#!/usr/bin/env python3
# PROPOSITO: Automatizar export codex cloud env no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/export_codex_cloud_env.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Export Codex Cloud environment variables from local runtime.

This script writes the complete key=value bundle to tmp/runtime and prints only
sanitized counts. It does not echo secret values to stdout.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
ENV_EXAMPLE_PATH = ROOT / ".env.example"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
INTEGRATIONS_PATH = RUNTIME_DIR / "valley-admin-integrations.json"
SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"
DEFAULT_OUTPUT_PATH = RUNTIME_DIR / "codex-cloud-secrets.env"


@dataclass(frozen=True)
class ProviderExport:
    provider_key: str
    env_prefix: str
    include_client_id: bool = True
    include_client_secret: bool = True
    include_access_token: bool = True
    include_refresh_token: bool = True
    include_seller_id: bool = True
    include_open_id: bool = False


PROVIDER_EXPORTS: tuple[ProviderExport, ...] = (
    ProviderExport("cjdropshipping", "CJDROPSHIPPING", include_client_id=False, include_client_secret=False, include_open_id=True),
    ProviderExport("aliexpress", "ALIEXPRESS"),
    ProviderExport("alibaba", "ALIBABA"),
    ProviderExport("amazon", "AMAZON"),
    ProviderExport("shopee", "SHOPEE"),
    ProviderExport("magalu", "MAGALU"),
    ProviderExport("mercado_livre", "MERCADOLIVRE"),
    ProviderExport("mercado_pago", "VALLEY_MERCADOPAGO", include_client_id=False, include_client_secret=False, include_refresh_token=False, include_seller_id=False),
)


def utc_now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def load_json(path: Path, fallback: Any) -> Any:
    if not path.exists():
        return fallback
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback


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


def parse_example_keys(path: Path) -> list[str]:
    if not path.exists():
        return []
    keys: list[str] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key = line.split("=", 1)[0].strip()
        if key and key not in keys:
            keys.append(key)
    return keys


def first_value(*values: Any) -> str:
    for value in values:
        text = str(value or "").strip()
        if text:
            return text
    return ""


def integrations_by_key() -> dict[str, dict[str, Any]]:
    payload = load_json(INTEGRATIONS_PATH, [])
    items = payload if isinstance(payload, list) else []
    return {
        str(item.get("key") or "").strip(): dict(item)
        for item in items
        if isinstance(item, dict) and str(item.get("key") or "").strip()
    }


def secrets_by_key() -> dict[str, dict[str, Any]]:
    payload = load_json(SECRETS_PATH, {})
    if not isinstance(payload, dict):
        return {}
    return {
        str(key): dict(value)
        for key, value in payload.items()
        if isinstance(value, dict)
    }


def add_if_missing(keys: list[str], key: str) -> None:
    if key not in keys:
        keys.append(key)


