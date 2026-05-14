#!/usr/bin/env python3
# PROPOSITO: Automatizar bootstrap mercadopago checkout no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/bootstrap_mercadopago_checkout.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Bootstrap and validate Mercado Pago checkout credentials for Valley.

Reads credentials from .env, tmp/runtime/codex-cloud-secrets.env, or process
environment, persists only to tmp/runtime/valley-provider-secrets.json, and
writes a sanitized health snapshot to tmp/runtime/valley-mercadopago-status.json.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_FILE = ROOT / ".env"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
CODEX_CLOUD_ENV_FILE = RUNTIME_DIR / "codex-cloud-secrets.env"
PROVIDER_SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"
STATUS_PATH = RUNTIME_DIR / "valley-mercadopago-status.json"
PUBLIC_RUNTIME_PATH = RUNTIME_DIR / "valley-admin-public-runtime.json"


def utc_now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def load_json(path: Path, fallback: Any) -> Any:
    if not path.exists():
        return fallback
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parse_env_file(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            continue
        if (value.startswith('"') and value.endswith('"')) or (
            value.startswith("'") and value.endswith("'")
        ):
            value = value[1:-1]
        values[key] = value
    return values


def merged_env(env_file: Path) -> dict[str, str]:
    values = parse_env_file(env_file)
    values.update(parse_env_file(CODEX_CLOUD_ENV_FILE))
    values.update({key: value for key, value in os.environ.items() if value})
    return values


def first_value(*candidates: Any) -> str:
    for candidate in candidates:
        value = str(candidate or "").strip()
        if value:
            return value
    return ""


def public_admin_base_url(env_values: dict[str, str]) -> str:
    runtime = load_json(PUBLIC_RUNTIME_PATH, {})
    runtime_url = str(runtime.get("public_url") or "").strip().rstrip("/")
    if runtime_url:
        return runtime_url

    for key in ("VALLEY_ADMIN_PUBLIC_URL", "VALLEY_CLOUDFLARE_PUBLIC_URL"):
        value = str(env_values.get(key) or "").strip().rstrip("/")
        if value:
            return value

    host = str(env_values.get("VALLEY_TERMIUS_CLOUDFLARE_HOST") or "").strip()
    if host:
        if host.startswith("http://") or host.startswith("https://"):
            return host.rstrip("/")
        return f"https://{host}"

    return "https://admin.brasildesconto.com.br"


def current_provider_secret() -> dict[str, Any]:
    payload = load_json(PROVIDER_SECRETS_PATH, {})
    if not isinstance(payload, dict):
        return {}
    section = payload.get("mercado_pago")
    return dict(section) if isinstance(section, dict) else {}


def resolved_credentials(env_values: dict[str, str]) -> dict[str, str]:
    current = current_provider_secret()
    return {
        "accessToken": first_value(
            env_values.get("VALLEY_MERCADOPAGO_ACCESS_TOKEN"),
            env_values.get("MERCADOPAGO_ACCESS_TOKEN"),
            env_values.get("MP_ACCESS_TOKEN"),
            current.get("accessToken"),
            current.get("access_token"),
        ),
        "publicKey": first_value(
            env_values.get("VALLEY_MERCADOPAGO_PUBLIC_KEY"),
            env_values.get("MERCADOPAGO_PUBLIC_KEY"),
            env_values.get("MP_PUBLIC_KEY"),
            current.get("publicKey"),
            current.get("public_key"),
        ),
        "webhookSecret": first_value(
            env_values.get("VALLEY_MERCADOPAGO_WEBHOOK_SECRET"),
            env_values.get("MERCADOPAGO_WEBHOOK_SECRET"),
            env_values.get("MP_WEBHOOK_SECRET"),
            current.get("webhookSecret"),
            current.get("webhook_secret"),
        ),
    }


def persist_provider_secret(credentials: dict[str, str], dry_run: bool) -> bool:
    payload = load_json(PROVIDER_SECRETS_PATH, {})
    secrets = payload if isinstance(payload, dict) else {}
    current = secrets.get("mercado_pago")
    section = dict(current) if isinstance(current, dict) else {}
    changed = False

    for source_key, target_key in (
        ("accessToken", "accessToken"),
        ("publicKey", "publicKey"),
        ("webhookSecret", "webhookSecret"),
    ):
        value = str(credentials.get(source_key) or "").strip()
        if value and section.get(target_key) != value:
            section[target_key] = value
            changed = True

    if changed:
        section["updated_at_utc"] = utc_now_iso()
        section["credentialSource"] = "env"
        secrets["mercado_pago"] = section
        if not dry_run:
            write_json(PROVIDER_SECRETS_PATH, secrets)

    return changed


def validate_access_token(access_token: str) -> dict[str, Any]:
    checked_at = utc_now_iso()
    if not access_token:
        return {
            "status": "missing_credentials",
            "checked_at_utc": checked_at,
            "detail": "Access token do Mercado Pago ausente.",
        }

    request = Request(
        "https://api.mercadopago.com/v1/payment_methods",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
            "User-Agent": "ValleyBootstrap/1.0",
        },
        method="GET",
    )
    try:
        with urlopen(request, timeout=25) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        return {
            "status": "http_error",
            "checked_at_utc": checked_at,
            "http_code": error.code,
            "detail": " ".join(detail.split())[:280],
        }
    except URLError as error:
        return {
            "status": "network_error",
            "checked_at_utc": checked_at,
            "detail": str(error)[:280],
        }
    except json.JSONDecodeError as error:
        return {
            "status": "invalid_response",
            "checked_at_utc": checked_at,
            "detail": str(error)[:280],
        }
    except Exception as error:  # noqa: BLE001
        return {
            "status": "failed",
            "checked_at_utc": checked_at,
            "detail": str(error)[:280],
        }

    methods = payload if isinstance(payload, list) else []
    method_ids = {
        str(method.get("id") or "").strip().lower()
        for method in methods
        if isinstance(method, dict)
    }
    payment_type_ids = {
        str(method.get("payment_type_id") or "").strip().lower()
        for method in methods
        if isinstance(method, dict)
    }
    return {
        "status": "ok",
        "checked_at_utc": checked_at,
        "payment_methods_total": len(methods),
        "pix_available": "pix" in method_ids,
        "account_money_available": "account_money" in payment_type_ids,
    }


