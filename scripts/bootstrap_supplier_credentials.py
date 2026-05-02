#!/usr/bin/env python3
"""Bootstrap local credentials for supplier integrations.

The script reads secrets from environment variables or a local .env file and
writes them only to tmp/runtime, which is ignored by Git in this repository.
It never prints usernames, passwords, tokens, or raw secret payloads.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_FILE = ROOT / ".env"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
CODEX_CLOUD_ENV_FILE = RUNTIME_DIR / "codex-cloud-secrets.env"
ADMIN_INTEGRATIONS_PATH = RUNTIME_DIR / "valley-admin-integrations.json"
PROVIDER_SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"
INTEGRATION_TEMPLATE_PATH = ROOT / "config" / "integrations" / "marketplace_api_integrations.template.json"


@dataclass(frozen=True)
class ProviderSpec:
    key: str
    label: str
    prefixes: tuple[str, ...]
    role: str
    base_url: str
    site_code: str


PROVIDERS: dict[str, ProviderSpec] = {
    "amazon": ProviderSpec(
        key="amazon",
        label="Amazon",
        prefixes=("AMAZON",),
        role="marketplace_price",
        base_url="https://sellingpartnerapi-na.amazon.com",
        site_code="BR",
    ),
    "alibaba": ProviderSpec(
        key="alibaba",
        label="Alibaba",
        prefixes=("ALIBABA",),
        role="supplier_api",
        base_url="https://openapi.alibaba.com",
        site_code="GLOBAL",
    ),
    "shopee": ProviderSpec(
        key="shopee",
        label="Shopee",
        prefixes=("SHOPEE", "SHOPPE"),
        role="marketplace_price",
        base_url="https://partner.shopeemobile.com",
        site_code="BR",
    ),
}


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


def first_env_value(values: dict[str, str], candidates: tuple[str, ...]) -> str:
    for candidate in candidates:
        value = str(values.get(candidate) or "").strip()
        if value:
            return value
    return ""


def credential_candidates(spec: ProviderSpec, suffixes: tuple[str, ...]) -> tuple[str, ...]:
    candidates: list[str] = []
    for prefix in spec.prefixes:
        for suffix in suffixes:
            candidates.append(f"{prefix}_{suffix}")
            candidates.append(f"VALLEY_{prefix}_{suffix}")
            candidates.append(f"VALLEY_SUPPLIER_{prefix}_{suffix}")
    return tuple(candidates)


def resolve_provider_credentials(spec: ProviderSpec, values: dict[str, str]) -> dict[str, str] | None:
    user = first_env_value(
        values,
        credential_candidates(spec, ("USER", "USERNAME", "LOGIN", "EMAIL"))
        + (
            "VALLEY_SUPPLIER_SHARED_USER",
            "VALLEY_SUPPLIER_SHARED_USERNAME",
            "SUPPLIER_SHARED_USER",
            "SUPPLIER_SHARED_USERNAME",
        ),
    )
    password = first_env_value(
        values,
        credential_candidates(spec, ("PASSWORD", "PASS", "SECRET"))
        + (
            "VALLEY_SUPPLIER_SHARED_PASSWORD",
            "VALLEY_SUPPLIER_SHARED_PASS",
            "SUPPLIER_SHARED_PASSWORD",
            "SUPPLIER_SHARED_PASS",
        ),
    )
    if not user or not password:
        return None
    return {"username": user, "password": password}


def load_template_provider_map() -> dict[str, dict[str, Any]]:
    template = load_json(INTEGRATION_TEMPLATE_PATH, {})
    providers = template.get("providers") if isinstance(template, dict) else None
    if not isinstance(providers, list):
        return {}
    return {
        str(provider.get("key") or "").strip(): dict(provider)
        for provider in providers
        if isinstance(provider, dict) and str(provider.get("key") or "").strip()
    }


def integration_defaults(spec: ProviderSpec, template_provider: dict[str, Any] | None) -> dict[str, Any]:
    base = dict(template_provider or {})
    base.update(
        {
            "key": spec.key,
            "label": base.get("label") or spec.label,
            "providerRole": base.get("providerRole") or spec.role,
            "siteCode": base.get("siteCode") or spec.site_code,
            "baseUrl": base.get("baseUrl") or spec.base_url,
            "authMode": "operator_login",
            "enabled": True,
            "importCatalog": bool(base.get("importCatalog", True)),
            "syncPricing": bool(base.get("syncPricing", True)),
            "syncInventory": bool(base.get("syncInventory", True)),
            "allowScrapingFallback": False,
            "blockExternalAiLookup": True,
            "secretRef": f"runtime://marketplaces/{spec.key}/operator-login",
            "usernameRef": f"runtime://marketplaces/{spec.key}/username",
            "passwordRef": f"runtime://marketplaces/{spec.key}/password",
            "credentialStatus": "local_runtime_ready",
            "notes": (
                "Credenciais locais carregadas de variaveis de ambiente. "
                "Para producao, trocar por OAuth/API oficial ou secret manager."
            ),
        }
    )
    return base


def merge_integrations(configured: list[str], dry_run: bool) -> None:
    template_map = load_template_provider_map()
    existing_payload = load_json(ADMIN_INTEGRATIONS_PATH, [])
    integrations = existing_payload if isinstance(existing_payload, list) else []
    by_key = {
        str(item.get("key") or "").strip(): dict(item)
        for item in integrations
        if isinstance(item, dict) and str(item.get("key") or "").strip()
    }

    for provider_key in configured:
        spec = PROVIDERS[provider_key]
        current = by_key.get(provider_key, {})
        defaults = integration_defaults(spec, template_map.get(provider_key))
        merged = dict(defaults)
        merged.update(current)
        for enforced_key in (
            "authMode",
            "enabled",
            "allowScrapingFallback",
            "blockExternalAiLookup",
            "secretRef",
            "usernameRef",
            "passwordRef",
            "credentialStatus",
            "notes",
        ):
            merged[enforced_key] = defaults[enforced_key]
        by_key[provider_key] = merged

    untouched = [
        dict(item)
        for item in integrations
        if isinstance(item, dict) and str(item.get("key") or "").strip() not in configured
    ]
    merged_payload = untouched + [by_key[key] for key in sorted(configured)]
    if not dry_run:
        write_json(ADMIN_INTEGRATIONS_PATH, merged_payload)


def merge_provider_secrets(credentials: dict[str, dict[str, str]], dry_run: bool) -> None:
    payload = load_json(PROVIDER_SECRETS_PATH, {})
    secrets = payload if isinstance(payload, dict) else {}
    now = utc_now_iso()

    for provider_key, provider_credentials in credentials.items():
        provider_payload = secrets.get(provider_key)
        if not isinstance(provider_payload, dict):
            provider_payload = {}
        provider_payload.update(
            {
                "authMode": "operator_login",
                "username": provider_credentials["username"],
                "password": provider_credentials["password"],
                "credentialSource": "env",
                "rotationRequired": True,
                "rotationReason": "credencial operacional informada fora de vault",
                "updated_at_utc": now,
            }
        )
        secrets[provider_key] = provider_payload

    if not dry_run:
        write_json(PROVIDER_SECRETS_PATH, secrets)


def parse_provider_filter(raw_value: str) -> list[str]:
    if not raw_value.strip():
        return sorted(PROVIDERS)
    selected: list[str] = []
    for item in raw_value.split(","):
        key = item.strip().lower()
        if key == "shoppe":
            key = "shopee"
        if key in PROVIDERS and key not in selected:
            selected.append(key)
    return selected


def bootstrap(env_file: Path, provider_filter: list[str], dry_run: bool) -> dict[str, Any]:
    values = merged_env(env_file)
    credentials: dict[str, dict[str, str]] = {}
    missing: list[str] = []

    for provider_key in provider_filter:
        resolved = resolve_provider_credentials(PROVIDERS[provider_key], values)
        if resolved is None:
            missing.append(provider_key)
            continue
        credentials[provider_key] = resolved

    configured = sorted(credentials)
    if configured:
        merge_provider_secrets(credentials, dry_run=dry_run)
        merge_integrations(configured, dry_run=dry_run)

    return {
        "status": "ok",
        "dry_run": dry_run,
        "env_file": str(env_file.relative_to(ROOT) if env_file.is_relative_to(ROOT) else env_file),
        "configured_providers": configured,
        "missing_providers": missing,
        "secrets_path": str(PROVIDER_SECRETS_PATH.relative_to(ROOT)),
        "integrations_path": str(ADMIN_INTEGRATIONS_PATH.relative_to(ROOT)),
        "secret_values_printed": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Carrega credenciais locais de Amazon, Alibaba e Shopee sem imprimir segredos."
    )
    parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE), help="Arquivo .env local.")
    parser.add_argument(
        "--providers",
        default="amazon,alibaba,shopee",
        help="Lista separada por virgula. Aceita amazon, alibaba, shopee/shoppe.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Valida sem gravar runtime.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    provider_filter = parse_provider_filter(args.providers)
    payload = bootstrap(Path(args.env_file).resolve(), provider_filter, dry_run=args.dry_run)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