def provider_env_values(
    existing_values: dict[str, str],
    integrations: dict[str, dict[str, Any]],
    secrets: dict[str, dict[str, Any]],
) -> dict[str, str]:
    values: dict[str, str] = {}
    for export in PROVIDER_EXPORTS:
        integration = integrations.get(export.provider_key, {})
        secret = secrets.get(export.provider_key, {})
        prefix = export.env_prefix

        if export.include_client_id:
            values[f"{prefix}_CLIENT_ID"] = first_value(
                existing_values.get(f"{prefix}_CLIENT_ID"),
                secret.get("clientId"),
                secret.get("client_id"),
                integration.get("clientId"),
            )
        if export.include_client_secret:
            values[f"{prefix}_CLIENT_SECRET"] = first_value(
                existing_values.get(f"{prefix}_CLIENT_SECRET"),
                secret.get("clientSecret"),
                secret.get("client_secret"),
            )
        if export.include_access_token:
            values[f"{prefix}_ACCESS_TOKEN"] = first_value(
                existing_values.get(f"{prefix}_ACCESS_TOKEN"),
                secret.get("accessToken"),
                secret.get("access_token"),
            )
        if export.include_refresh_token:
            values[f"{prefix}_REFRESH_TOKEN"] = first_value(
                existing_values.get(f"{prefix}_REFRESH_TOKEN"),
                secret.get("refreshToken"),
                secret.get("refresh_token"),
            )
        if export.include_seller_id:
            values[f"{prefix}_SELLER_ID"] = first_value(
                existing_values.get(f"{prefix}_SELLER_ID"),
                secret.get("sellerId"),
                secret.get("seller_id"),
                integration.get("sellerId"),
            )
        if export.include_open_id:
            values[f"{prefix}_OPEN_ID"] = first_value(
                existing_values.get(f"{prefix}_OPEN_ID"),
                secret.get("openId"),
                secret.get("open_id"),
            )

    mercado_pago = secrets.get("mercado_pago", {})
    values["VALLEY_MERCADOPAGO_PUBLIC_KEY"] = first_value(
        existing_values.get("VALLEY_MERCADOPAGO_PUBLIC_KEY"),
        mercado_pago.get("publicKey"),
        mercado_pago.get("public_key"),
    )
    values["VALLEY_MERCADOPAGO_WEBHOOK_SECRET"] = first_value(
        existing_values.get("VALLEY_MERCADOPAGO_WEBHOOK_SECRET"),
        mercado_pago.get("webhookSecret"),
        mercado_pago.get("webhook_secret"),
    )
    return values


def build_export_values() -> dict[str, str]:
    env_values = parse_env_file(ENV_PATH)
    values: dict[str, str] = {}
    for key in parse_example_keys(ENV_EXAMPLE_PATH):
        values[key] = env_values.get(key, "")

    provider_values = provider_env_values(env_values, integrations_by_key(), secrets_by_key())
    for key, value in provider_values.items():
        values[key] = value

    for key in (
        "MERCADOLIVRE_CLIENT_ID",
        "MERCADOLIVRE_CLIENT_SECRET",
        "MERCADOLIVRE_ACCESS_TOKEN",
        "MERCADOLIVRE_REFRESH_TOKEN",
        "MERCADOLIVRE_SELLER_ID",
        "MAGALU_CLIENT_ID",
        "MAGALU_CLIENT_SECRET",
        "MAGALU_ACCESS_TOKEN",
        "MAGALU_REFRESH_TOKEN",
        "MAGALU_SELLER_ID",
    ):
        add_if_missing(list(values), key)
        values.setdefault(key, provider_values.get(key, env_values.get(key, "")))

    return values


def render_env(values: dict[str, str]) -> str:
    lines = [
        "# Valley Codex Cloud environment export",
        f"# Generated at {utc_now_iso()}",
        "# Do not commit this file.",
        "",
    ]
    for key in sorted(values):
        value = values[key]
        if "\n" in value or "\r" in value:
            value = value.replace("\r", "\\r").replace("\n", "\\n")
        if value and any(char.isspace() for char in value):
            escaped = value.replace('"', '\\"')
            lines.append(f'{key}="{escaped}"')
        else:
            lines.append(f"{key}={value}")
    lines.append("")
    return "\n".join(lines)


def write_export(output_path: Path) -> dict[str, Any]:
    values = build_export_values()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(render_env(values), encoding="utf-8")
    filled = [key for key, value in values.items() if str(value).strip()]
    missing = [key for key, value in values.items() if not str(value).strip()]
    return {
        "status": "ok",
        "output_path": str(output_path.relative_to(ROOT)),
        "keys_total": len(values),
        "keys_with_values": len(filled),
        "keys_missing_values": len(missing),
        "missing_keys": missing,
        "secret_values_printed": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export Codex Cloud env file without echoing secrets.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT_PATH), help="Output .env path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    print(json.dumps(write_export(output_path), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