def build_status(credentials: dict[str, str], validation: dict[str, Any], env_values: dict[str, str], provider_secret_written: bool) -> dict[str, Any]:
    base_url = public_admin_base_url(env_values)
    if credentials["accessToken"] and validation.get("status") == "ok":
        status = "ready"
    elif credentials["accessToken"] or credentials["publicKey"] or credentials["webhookSecret"]:
        status = "partial"
    else:
        status = "missing_credentials"

    return {
        "status": status,
        "service": "valley-mercadopago-checkout",
        "provider": "mercado_pago",
        "generated_at_utc": utc_now_iso(),
        "checkout_ready": bool(credentials["accessToken"]),
        "access_token_present": bool(credentials["accessToken"]),
        "public_key_present": bool(credentials["publicKey"]),
        "webhook_secret_present": bool(credentials["webhookSecret"]),
        "provider_secret_written": provider_secret_written,
        "notification_url": f"{base_url}/integrations/mercadopago/notifications?source_news=webhooks",
        "sample_return_url": f"{base_url}/integrations/mercadopago/return?status=approved&item_id=demo-item",
        "validation": validation,
    }


def bootstrap(env_file: Path, dry_run: bool) -> dict[str, Any]:
    env_values = merged_env(env_file)
    credentials = resolved_credentials(env_values)
    provider_secret_written = persist_provider_secret(credentials, dry_run=dry_run)
    validation = validate_access_token(credentials["accessToken"])
    status = build_status(credentials, validation, env_values, provider_secret_written)
    if not dry_run:
        write_json(STATUS_PATH, status)
    return status


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap do checkout Mercado Pago para o Valley.")
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE, help="Arquivo .env adicional para leitura.")
    parser.add_argument("--dry-run", action="store_true", help="Nao persiste alteracoes em tmp/runtime.")
    args = parser.parse_args()

    payload = bootstrap(args.env_file, dry_run=args.dry_run)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
