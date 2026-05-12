#!/usr/bin/env python3
"""Import, normalize, compare, and select dropshipping products.

Source providers are intentionally limited to CJ Dropshipping, AliExpress, and
Alibaba. Marketplaces such as Mercado Livre, Shopee, Magalu, and Amazon are
used only as benchmark providers when authorized API credentials are present.

No scraping is performed. Missing APIs, scopes, or credentials are recorded as
``dados_insuficientes`` and block publication when the commercial policy
requires benchmark evidence.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import time
import unicodedata
import urllib.parse
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import NAMESPACE_URL, uuid5


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "tmp" / "runtime"
CONFIG_PATH = ROOT / "config" / "integrations" / "dropshipping_product_selection.json"
INTEGRATIONS_PATH = RUNTIME_DIR / "valley-admin-integrations.json"
SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"
ENV_PATH = ROOT / ".env"
CODEX_CLOUD_ENV_PATH = RUNTIME_DIR / "codex-cloud-secrets.env"
STOCK_RUNTIME_PATH = RUNTIME_DIR / "valley-stock-real-catalog.json"
CATEGORIES_PATH = RUNTIME_DIR / "valley-dropshipping-source-categories.json"
CANDIDATES_PATH = RUNTIME_DIR / "valley-dropshipping-product-candidates.json"
ELIGIBLE_PATH = RUNTIME_DIR / "valley-dropshipping-eligible-products.json"
STATUS_PATH = RUNTIME_DIR / "valley-dropshipping-selection-status.json"
CHECKPOINTS_PATH = RUNTIME_DIR / "valley-dropshipping-api-checkpoints.json"
CACHE_PATH = RUNTIME_DIR / "valley-dropshipping-api-cache.json"
QUOTA_REPORT_PATH = RUNTIME_DIR / "valley-dropshipping-quota-escalation-report.json"

SOURCE_PROVIDERS = ("cjdropshipping", "aliexpress", "alibaba")
BENCHMARK_PROVIDERS = ("mercado_livre", "shopee", "magalu", "amazon", "aliexpress")
CACHE_TTL_SECONDS = {
    "categories": 7 * 24 * 60 * 60,
    "product": 24 * 60 * 60,
    "stock": 6 * 60 * 60,
    "supplier_price": 6 * 60 * 60,
    "competitor_price": 12 * 60 * 60,
    "compliance": 30 * 24 * 60 * 60,
}
RETRYABLE_STATUS_CODES = {429, 500, 502, 503}


@dataclass(frozen=True)
class ProviderAuth:
    key: str
    integration: dict[str, Any]
    secrets: dict[str, Any]


@dataclass(frozen=True)
class RateLimitPolicy:
    provider: str
    per_minute: int = 60
    per_hour: int = 1200
    per_day: int = 10000
    max_retries: int = 4
    base_backoff_seconds: float = 1.0
    max_backoff_seconds: float = 120.0
    circuit_breaker_failures: int = 5
    circuit_breaker_cooldown_seconds: float = 300.0


@dataclass
class ConnectorRateLimiter:
    policy: RateLimitPolicy
    minute_window_started_at: float = field(default_factory=time.monotonic)
    hour_window_started_at: float = field(default_factory=time.monotonic)
    day_window_started_at: float = field(default_factory=time.monotonic)
    minute_count: int = 0
    hour_count: int = 0
    day_count: int = 0
    consecutive_failures: int = 0
    circuit_open_until: float = 0.0

    def before_request(self) -> None:
        now = time.monotonic()
        if now < self.circuit_open_until:
            raise RuntimeError(
                f"circuit_breaker_open:{self.policy.provider}:retry_after_seconds="
                f"{round(self.circuit_open_until - now, 2)}"
            )
        self._reset_windows(now)
        waits = []
        if self.minute_count >= self.policy.per_minute:
            waits.append(60 - (now - self.minute_window_started_at))
        if self.hour_count >= self.policy.per_hour:
            waits.append(3600 - (now - self.hour_window_started_at))
        if self.day_count >= self.policy.per_day:
            waits.append(86400 - (now - self.day_window_started_at))
        wait = max([value for value in waits if value > 0], default=0.0)
        if wait:
            time.sleep(wait)
            self._reset_windows(time.monotonic())
        self.minute_count += 1
        self.hour_count += 1
        self.day_count += 1

    def after_success(self, headers: dict[str, str] | None = None) -> None:
        self.consecutive_failures = 0
        self._apply_rate_headers(headers or {})

    def after_failure(self, retry_after_seconds: float | None = None) -> float:
        self.consecutive_failures += 1
        if self.consecutive_failures >= self.policy.circuit_breaker_failures:
            self.circuit_open_until = time.monotonic() + self.policy.circuit_breaker_cooldown_seconds
        if retry_after_seconds is not None and retry_after_seconds >= 0:
            return min(retry_after_seconds, self.policy.max_backoff_seconds)
        exponent = min(self.consecutive_failures, self.policy.max_retries)
        jitter = random.uniform(0, self.policy.base_backoff_seconds)
        return min((self.policy.base_backoff_seconds * (2 ** exponent)) + jitter, self.policy.max_backoff_seconds)

    def _reset_windows(self, now: float) -> None:
        if now - self.minute_window_started_at >= 60:
            self.minute_window_started_at = now
            self.minute_count = 0
        if now - self.hour_window_started_at >= 3600:
            self.hour_window_started_at = now
            self.hour_count = 0
        if now - self.day_window_started_at >= 86400:
            self.day_window_started_at = now
            self.day_count = 0

    def _apply_rate_headers(self, headers: dict[str, str]) -> None:
        remaining = (
            headers.get("x-ratelimit-remaining")
            or headers.get("x-rate-limit-remaining")
            or headers.get("X-RateLimit-Remaining")
        )
        if remaining is not None and safe_int(remaining, 1) <= 0:
            reset = headers.get("x-ratelimit-reset") or headers.get("X-RateLimit-Reset")
            reset_seconds = safe_float(reset, 60.0)
            self.circuit_open_until = max(self.circuit_open_until, time.monotonic() + min(reset_seconds, 3600))


class CJDropshippingConnectorRateLimiter(ConnectorRateLimiter):
    pass


class AlibabaConnectorRateLimiter(ConnectorRateLimiter):
    pass


class AliExpressConnectorRateLimiter(ConnectorRateLimiter):
    pass


class MercadoLivreConnectorRateLimiter(ConnectorRateLimiter):
    pass


class ShopeeConnectorRateLimiter(ConnectorRateLimiter):
    pass


class MagaluConnectorRateLimiter(ConnectorRateLimiter):
    pass


class AmazonConnectorRateLimiter(ConnectorRateLimiter):
    pass


class CheckpointStore:
    def __init__(self, path: Path = CHECKPOINTS_PATH) -> None:
        self.path = path
        payload = load_json(path, {})
        self.payload = payload if isinstance(payload, dict) else {}

    def key(self, provider: str, category_id: str, filters: dict[str, Any]) -> str:
        filter_json = json.dumps(filters, ensure_ascii=False, sort_keys=True)
        return str(uuid5(NAMESPACE_URL, f"valley:checkpoint:{provider}:{category_id}:{filter_json}"))

    def get(self, provider: str, category_id: str, filters: dict[str, Any]) -> dict[str, Any]:
        return dict(self.payload.get(self.key(provider, category_id, filters), {}))

    def save(
        self,
        provider: str,
        category_id: str,
        filters: dict[str, Any],
        page: int | None = None,
        cursor: str | None = None,
        status: str = "running",
    ) -> None:
        self.payload[self.key(provider, category_id, filters)] = {
            "provider": provider,
            "category_id": category_id,
            "filters": filters,
            "page": page,
            "cursor": cursor,
            "status": status,
            "updated_at_utc": utc_now_iso(),
        }
        write_json(self.path, self.payload)


class CacheStore:
    def __init__(self, path: Path = CACHE_PATH) -> None:
        self.path = path
        payload = load_json(path, {})
        self.payload = payload if isinstance(payload, dict) else {}

    def get(self, cache_type: str, key: str) -> Any | None:
        entry = self.payload.get(f"{cache_type}:{key}")
        if not isinstance(entry, dict):
            return None
        expires_at = safe_float(entry.get("expires_at_epoch"))
        if expires_at and time.time() <= expires_at:
            return entry.get("value")
        return None

    def set(self, cache_type: str, key: str, value: Any) -> None:
        ttl = CACHE_TTL_SECONDS.get(cache_type, 3600)
        self.payload[f"{cache_type}:{key}"] = {
            "cache_type": cache_type,
            "key": key,
            "value": value,
            "expires_at_epoch": time.time() + ttl,
            "created_at_utc": utc_now_iso(),
        }
        write_json(self.path, self.payload)


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
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]
        values[key.strip()] = value
    return values


def runtime_env_values() -> dict[str, str]:
    values = parse_env_file(ENV_PATH)
    values.update(parse_env_file(CODEX_CLOUD_ENV_PATH))
    values.update({key: value for key, value in os.environ.items() if value})
    return values


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_text = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", ascii_text.lower()).strip()


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", value or "")).strip()


def safe_float(value: Any, default: float = 0.0) -> float:
    try:
        if value in (None, ""):
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def safe_int(value: Any, default: int = 0) -> int:
    try:
        if value in (None, ""):
            return default
        return int(float(value))
    except (TypeError, ValueError):
        return default


def provider_auth(provider_key: str, integrations: list[dict[str, Any]], secrets: dict[str, Any]) -> ProviderAuth:
    integration = next(
        (item for item in integrations if isinstance(item, dict) and item.get("key") == provider_key),
        {},
    )
    provider_secrets = secrets.get(provider_key) if isinstance(secrets, dict) else {}
    merged_secrets = dict(provider_secrets if isinstance(provider_secrets, dict) else {})
    env_values = runtime_env_values()
    prefixes = {
        "cjdropshipping": ("CJDROPSHIPPING", "CJ"),
        "aliexpress": ("ALIEXPRESS",),
        "alibaba": ("ALIBABA",),
        "mercado_livre": ("MERCADOLIVRE", "MERCADO_LIVRE"),
        "shopee": ("SHOPEE", "SHOPPE"),
        "magalu": ("MAGALU",),
        "amazon": ("AMAZON",),
    }.get(provider_key, (provider_key.upper(),))
    alias_map = {
        "CLIENT_ID": ("clientId", "client_id"),
        "CLIENT_SECRET": ("clientSecret", "client_secret"),
        "ACCESS_TOKEN": ("accessToken", "access_token"),
        "REFRESH_TOKEN": ("refreshToken", "refresh_token"),
        "SELLER_ID": ("sellerId", "seller_id"),
        "OPEN_ID": ("openId", "open_id"),
    }
    for suffix, secret_keys in alias_map.items():
        value = ""
        for prefix in prefixes:
            value = str(env_values.get(f"{prefix}_{suffix}") or env_values.get(f"VALLEY_{prefix}_{suffix}") or "").strip()
            if value:
                break
        if not value:
            continue
        for secret_key in secret_keys:
            merged_secrets.setdefault(secret_key, value)
    return ProviderAuth(
        key=provider_key,
        integration=integration if isinstance(integration, dict) else {},
        secrets=merged_secrets,
    )


def bearer(auth: ProviderAuth) -> str:
    return str(auth.secrets.get("accessToken") or auth.secrets.get("access_token") or "").strip()


def refresh_token(auth: ProviderAuth) -> str:
    return str(auth.secrets.get("refreshToken") or auth.secrets.get("refresh_token") or "").strip()


def client_secret(auth: ProviderAuth) -> str:
    return str(auth.secrets.get("clientSecret") or auth.secrets.get("client_secret") or "").strip()


def client_id(auth: ProviderAuth) -> str:
    return str(auth.integration.get("clientId") or auth.secrets.get("clientId") or auth.secrets.get("client_id") or "").strip()


def seller_id(auth: ProviderAuth) -> str:
    return str(auth.integration.get("sellerId") or auth.secrets.get("sellerId") or auth.secrets.get("seller_id") or "").strip()


def retry_after_from_headers(headers: Any) -> float | None:
    if not headers:
        return None
    value = headers.get("Retry-After") if hasattr(headers, "get") else None
    if value is None:
        return None
    return safe_float(value, -1.0) if str(value).strip() else None


def get_json(
    url: str,
    headers: dict[str, str],
    timeout: int = 45,
    limiter: ConnectorRateLimiter | None = None,
) -> Any:
    request = Request(url, headers=headers)
    attempts = (limiter.policy.max_retries + 1) if limiter is not None else 1
    for attempt in range(attempts):
        if limiter is not None:
            limiter.before_request()
        try:
            with urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8", errors="replace"))
                if limiter is not None:
                    limiter.after_success(dict(response.headers.items()))
                return payload
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            retry_after = retry_after_from_headers(error.headers)
            if error.code in RETRYABLE_STATUS_CODES and limiter is not None and attempt < attempts - 1:
                time.sleep(limiter.after_failure(retry_after))
                continue
            if limiter is not None:
                limiter.after_failure(retry_after)
            raise RuntimeError(f"http_{error.code}: {detail[:500]}") from error
        except TimeoutError as error:
            if limiter is not None and attempt < attempts - 1:
                time.sleep(limiter.after_failure())
                continue
            raise RuntimeError(f"timeout: {error}") from error
        except URLError as error:
            if limiter is not None and attempt < attempts - 1:
                time.sleep(limiter.after_failure())
                continue
            raise RuntimeError(f"network_error: {error}") from error
    raise RuntimeError("retry_exhausted")


def insufficient(provider: str, capability: str, reason: str) -> dict[str, Any]:
    return {
        "provider": provider,
        "capability": capability,
        "status": "dados_insuficientes",
        "reason": reason,
        "allow_scraping": False,
        "checked_at_utc": utc_now_iso(),
    }


def env_flag(name: str, default: bool = True) -> bool:
    values = runtime_env_values()
    if name not in values:
        return default
    return str(values.get(name) or "").strip().lower() in {"1", "true", "yes", "on"}


def target_category_scope() -> list[dict[str, Any]]:
    config = load_json(CONFIG_PATH, {})
    scope = config.get("target_category_scope") if isinstance(config, dict) else []
    if not isinstance(scope, list):
        return []
    return [item for item in scope if isinstance(item, dict)]


def mock_categories(provider: str, limit: int) -> list[dict[str, Any]]:
    prefix = {"cjdropshipping": "cj", "aliexpress": "ae", "alibaba": "ab"}.get(provider, provider[:2])
    scope = sorted(target_category_scope(), key=lambda item: -safe_int(item.get("priority")))
    if not scope:
        scope = [
            {
                "internal_category_path": "Casa > Cozinha > Organizadores",
                "google_product_category_id": "638",
                "google_product_category_path": "Home & Garden > Kitchen & Dining > Kitchen Storage & Organization",
            }
        ]
    rows = [
        {
            "provider": provider,
            "category_id": f"{prefix}-{index + 1:03d}",
            "category_name": str(item.get("internal_category_path") or "").split(" > ")[-1],
            "category_path": str(item.get("google_product_category_path") or item.get("internal_category_path") or ""),
            "internal_category_path": str(item.get("internal_category_path") or ""),
            "google_product_category_id": str(item.get("google_product_category_id") or ""),
            "google_product_category_path": str(item.get("google_product_category_path") or ""),
            "priority": safe_int(item.get("priority")),
            "source": "configured_target_scope",
        }
        for index, item in enumerate(scope)
    ]
    return rows[:limit] if limit > 0 else rows


def mock_products(provider: str, categories: list[dict[str, Any]], max_per_category: int) -> list[dict[str, Any]]:
    products: list[dict[str, Any]] = []
    for category in categories:
        for index in range(max_per_category):
            source_id = f"{category['category_id']}-{index + 1}"
            title = f"{category['category_name']} premium para comercio local {index + 1}"
            price = 90.0 + (index * 18.0)
            stock = 120 - (index * 5)
            products.append(
                {
                    "candidate_id": str(uuid5(NAMESPACE_URL, f"valley:dropshipping:{provider}:{source_id}")),
                    "source_provider": provider,
                    "source_product_id": source_id,
                    "title": title,
                    "normalized_title": normalize_text(title),
                    "category_id": str(category.get("category_id") or ""),
                    "category_name": str(category.get("category_name") or ""),
                    "category_path": str(category.get("category_path") or ""),
                    "source_price_usd": 0.0,
                    "source_price_brl": price,
                    "currency": "BRL",
                    "shipping_cost_brl": 8.0,
                    "stock": stock,
                    "source_score": 76 - index,
                    "image_url": "",
                    "source_url": "",
                    "raw_snapshot": {"mock": True},
                }
            )
    return products


def official_filter_partitions(category: dict[str, Any]) -> list[dict[str, Any]]:
    category_id = str(category.get("category_id") or "")
    return [
        {"category_id": category_id, "partition_type": "category", "filters": {"category_id": category_id}},
        {"category_id": category_id, "partition_type": "stock_available", "filters": {"stock_available": True}},
        {"category_id": category_id, "partition_type": "min_orders", "filters": {"min_orders": 10}},
        {"category_id": category_id, "partition_type": "rating", "filters": {"min_rating": 4}},
        {"category_id": category_id, "partition_type": "warehouse", "filters": {"warehouse": "official_api_supported"}},
        {"category_id": category_id, "partition_type": "updated_since", "filters": {"updated_since": "last_successful_sync"}},
    ]


def quota_escalation_report(
    provider: str,
    endpoint: str,
    required_volume: int,
    max_allowed_volume: int,
    limit_found: str,
) -> dict[str, Any]:
    return {
        "provider": provider,
        "endpoint": endpoint,
        "limit_found": limit_found,
        "required_volume": required_volume,
        "max_allowed_volume": max_allowed_volume,
        "recommendation": "Solicitar aumento de quota, acesso parceiro, endpoint bulk ou feed oficial.",
        "created_at_utc": utc_now_iso(),
    }


def dedupe_candidates(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[str] = set()
    deduped: list[dict[str, Any]] = []
    for candidate in candidates:
        parts = [
            str(candidate.get("source_provider") or ""),
            str(candidate.get("source_product_id") or ""),
            str(candidate.get("supplier_sku") or ""),
            str(candidate.get("gtin") or ""),
            str(candidate.get("brand") or ""),
            str(candidate.get("model") or ""),
            str(candidate.get("normalized_title") or ""),
        ]
        key = str(uuid5(NAMESPACE_URL, "valley:dedupe:" + "|".join(parts)))
        if key in seen:
            continue
        seen.add(key)
        candidate["dedupe_key"] = key
        deduped.append(candidate)
    return deduped


def cj_headers(auth: ProviderAuth) -> dict[str, str]:
    token = bearer(auth)
    if not token:
        raise RuntimeError("CJ access token ausente.")
    return {
        "CJ-Access-Token": token,
        "Accept": "application/json",
        "User-Agent": "Valley/1.0",
    }


def cj_api_root(auth: ProviderAuth) -> str:
    base_url = str(auth.integration.get("baseUrl") or "https://developers.cjdropshipping.com").rstrip("/")
    return f"{base_url}/api2.0/v1"


def connector_rate_limiter(provider: str) -> ConnectorRateLimiter:
    policies = {
        "cjdropshipping": (CJDropshippingConnectorRateLimiter, RateLimitPolicy(provider, per_minute=45, per_hour=1500, per_day=12000)),
        "alibaba": (AlibabaConnectorRateLimiter, RateLimitPolicy(provider, per_minute=30, per_hour=900, per_day=8000)),
        "aliexpress": (AliExpressConnectorRateLimiter, RateLimitPolicy(provider, per_minute=30, per_hour=900, per_day=8000)),
        "mercado_livre": (MercadoLivreConnectorRateLimiter, RateLimitPolicy(provider, per_minute=45, per_hour=1800, per_day=12000)),
        "shopee": (ShopeeConnectorRateLimiter, RateLimitPolicy(provider, per_minute=30, per_hour=900, per_day=8000)),
        "magalu": (MagaluConnectorRateLimiter, RateLimitPolicy(provider, per_minute=30, per_hour=900, per_day=8000)),
        "amazon": (AmazonConnectorRateLimiter, RateLimitPolicy(provider, per_minute=20, per_hour=600, per_day=5000)),
    }
    klass, policy = policies.get(provider, (ConnectorRateLimiter, RateLimitPolicy(provider)))
    return klass(policy)


def import_cj_categories(auth: ProviderAuth, limit: int) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    errors: list[dict[str, Any]] = []
    categories: list[dict[str, Any]] = []
    endpoints = (
        "/product/getCategory",
        "/product/categoryList",
        "/product/listCategory",
    )
    limiter = connector_rate_limiter("cjdropshipping")
    cache = CacheStore()
    cached = cache.get("categories", "cjdropshipping")
    if isinstance(cached, list):
        return (cached[:limit] if limit > 0 else cached), []
    for endpoint in endpoints:
        try:
            payload = get_json(f"{cj_api_root(auth)}{endpoint}", headers=cj_headers(auth), limiter=limiter)
        except Exception as error:  # noqa: BLE001
            errors.append(insufficient("cjdropshipping", "categories", f"{endpoint}: {error}"))
            continue
        raw_data = payload.get("data") if isinstance(payload, dict) else payload
        extracted = flatten_category_payload(raw_data, "cjdropshipping")
        if extracted:
            categories = extracted[:limit] if limit > 0 else extracted
            cache.set("categories", "cjdropshipping", extracted)
            break
    if not categories:
        fallback = categories_from_existing_stock("cjdropshipping")
        if fallback:
            categories = fallback[:limit] if limit > 0 else fallback
            errors.append(insufficient("cjdropshipping", "categories", "API de categorias indisponivel; usando categorias ja importadas no runtime."))
        else:
            categories = mock_categories("cjdropshipping", limit)
            errors.append(insufficient("cjdropshipping", "categories", "API de categorias indisponivel; usando escopo real de categorias alvo configurado."))
    return categories, errors


def flatten_category_payload(payload: Any, provider: str) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []

    def walk(value: Any, path: list[str]) -> None:
        if isinstance(value, dict):
            raw_id = value.get("id") or value.get("categoryId") or value.get("category_id")
            raw_name = (
                value.get("name")
                or value.get("categoryName")
                or value.get("category_name")
                or value.get("nameEn")
                or value.get("nameCn")
            )
            if raw_id or raw_name:
                label = clean_text(str(raw_name or raw_id))
                found.append(
                    {
                        "provider": provider,
                        "category_id": str(raw_id or label),
                        "category_name": label,
                        "category_path": " > ".join([*path, label]) if label else " > ".join(path),
                    }
                )
                next_path = [*path, label] if label else path
            else:
                next_path = path
            for key in ("children", "childList", "childs", "subCategories", "list"):
                walk(value.get(key), next_path)
        elif isinstance(value, list):
            for item in value:
                walk(item, path)

    walk(payload, [])
    deduped: dict[tuple[str, str], dict[str, Any]] = {}
    for item in found:
        key = (str(item.get("category_id") or ""), normalize_text(str(item.get("category_path") or "")))
        deduped[key] = item
    return list(deduped.values())


def categories_from_existing_stock(provider_key: str) -> list[dict[str, Any]]:
    runtime = load_json(STOCK_RUNTIME_PATH, {})
    items = runtime.get("items") if isinstance(runtime, dict) else []
    categories: dict[str, dict[str, Any]] = {}
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict) or item.get("provider_key") != provider_key:
            continue
        category_id = str(item.get("source_category_id") or item.get("category") or "").strip()
        category_name = str(item.get("category") or category_id).strip()
        if not category_name:
            continue
        categories[category_name] = {
            "provider": provider_key,
            "category_id": category_id or category_name,
            "category_name": category_name,
            "category_path": str(item.get("google_product_category_path") or category_name),
            "source": "runtime_cache",
        }
    return list(categories.values())


def import_cj_products(auth: ProviderAuth, categories: list[dict[str, Any]], max_per_category: int) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    errors: list[dict[str, Any]] = []
    products: list[dict[str, Any]] = []
    limiter = connector_rate_limiter("cjdropshipping")
    checkpoints = CheckpointStore()
    for category in categories:
        category_name = str(category.get("category_name") or "").strip()
        category_id = str(category.get("category_id") or category_name).strip()
        if not category_name:
            continue
        filters = {"category_name": category_name, "limit": min(max_per_category, 60), "mode": "keyword"}
        checkpoint = checkpoints.get("cjdropshipping", category_id, filters)
        page = max(safe_int(checkpoint.get("page"), 1), 1)
        collected = 0
        while collected < max_per_category and page <= 4:
            params = urllib.parse.urlencode(
                {
                    "page": page,
                    "size": min(max_per_category, 60),
                    "keyWord": category_name,
                    "features": "enable_category",
                }
            )
            try:
                payload = get_json(
                    f"{cj_api_root(auth)}/product/listV2?{params}",
                    headers=cj_headers(auth),
                    timeout=60,
                    limiter=limiter,
                )
            except Exception as error:  # noqa: BLE001
                errors.append(insufficient("cjdropshipping", "products", f"{category_name}: {error}"))
                checkpoints.save("cjdropshipping", category_id, filters, page=page, status="failed")
                break
            data = payload.get("data") if isinstance(payload, dict) else {}
            content = data.get("content") if isinstance(data, dict) else []
            if not isinstance(content, list) or not content:
                break
            for entry in content:
                product_list = entry.get("productList") if isinstance(entry, dict) else []
                if not isinstance(product_list, list):
                    continue
                for raw in product_list:
                    if isinstance(raw, dict):
                        normalized = normalize_cj_product(raw, category)
                        if normalized:
                            products.append(normalized)
                            collected += 1
                            if collected >= max_per_category:
                                break
                if collected >= max_per_category:
                    break
            page += 1
            checkpoints.save("cjdropshipping", category_id, filters, page=page, status="running")
        checkpoints.save("cjdropshipping", category_id, filters, page=page, status="completed")
    return products, errors


def normalize_cj_product(raw: dict[str, Any], category: dict[str, Any]) -> dict[str, Any] | None:
    source_id = str(raw.get("id") or raw.get("pid") or "").strip()
    title = clean_text(str(raw.get("nameEn") or raw.get("name") or raw.get("productName") or ""))
    if not source_id or not title:
        return None
    sell_price_usd = safe_float(raw.get("sellPrice") or raw.get("listedPrice") or raw.get("price"))
    stock = safe_int(raw.get("warehouseInventoryNum") or raw.get("totalVerifiedInventory") or raw.get("inventory"))
    listed = safe_int(raw.get("listedNum"))
    image = str(raw.get("bigImage") or raw.get("image") or raw.get("productImage") or "").strip()
    return {
        "candidate_id": str(uuid5(NAMESPACE_URL, f"valley:dropshipping:cj:{source_id}")),
        "source_provider": "cjdropshipping",
        "source_product_id": source_id,
        "title": title,
        "normalized_title": normalize_text(title),
        "category_id": str(category.get("category_id") or ""),
        "category_name": str(category.get("category_name") or ""),
        "category_path": str(category.get("category_path") or ""),
        "source_price_usd": sell_price_usd,
        "source_price_brl": 0.0,
        "currency": "USD",
        "stock": stock,
        "source_score": min(100, 20 + min(listed, 60) + (20 if stock >= 50 else 0)),
        "image_url": image,
        "source_url": str(raw.get("productUrl") or ""),
        "raw_snapshot": raw,
    }


def import_unsupported_source(provider: str, auth: ProviderAuth) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if not bearer(auth) and not refresh_token(auth):
        return [], [insufficient(provider, "source_import", "Credenciais oficiais ausentes para importar categorias e produtos por API autorizada.")]
    return [], [insufficient(provider, "source_import", "Credencial existe, mas o conector oficial de categoria/produto ainda nao esta implementado neste runtime.")]


def import_unsupported_categories(provider: str, auth: ProviderAuth, limit: int) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    categories = mock_categories(provider, limit)
    reason = (
        "Credenciais oficiais ausentes para consultar categorias por API autorizada."
        if not bearer(auth) and not refresh_token(auth)
        else "Credencial existe, mas o conector oficial de categorias ainda nao esta implementado neste runtime."
    )
    return categories, [insufficient(provider, "categories", reason)]


def estimate_brl_prices(candidates: list[dict[str, Any]], usd_brl_rate: float = 5.25) -> None:
    for candidate in candidates:
        if safe_float(candidate.get("source_price_brl")) <= 0:
            usd = safe_float(candidate.get("source_price_usd"))
            if usd > 0:
                candidate["source_price_brl"] = round(usd * usd_brl_rate, 2)


def benchmark_with_provider(provider: str, candidate: dict[str, Any], auth: ProviderAuth) -> dict[str, Any]:
    if provider == "mercado_livre":
        if not env_flag("VALLEY_MARKETPLACE_ENABLE_REAL_MERCADOLIVRE"):
            return mock_benchmark(provider, candidate)
        return benchmark_mercadolivre(candidate, auth)
    if provider == "aliexpress":
        if candidate.get("source_provider") == "aliexpress":
            return {
                "provider": provider,
                "status": "source_price",
                "sample_count": 1,
                "min_price_brl": safe_float(candidate.get("source_price_brl")),
                "notes": "AliExpress usado como fonte e benchmark do proprio item.",
            }
        return insufficient(provider, "benchmark", "Conector de busca oficial AliExpress para comparacao ainda nao habilitado.")
    flag_name = f"VALLEY_MARKETPLACE_ENABLE_REAL_{provider.upper()}"
    if not env_flag(flag_name):
        return mock_benchmark(provider, candidate)
    return insufficient(provider, "benchmark", "Benchmark exige API/feed oficial homologado ou credenciais nao presentes; scraping bloqueado.")


def mock_benchmark(provider: str, candidate: dict[str, Any]) -> dict[str, Any]:
    base = safe_float(candidate.get("source_price_brl"))
    if "sem concorrencia" in str(candidate.get("normalized_title") or ""):
        return insufficient(provider, "benchmark", "Mock sem concorrente equivalente.")
    multiplier_by_provider = {
        "mercado_livre": 1.55,
        "shopee": 1.42,
        "magalu": 1.68,
        "amazon": 1.74,
        "aliexpress": 1.30,
    }
    final_price = round(base * multiplier_by_provider.get(provider, 1.5), 2)
    return {
        "provider": provider,
        "status": "ok",
        "sample_count": 1,
        "min_price_brl": final_price,
        "median_price_brl": final_price,
        "match_type": "SIMILAR_MATCH",
        "match_confidence": 74,
        "mock": True,
    }


def benchmark_mercadolivre(candidate: dict[str, Any], auth: ProviderAuth) -> dict[str, Any]:
    token = bearer(auth)
    if not token:
        return insufficient("mercado_livre", "benchmark", "Access token ausente para busca oficial no Mercado Livre.")
    base_url = str(auth.integration.get("baseUrl") or "https://api.mercadolibre.com").rstrip("/")
    query = urllib.parse.urlencode({"q": candidate.get("title"), "limit": 10})
    try:
        payload = get_json(
            f"{base_url}/sites/MLB/search?{query}",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
            limiter=connector_rate_limiter("mercado_livre"),
        )
    except Exception as error:  # noqa: BLE001
        return insufficient("mercado_livre", "benchmark", str(error))
    results = payload.get("results") if isinstance(payload, dict) else []
    prices = [
        safe_float(item.get("price"))
        for item in results
        if isinstance(item, dict) and str(item.get("currency_id") or "BRL") == "BRL" and safe_float(item.get("price")) > 0
    ]
    if not prices:
        return insufficient("mercado_livre", "benchmark", "API retornou sem amostras de preco BRL.")
    return {
        "provider": "mercado_livre",
        "status": "ok",
        "sample_count": len(prices),
        "min_price_brl": round(min(prices), 2),
        "median_price_brl": round(sorted(prices)[len(prices) // 2], 2),
    }


def evaluate_candidate(candidate: dict[str, Any], benchmarks: list[dict[str, Any]], rules: dict[str, Any]) -> dict[str, Any]:
    blocked_terms = [normalize_text(term) for term in rules.get("blocked_terms", [])]
    preferred_terms = [normalize_text(term) for term in rules.get("preferred_terms_ptbr", [])]
    title = str(candidate.get("normalized_title") or "")
    source_price = safe_float(candidate.get("source_price_brl"))
    stock = safe_int(candidate.get("stock"))
    source_score = safe_int(candidate.get("source_score"))
    failures: list[str] = []

    if any(term and term in title for term in blocked_terms):
        failures.append("blocked_term")
    if source_price <= 0:
        failures.append("missing_source_price")
    if source_price > safe_float(rules.get("max_price_brl"), 900):
        failures.append("price_above_limit")
    if stock < safe_int(rules.get("min_stock"), 10):
        failures.append("stock_below_minimum")
    if source_score < safe_int(rules.get("min_source_score"), 35):
        failures.append("source_score_below_minimum")

    ok_benchmarks = [item for item in benchmarks if item.get("status") in {"ok", "source_price"} and safe_float(item.get("min_price_brl")) > 0]
    market_floor = min((safe_float(item.get("min_price_brl")) for item in ok_benchmarks), default=0.0)
    target_price = round(source_price * (1 + safe_float(rules.get("min_margin_pct"), 22) / 100), 2) if source_price else 0.0
    estimated_profit = round(target_price - source_price, 2) if target_price else 0.0
    advantage_pct = round(((market_floor - target_price) / market_floor) * 100, 2) if market_floor > 0 and target_price > 0 else 0.0

    if estimated_profit < safe_float(rules.get("min_estimated_profit_brl"), 18):
        failures.append("profit_below_minimum")
    ignore_marketplace_advantage = bool(rules.get("ignore_marketplace_advantage"))
    if (
        not ignore_marketplace_advantage
        and market_floor > 0
        and advantage_pct < safe_float(rules.get("min_marketplace_advantage_pct"), 10)
    ):
        failures.append("marketplace_advantage_below_minimum")

    local_fit_score = min(100, source_score + sum(8 for term in preferred_terms if term and term in title))
    reliable_competitors = len(ok_benchmarks)
    price_status = (
        "APPROVED_NO_COMPETITION"
        if reliable_competitors == 0 and not failures
        else "APPROVED_PRICE_ADVANTAGE"
        if reliable_competitors > 0 and not failures
        else "REJECTED_PRICE_NOT_COMPETITIVE"
        if "marketplace_advantage_below_minimum" in failures
        else "REJECTED_COMPLIANCE"
        if "blocked_term" in failures
        else "REJECTED_LOW_SCORE"
        if "source_score_below_minimum" in failures or "stock_below_minimum" in failures
        else "REVIEW_REQUIRED"
    )
    approved = price_status in {"APPROVED_NO_COMPETITION", "APPROVED_PRICE_ADVANTAGE"}
    return {
        "approved": approved,
        "status": price_status,
        "rejection_reasons": failures,
        "target_price_brl": target_price,
        "estimated_profit_brl": estimated_profit,
        "market_floor_brl": market_floor,
        "marketplace_advantage_pct": advantage_pct,
        "local_fit_score": local_fit_score,
    }


def google_feed_item(row: dict[str, Any]) -> dict[str, Any]:
    evaluation = row.get("commercial_evaluation") if isinstance(row.get("commercial_evaluation"), dict) else {}
    price = safe_float(evaluation.get("target_price_brl") or row.get("final_customer_cost_brl") or row.get("source_price_brl"))
    category_path = str(row.get("category_path") or row.get("category_name") or "")
    return {
        "id": row.get("candidate_id"),
        "google_product_category": row.get("google_product_category_path") or category_path,
        "product_type": category_path,
        "title": row.get("title"),
        "description": row.get("description_normalized_pt_br") or row.get("title"),
        "link": row.get("source_url") or "",
        "image_link": row.get("image_url") or "",
        "additional_image_link": [],
        "availability": "in_stock" if safe_int(row.get("stock")) > 0 else "out_of_stock",
        "price": f"{price:.2f} BRL",
        "sale_price": f"{price:.2f} BRL",
        "brand": row.get("brand") or "Valley",
        "gtin": row.get("gtin") or "",
        "mpn": row.get("mpn") or row.get("source_product_id") or "",
        "condition": "new",
        "shipping": {
            "country": "BR",
            "price": f"{safe_float(row.get('shipping_cost_brl')):.2f} BRL",
        },
        "shipping_weight": row.get("package_weight") or "",
        "custom_label_0": row.get("source_provider"),
        "custom_label_1": row.get("category_name"),
        "custom_label_2": evaluation.get("status"),
        "custom_label_3": str(evaluation.get("estimated_profit_brl") or ""),
        "custom_label_4": str(evaluation.get("local_fit_score") or row.get("source_score") or ""),
    }


def category_report(evaluated: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_category: dict[str, dict[str, Any]] = {}
    for row in evaluated:
        key = str(row.get("category_name") or "Sem categoria")
        report = by_category.setdefault(
            key,
            {
                "category": key,
                "imported_total": 0,
                "compared_total": 0,
                "approved_total": 0,
                "rejected_total": 0,
                "rejection_reasons": {},
                "profit_sum": 0.0,
                "top_products": [],
            },
        )
        report["imported_total"] += 1
        report["compared_total"] += 1
        evaluation = row.get("commercial_evaluation") if isinstance(row.get("commercial_evaluation"), dict) else {}
        if evaluation.get("approved"):
            report["approved_total"] += 1
            report["profit_sum"] += safe_float(evaluation.get("estimated_profit_brl"))
            report["top_products"].append(
                {
                    "candidate_id": row.get("candidate_id"),
                    "title": row.get("title"),
                    "source_provider": row.get("source_provider"),
                    "estimated_profit_brl": evaluation.get("estimated_profit_brl"),
                    "local_commerce_score": evaluation.get("local_fit_score"),
                }
            )
        else:
            report["rejected_total"] += 1
            for reason in evaluation.get("rejection_reasons") or ["unknown"]:
                report["rejection_reasons"][reason] = report["rejection_reasons"].get(reason, 0) + 1
    for report in by_category.values():
        approved_total = max(int(report["approved_total"]), 1)
        report["average_profit_brl"] = round(float(report.pop("profit_sum")) / approved_total, 2)
        report["top_products"] = sorted(
            report["top_products"],
            key=lambda item: -safe_float(item.get("estimated_profit_brl")),
        )[:10]
    return list(by_category.values())


def run_selection(
    max_categories: int,
    max_products_per_category: int,
    max_candidates: int,
    dry_run: bool,
    ignore_marketplace_advantage: bool = False,
) -> dict[str, Any]:
    config = load_json(CONFIG_PATH, {})
    integrations = load_json(INTEGRATIONS_PATH, [])
    secrets = load_json(SECRETS_PATH, {})
    rules = config.get("commercial_rules") if isinstance(config, dict) else {}
    rules = rules if isinstance(rules, dict) else {}
    if ignore_marketplace_advantage or env_flag("VALLEY_IGNORE_MARKETPLACE_ADVANTAGE"):
        rules = dict(rules)
        rules["ignore_marketplace_advantage"] = True

    all_categories: list[dict[str, Any]] = []
    candidates: list[dict[str, Any]] = []
    limitations: list[dict[str, Any]] = []
    quota_reports: list[dict[str, Any]] = []

    for provider in SOURCE_PROVIDERS:
        auth = provider_auth(provider, integrations if isinstance(integrations, list) else [], secrets if isinstance(secrets, dict) else {})
        if provider == "cjdropshipping":
            if env_flag("VALLEY_DROPSHIPPING_ENABLE_REAL_CJ"):
                categories, errors = import_cj_categories(auth, max_categories)
                limitations.extend(errors)
                all_categories.extend(categories)
                products, errors = import_cj_products(auth, categories, max_products_per_category)
                limitations.extend(errors)
                candidates.extend(products)
            else:
                categories = mock_categories(provider, max_categories)
                all_categories.extend(categories)
                candidates.extend(mock_products(provider, categories, max_products_per_category))
                limitations.append(insufficient(provider, "source_import", "Conector real CJ desligado; usando mock ate VALLEY_DROPSHIPPING_ENABLE_REAL_CJ=true."))
                if max_products_per_category < safe_int(os.environ.get("VALLEY_DROPSHIPPING_MIN_IMPORTED_CANDIDATES_PER_CATEGORY"), 1000):
                    quota_reports.append(
                        quota_escalation_report(
                            provider,
                            "mock/product/list",
                            safe_int(os.environ.get("VALLEY_DROPSHIPPING_MIN_IMPORTED_CANDIDATES_PER_CATEGORY"), 1000),
                            max_products_per_category,
                            "Execucao local limitada por parametro; carga real deve paginar ate a meta usando filtros oficiais.",
                        )
                    )
        else:
            flag = f"VALLEY_DROPSHIPPING_ENABLE_REAL_{provider.upper()}"
            if env_flag(flag):
                categories, errors = import_unsupported_categories(provider, auth, max_categories)
                all_categories.extend(categories)
                limitations.extend(errors)
                products, errors = import_unsupported_source(provider, auth)
                limitations.extend(errors)
                candidates.extend(products)
            else:
                categories = mock_categories(provider, max_categories)
                all_categories.extend(categories)
                candidates.extend(mock_products(provider, categories, max_products_per_category))
                limitations.append(insufficient(provider, "source_import", f"Conector real {provider} desligado; usando mock ate {flag}=true."))
                if max_products_per_category < safe_int(os.environ.get("VALLEY_DROPSHIPPING_MIN_IMPORTED_CANDIDATES_PER_CATEGORY"), 1000):
                    quota_reports.append(
                        quota_escalation_report(
                            provider,
                            "mock/product/list",
                            safe_int(os.environ.get("VALLEY_DROPSHIPPING_MIN_IMPORTED_CANDIDATES_PER_CATEGORY"), 1000),
                            max_products_per_category,
                            "Execucao local limitada por parametro; carga real deve paginar ate a meta usando filtros oficiais.",
                        )
                    )

    estimate_brl_prices(candidates)
    candidates = dedupe_candidates(candidates)
    candidates = sorted(
        candidates,
        key=lambda item: (-safe_int(item.get("source_score")), -safe_int(item.get("stock")), safe_float(item.get("source_price_brl"))),
    )[:max_candidates]

    benchmark_auth = {
        provider: provider_auth(provider, integrations if isinstance(integrations, list) else [], secrets if isinstance(secrets, dict) else {})
        for provider in BENCHMARK_PROVIDERS
    }
    evaluated: list[dict[str, Any]] = []
    eligible: list[dict[str, Any]] = []
    for candidate in candidates:
        benchmarks = [benchmark_with_provider(provider, candidate, benchmark_auth[provider]) for provider in BENCHMARK_PROVIDERS]
        evaluation = evaluate_candidate(candidate, benchmarks, rules)
        row = {
            **{key: value for key, value in candidate.items() if key != "raw_snapshot"},
            "benchmarks": benchmarks,
            "commercial_evaluation": evaluation,
            "selected_at_utc": utc_now_iso(),
        }
        if evaluation["approved"]:
            row["google_merchant_item"] = google_feed_item(row)
        evaluated.append(row)
        if evaluation["approved"]:
            eligible.append(row)

    status = {
        "status": "ok",
        "service": "valley-dropshipping-product-selection",
        "generated_at_utc": utc_now_iso(),
        "source_providers": list(SOURCE_PROVIDERS),
        "benchmark_providers": list(BENCHMARK_PROVIDERS),
        "allow_scraping": False,
        "ignore_marketplace_advantage": bool(rules.get("ignore_marketplace_advantage")),
        "categories_total": len(all_categories),
        "candidates_total": len(candidates),
        "eligible_total": len(eligible),
        "rejected_total": len(evaluated) - len(eligible),
        "limitations_total": len(limitations),
        "limitations": limitations[:200],
        "quota_escalation_total": len(quota_reports),
        "quota_escalation": quota_reports[:200],
        "pagination_policy": {
            "supports_page_limit": True,
            "supports_cursor": True,
            "checkpoint_path": str(CHECKPOINTS_PATH.relative_to(ROOT)),
            "resume_from_checkpoint": True,
            "max_retries": 4,
            "retryable_status_codes": sorted(RETRYABLE_STATUS_CODES),
            "no_infinite_loop": True,
        },
        "partition_strategy": {
            "allowed_filters": [
                "category",
                "subcategoria",
                "faixa_de_preco",
                "data_de_atualizacao",
                "pais",
                "warehouse",
                "estoque_disponivel",
                "avaliacao_minima",
                "quantidade_minima_de_pedidos",
            ],
            "example_partitions": official_filter_partitions(all_categories[0]) if all_categories else [],
        },
        "cache_policy": {
            "path": str(CACHE_PATH.relative_to(ROOT)),
            "ttl_seconds": CACHE_TTL_SECONDS,
        },
        "category_report": category_report(evaluated),
        "outputs": {
            "categories": str(CATEGORIES_PATH.relative_to(ROOT)),
            "candidates": str(CANDIDATES_PATH.relative_to(ROOT)),
            "eligible": str(ELIGIBLE_PATH.relative_to(ROOT)),
            "status": str(STATUS_PATH.relative_to(ROOT)),
            "quota_escalation": str(QUOTA_REPORT_PATH.relative_to(ROOT)),
        },
        "dry_run": dry_run,
    }

    if not dry_run:
        write_json(CATEGORIES_PATH, {"status": "ok", "generated_at_utc": utc_now_iso(), "items": all_categories})
        write_json(CANDIDATES_PATH, {"status": "ok", "generated_at_utc": utc_now_iso(), "items": evaluated})
        write_json(ELIGIBLE_PATH, {"status": "ok", "generated_at_utc": utc_now_iso(), "items": eligible})
        write_json(STATUS_PATH, status)
        write_json(QUOTA_REPORT_PATH, {"status": "ok", "generated_at_utc": utc_now_iso(), "items": quota_reports})

    return status


def main() -> None:
    parser = argparse.ArgumentParser(description="Seleciona produtos elegiveis para dropshipping Valley sem scraping.")
    parser.add_argument("--max-categories", type=int, default=40)
    parser.add_argument("--max-products-per-category", type=int, default=12)
    parser.add_argument("--max-candidates", type=int, default=120)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--ignore-marketplace-advantage",
        action="store_true",
        help="Libera a regra de vantagem minima de marketplace, inclusive o corte de 10 por cento.",
    )
    args = parser.parse_args()
    payload = run_selection(
        max_categories=args.max_categories,
        max_products_per_category=args.max_products_per_category,
        max_candidates=args.max_candidates,
        dry_run=args.dry_run,
        ignore_marketplace_advantage=args.ignore_marketplace_advantage,
    )
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
