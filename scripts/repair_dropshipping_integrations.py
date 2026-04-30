#!/usr/bin/env python3
"""Repair and audit Valley dropshipping integrations without leaking secrets.

The script fixes local runtime configuration that can be fixed autonomously:
- seeds missing provider rows from the integration template;
- imports credentials from environment/.env into ignored tmp/runtime secrets;
- preserves existing OAuth tokens and seller IDs;
- enforces safe sync flags and disables scraping fallback;
- writes a sanitized status report for operators.

It cannot complete third-party OAuth consent, marketplace app approval, 2FA, or
vendor-side activation. Those remain reported as external_auth_pending.
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
RUNTIME_DIR = ROOT / "tmp" / "runtime"
ENV_PATH = ROOT / ".env"
TEMPLATE_PATH = ROOT / "config" / "integrations" / "marketplace_api_integrations.template.json"
INTEGRATIONS_PATH = RUNTIME_DIR / "valley-admin-integrations.json"
SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"
STATUS_PATH = RUNTIME_DIR / "valley-dropshipping-integration-status.json"


@dataclass(frozen=True)
class ProviderPolicy:
    key: str
    label: str
    role: str
    required_any_secret_fields: tuple[str, ...]
    env_prefixes: tuple[str, ...]
    runtime_paths: tuple[Path, ...] = ()
    can_use_operator_login: bool = False


PROVIDERS: tuple[ProviderPolicy, ...] = (
    ProviderPolicy(
        key="cjdropshipping",
        label="CJDropshipping",
        role="supplier_api",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("CJDROPSHIPPING", "CJ"),
        runtime_paths=(
            RUNTIME_DIR / "valley-cjdropshipping-notification-latest.json",
            RUNTIME_DIR / "valley-stock-real-catalog.json",
        ),
    ),
    ProviderPolicy(
        key="aliexpress",
        label="AliExpress",
        role="supplier_api",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("ALIEXPRESS",),
        runtime_paths=(RUNTIME_DIR / "valley-aliexpress-oauth-runtime.json",),
    ),
    ProviderPolicy(
        key="alibaba",
        label="Alibaba",
        role="supplier_api",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("ALIBABA",),
        runtime_paths=(RUNTIME_DIR / "valley-alibaba-oauth-runtime.json",),
        can_use_operator_login=True,
    ),
    ProviderPolicy(
        key="amazon",
        label="Amazon",
        role="marketplace_price",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("AMAZON",),
        can_use_operator_login=True,
    ),
    ProviderPolicy(
        key="shopee",
        label="Shopee",
        role="marketplace_price",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("SHOPEE", "SHOPPE"),
        runtime_paths=(RUNTIME_DIR / "valley-shopee-oauth-runtime.json",),
        can_use_operator_login=True,
    ),
    ProviderPolicy(
        key="magalu",
        label="Magalu",
        role="marketplace_price",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("MAGALU",),
        runtime_paths=(RUNTIME_DIR / "valley-magalu-oauth-runtime.json",),
    ),
    ProviderPolicy(
        key="mercado_livre",
        label="Mercado Livre",
        role="marketplace_price",
        required_any_secret_fields=("accessToken", "access_token"),
        env_prefixes=("MERCADOLIVRE", "MERCADO_LIVRE"),
        runtime_paths=(RUNTIME_DIR / "valley-marketplace-oauth-runtime.json",),
    ),
)

SECRET_FIELD_ALIASES = {
    "CLIENT_ID": ("clientId", "client_id"),
    "CLIENT_SECRET": ("clientSecret", "client_secret"),
    "ACCESS_TOKEN": ("accessToken", "access_token"),
    "REFRESH_TOKEN": ("refreshToken", "refresh_token"),
    "SELLER_ID": ("sellerId", "seller_id"),
    "OPEN_ID": ("openId", "open_id"),
    "USER": ("username", "user"),
    "USERNAME": ("username",),
    "EMAIL": ("username",),
    "LOGIN": ("username",),
    "PASSWORD": ("password",),
    "PASS": ("password",),
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


def merged_env() -> dict[str, str]:
    values = parse_env_file(ENV_PATH)
    values.update({key: value for key, value in os.environ.items() if value})
    return values


def template_provider_map() -> dict[str, dict[str, Any]]:
    payload = load_json(TEMPLATE_PATH, {})
    providers = payload.get("providers") if isinstance(payload, dict) else None
    if not isinstance(providers, list):
        return {}
    return {
        str(provider.get("key") or "").strip(): dict(provider)
        for provider in providers
        if isinstance(provider, dict) and str(provider.get("key") or "").strip()
    }


def provider_by_key() -> dict[str, ProviderPolicy]:
    return {provider.key: provider for provider in PROVIDERS}


def first_value(values: dict[str, str], names: list[str]) -> str:
    for name in names:
        value = str(values.get(name) or "").strip()
        if value:
            return value
    return ""


def import_env_secrets(secrets: dict[str, Any], env_values: dict[str, str]) -> list[str]:
    touched: list[str] = []
    for provider in PROVIDERS:
        provider_payload = secrets.get(provider.key)
        if not isinstance(provider_payload, dict):
            provider_payload = {}
        changed = False

        for env_suffix, secret_keys in SECRET_FIELD_ALIASES.items():
            candidates: list[str] = []
            for prefix in provider.env_prefixes:
                candidates.extend(
                    [
                        f"{prefix}_{env_suffix}",
                        f"VALLEY_{prefix}_{env_suffix}",
                        f"VALLEY_SUPPLIER_{prefix}_{env_suffix}",
                    ]
                )
            if env_suffix in {"USER", "USERNAME", "EMAIL", "LOGIN"}:
                candidates.extend(
                    [
                        "VALLEY_SUPPLIER_SHARED_USER",
                        "VALLEY_SUPPLIER_SHARED_USERNAME",
                        "SUPPLIER_SHARED_USER",
                        "SUPPLIER_SHARED_USERNAME",
                    ]
                )
            if env_suffix in {"PASSWORD", "PASS"}:
                candidates.extend(
                    [
                        "VALLEY_SUPPLIER_SHARED_PASSWORD",
                        "VALLEY_SUPPLIER_SHARED_PASS",
                        "SUPPLIER_SHARED_PASSWORD",
                        "SUPPLIER_SHARED_PASS",
                    ]
                )

            value = first_value(env_values, candidates)
            if not value:
                continue
            for secret_key in secret_keys:
                provider_payload[secret_key] = value
            changed = True

        if changed:
            provider_payload["credentialSource"] = "env"
            provider_payload["updated_at_utc"] = utc_now_iso()
            if provider_payload.get("username") and provider_payload.get("password"):
                provider_payload["authMode"] = "operator_login"
                provider_payload["rotationRequired"] = True
                provider_payload["rotationReason"] = "operator credential loaded from local env"
            secrets[provider.key] = provider_payload
            touched.append(provider.key)
    return touched


def merge_runtime_oauth(secrets: dict[str, Any]) -> list[str]:
    touched: list[str] = []
    field_map = {
        "access_token": "accessToken",
        "accessToken": "accessToken",
        "refresh_token": "refreshToken",
        "refreshToken": "refreshToken",
        "seller_id": "sellerId",
        "sellerId": "sellerId",
        "shop_id": "sellerId",
        "shopId": "sellerId",
        "open_id": "openId",
        "openId": "openId",
        "user_id": "userId",
        "userId": "userId",
    }

    for provider in PROVIDERS:
        provider_payload = secrets.get(provider.key)
        if not isinstance(provider_payload, dict):
            provider_payload = {}
        changed = False
        for path in provider.runtime_paths:
            payload = load_json(path, {})
            if not isinstance(payload, dict):
                continue
            for source_key, target_key in field_map.items():
                value = payload.get(source_key)
                if value:
                    provider_payload[target_key] = value
                    changed = True
        if changed:
            provider_payload["credentialSource"] = provider_payload.get("credentialSource") or "runtime_oauth"
            provider_payload["updated_at_utc"] = utc_now_iso()
            secrets[provider.key] = provider_payload
            touched.append(provider.key)
    return touched


def safe_integration_defaults(provider: ProviderPolicy, template: dict[str, Any] | None) -> dict[str, Any]:
    item = dict(template or {})
    item.update(
        {
            "key": provider.key,
            "label": item.get("label") or provider.label,
            "providerRole": item.get("providerRole") or provider.role,
            "enabled": True,
            "importCatalog": True,
            "syncOrders": bool(item.get("syncOrders", True)),
            "syncInventory": True,
            "syncPricing": True,
            "allowScrapingFallback": False,
            "blockExternalAiLookup": True,
            "secretRef": item.get("secretRef") or f"runtime://marketplaces/{provider.key}/secret",
            "accessTokenRef": item.get("accessTokenRef") or f"runtime://marketplaces/{provider.key}/access-token",
            "refreshTokenRef": item.get("refreshTokenRef") or f"runtime://marketplaces/{provider.key}/refresh-token",
            "usernameRef": item.get("usernameRef") or f"runtime://marketplaces/{provider.key}/username",
            "passwordRef": item.get("passwordRef") or f"runtime://marketplaces/{provider.key}/password",
        }
    )
    return item


def repair_integrations(secrets: dict[str, Any]) -> list[dict[str, Any]]:
    template_map = template_provider_map()
    existing = load_json(INTEGRATIONS_PATH, [])
    integrations = existing if isinstance(existing, list) else []
    known = provider_by_key()
    by_key: dict[str, dict[str, Any]] = {}
    for item in integrations:
        if isinstance(item, dict) and str(item.get("key") or "").strip():
            by_key[str(item.get("key")).strip()] = dict(item)

    for provider in PROVIDERS:
        base = safe_integration_defaults(provider, template_map.get(provider.key))
        current = by_key.get(provider.key, {})
        merged = dict(base)
        merged.update(current)
        for enforced_key in (
            "enabled",
            "importCatalog",
            "syncInventory",
            "syncPricing",
            "allowScrapingFallback",
            "blockExternalAiLookup",
            "usernameRef",
            "passwordRef",
        ):
            merged[enforced_key] = base[enforced_key]
        provider_secrets = secrets.get(provider.key)
        if isinstance(provider_secrets, dict):
            if provider_secrets.get("sellerId") and not str(merged.get("sellerId") or "").strip():
                merged["sellerId"] = str(provider_secrets.get("sellerId"))
            if provider_secrets.get("clientId") and not str(merged.get("clientId") or "").strip():
                merged["clientId"] = str(provider_secrets.get("clientId"))
        by_key[provider.key] = merged

    ordered_keys = [item.get("key") for item in integrations if isinstance(item, dict)]
    for provider in PROVIDERS:
        if provider.key not in ordered_keys:
            ordered_keys.append(provider.key)
    deduped_order = []
    for key in ordered_keys:
        if key and key not in deduped_order:
            deduped_order.append(str(key))
    repaired = [by_key[key] for key in deduped_order if key in by_key]
    write_json(INTEGRATIONS_PATH, repaired)
    return repaired


def has_any_secret(payload: dict[str, Any], fields: tuple[str, ...]) -> bool:
    return any(bool(payload.get(field)) for field in fields)


def provider_status(
    provider: ProviderPolicy,
    integration: dict[str, Any],
    provider_secrets: dict[str, Any],
) -> dict[str, Any]:
    has_token = has_any_secret(provider_secrets, provider.required_any_secret_fields)
    has_operator_login = bool(provider_secrets.get("username") and provider_secrets.get("password"))
    runtime_evidence = [path.name for path in provider.runtime_paths if path.exists()]

    if has_token:
        status = "active"
        pending: list[str] = []
    elif provider.can_use_operator_login and has_operator_login:
        status = "operator_login_ready"
        pending = ["official_api_or_oauth_token"]
    else:
        status = "external_auth_pending"
        pending = ["credentials_or_oauth_token"]

    if not integration.get("enabled"):
        pending.append("integration_enable_flag")
    if integration.get("allowScrapingFallback"):
        pending.append("disable_scraping_fallback")

    return {
        "key": provider.key,
        "label": provider.label,
        "role": provider.role,
        "status": status,
        "enabled": bool(integration.get("enabled")),
        "importCatalog": bool(integration.get("importCatalog")),
        "syncInventory": bool(integration.get("syncInventory")),
        "syncPricing": bool(integration.get("syncPricing")),
        "safePolicy": {
            "allowScrapingFallback": bool(integration.get("allowScrapingFallback")),
            "blockExternalAiLookup": bool(integration.get("blockExternalAiLookup")),
        },
        "secrets": {
            "hasAccessToken": has_token,
            "hasRefreshToken": bool(provider_secrets.get("refreshToken") or provider_secrets.get("refresh_token")),
            "hasOperatorLogin": has_operator_login,
            "hasClientSecret": bool(provider_secrets.get("clientSecret") or provider_secrets.get("client_secret")),
            "hasSellerId": bool(provider_secrets.get("sellerId") or integration.get("sellerId")),
        },
        "runtimeEvidence": runtime_evidence,
        "pending": pending,
    }


def build_status(integrations: list[dict[str, Any]], secrets: dict[str, Any], repaired_sources: list[str]) -> dict[str, Any]:
    by_key = {
        str(item.get("key") or "").strip(): item
        for item in integrations
        if isinstance(item, dict) and str(item.get("key") or "").strip()
    }
    providers_status = []
    for provider in PROVIDERS:
        provider_secrets = secrets.get(provider.key)
        providers_status.append(
            provider_status(
                provider,
                by_key.get(provider.key, {}),
                provider_secrets if isinstance(provider_secrets, dict) else {},
            )
        )

    active = [item["key"] for item in providers_status if item["status"] == "active"]
    ready = [item["key"] for item in providers_status if item["status"] == "operator_login_ready"]
    pending = [item["key"] for item in providers_status if item["pending"]]
    return {
        "status": "ok",
        "generated_at_utc": utc_now_iso(),
        "scope": "dropshipping",
        "summary": {
            "active": active,
            "operator_login_ready": ready,
            "pending": pending,
            "providers_total": len(providers_status),
        },
        "repairedSources": repaired_sources,
        "providers": providers_status,
        "secret_values_printed": False,
    }


def repair(dry_run: bool = False) -> dict[str, Any]:
    env_values = merged_env()
    secrets_payload = load_json(SECRETS_PATH, {})
    secrets = secrets_payload if isinstance(secrets_payload, dict) else {}

    repaired_sources: list[str] = []
    env_touched = import_env_secrets(secrets, env_values)
    if env_touched:
        repaired_sources.append(f"env:{','.join(sorted(env_touched))}")
    oauth_touched = merge_runtime_oauth(secrets)
    if oauth_touched:
        repaired_sources.append(f"runtime_oauth:{','.join(sorted(oauth_touched))}")

    integrations = repair_integrations(secrets)
    report = build_status(integrations, secrets, repaired_sources)

    if not dry_run:
        write_json(SECRETS_PATH, secrets)
        write_json(STATUS_PATH, report)
    report["dry_run"] = dry_run
    report["status_path"] = str(STATUS_PATH.relative_to(ROOT))
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repair/audit dropshipping integrations.")
    parser.add_argument("--dry-run", action="store_true", help="Do not persist runtime changes.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    print(json.dumps(repair(dry_run=args.dry_run), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
