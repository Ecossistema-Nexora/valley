#!/usr/bin/env python3
"""Materializa o catalogo real do STOCK em modo multi-provedor.

Mantem o shell embarcado leve com uma vitrine reduzida e sanitizada para o
bundle publico, mas grava o catalogo completo em runtime para consumo via API.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import threading
import time
import unicodedata
import urllib.parse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import NAMESPACE_URL, uuid5


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
FULL_STOCK_PATH = RUNTIME_DIR / "valley-stock-real-catalog.json"
INTEGRATIONS_PATH = RUNTIME_DIR / "valley-admin-integrations.json"
SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"

MERCADOLIVRE_KEY = "mercado_livre"
MERCADOLIVRE_BASE_URL = "https://api.mercadolibre.com"
SITE_ID = "MLB"
SEARCH_PAGE_SIZE = 50
THREAD_POOL_SIZE = 12

CJDROPSHIPPING_KEY = "cjdropshipping"
CJDROPSHIPPING_BASE_URL = "https://developers.cjdropshipping.com"
CJ_PAGE_SIZE = 24
CJ_MIN_INTERVAL_SECONDS = 1.15

PTAX_BASE_URL = "https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata"
PREVIEW_LIMIT = 80

PUBLIC_STOCK_INTERNAL_FIELDS = {
    "supplier_name",
    "supplier_type",
    "supplier_model",
    "supplier_visibility",
    "provider_key",
    "provider_status",
    "channel_label",
    "official_store_id",
    "source_product_id",
    "source_parent_id",
    "source_domain_id",
    "source_category_id",
    "source_item_id",
    "source_seller_id",
    "source_status",
    "source_permalink",
    "source_collected_at_utc",
    "source_currency",
    "fx_rate_brl_per_usd",
    "fx_reference_date",
    "tracking_capable",
    "tracking_mode",
    "tracking_webhook_enabled",
    "tracking_status",
    "source_inventory_verified",
    "source_inventory_unverified",
    "source_verified_warehouses",
    "source_relevance_score",
    "provider_priority",
}


def utc_now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def stable_uuid(name: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"valley-stock::{name}"))


def load_json(path: Path, fallback: Any) -> Any:
    if not path.exists():
        return fallback
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def first_attr_value(attributes: list[dict[str, Any]], attribute_id: str) -> str:
    for attribute in attributes:
        if str(attribute.get("id")) != attribute_id:
            continue
        value_name = str(attribute.get("value_name") or "").strip()
        if value_name:
            return value_name
        values = attribute.get("values") or []
        if isinstance(values, list):
            for value in values:
                if isinstance(value, dict):
                    candidate = str(value.get("name") or "").strip()
                    if candidate:
                        return candidate
    return ""


def normalize_band(price_brl: float) -> str:
    if price_brl < 100:
        return "Ate R$ 99"
    if price_brl < 250:
        return "R$ 100-249"
    if price_brl < 500:
        return "R$ 250-499"
    if price_brl < 1000:
        return "R$ 500-999"
    if price_brl < 2000:
        return "R$ 1.000-1.999"
    return "Acima de R$ 2.000"


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.lower())
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", ascii_only).strip()


def clean_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "")
    return re.sub(r"\s+", " ", text).strip()


def parse_string_array(raw_value: Any) -> list[str]:
    if isinstance(raw_value, list):
        values = raw_value
    else:
        text = str(raw_value or "").strip()
        if not text:
            return []
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            values = [text]
        else:
            values = parsed if isinstance(parsed, list) else [text]

    normalized: list[str] = []
    for value in values:
        candidate = str(value or "").strip()
        if candidate and candidate not in normalized:
            normalized.append(candidate)
    return normalized


def safe_int(value: Any, default: int = 0) -> int:
    try:
        if value is None or value == "":
            return default
        return int(float(str(value).strip()))
    except (TypeError, ValueError):
        return default


def parse_price_window(raw_value: Any) -> tuple[float, float]:
    if raw_value is None:
        return 0.0, 0.0
    numbers = re.findall(r"\d+(?:\.\d+)?", str(raw_value))
    parsed = [float(number) for number in numbers]
    if not parsed:
        return 0.0, 0.0
    if len(parsed) == 1:
        return parsed[0], parsed[0]
    return min(parsed), max(parsed)


def stock_identity(provider_key: str, source_product_id: str) -> str:
    return f"{provider_key}:{source_product_id}"


def sanitize_public_stock_item(item: dict[str, Any]) -> dict[str, Any]:
    sanitized = dict(item)
    for key in PUBLIC_STOCK_INTERNAL_FIELDS:
        sanitized.pop(key, None)
    return sanitized


def build_description(category: str, brand: str, model: str, offer_count: int, first_offer: dict[str, Any]) -> str:
    shipping = first_offer.get("shipping") if isinstance(first_offer.get("shipping"), dict) else {}
    free_shipping = bool(shipping.get("free_shipping"))
    warranty = str(first_offer.get("warranty") or "").strip()
    seller_address = first_offer.get("seller_address") if isinstance(first_offer.get("seller_address"), dict) else {}
    city = ""
    state = ""
    if isinstance(seller_address.get("city"), dict):
        city = str(seller_address["city"].get("name") or "").strip()
    if isinstance(seller_address.get("state"), dict):
        state = str(seller_address["state"].get("name") or "").strip()
    fragments = [
        f"Curadoria Valley para {category.lower()} com {offer_count} ofertas ativas no catálogo.",
        f"Marca {brand}." if brand else "",
        f"Modelo {model}." if model else "",
        "Frete grátis habilitado." if free_shipping else "",
        f"Saída operacional em {city}/{state}." if city and state else "",
        f"Garantia declarada: {warranty}." if warranty else "",
    ]
    return " ".join(fragment for fragment in fragments if fragment)


def build_tags(category: str, brand: str, model: str, free_shipping: bool) -> list[str]:
    tags = ["Catalogo real", category]
    if brand:
        tags.append(brand)
    if model:
        tags.append(model)
    if free_shipping:
        tags.append("Frete gratis")
    return tags


@dataclass(frozen=True)
class SourcePlan:
    domain_id: str
    queries: tuple[str, ...]
    collection_label: str
    google_category_id: str
    google_category_path: str
    target_items: int


@dataclass(frozen=True)
class CategoryPlan:
    category: str
    sources: tuple[SourcePlan, ...]


@dataclass(frozen=True)
class CjSourcePlan:
    queries: tuple[str, ...]
    collection_label: str
    google_category_id: str
    google_category_path: str
    target_items: int
    allowed_category_terms: tuple[str, ...]
    required_title_terms: tuple[str, ...] = ()
    blocked_title_terms: tuple[str, ...] = ()
    blocked_category_terms: tuple[str, ...] = ()
    min_listed_num: int = 0


@dataclass(frozen=True)
class CjCategoryPlan:
    category: str
    sources: tuple[CjSourcePlan, ...]


MERCADOLIVRE_CATEGORY_PLANS: tuple[CategoryPlan, ...] = (
    CategoryPlan(
        category="Smartphones",
        sources=(
            SourcePlan(
                domain_id="MLB-CELLPHONES",
                queries=(
                    "smartphone",
                    "celular samsung",
                    "iphone",
                    "xiaomi celular",
                    "motorola g",
                    "celular 128gb",
                ),
                collection_label="Valley Edge",
                google_category_id="267",
                google_category_path="Electronics > Communications > Telephony > Mobile Phones",
                target_items=500,
            ),
        ),
    ),
    CategoryPlan(
        category="Audio",
        sources=(
            SourcePlan(
                domain_id="MLB-HEADPHONES",
                queries=("fone bluetooth", "fone sem fio", "headset gamer", "earbuds bluetooth"),
                collection_label="Valley Pulse",
                google_category_id="543626",
                google_category_path="Electronics > Audio > Audio Components > Headphones & Headsets > Headphones",
                target_items=250,
            ),
            SourcePlan(
                domain_id="MLB-SPEAKERS",
                queries=("caixa de som bluetooth", "soundbar bluetooth", "caixa bluetooth", "speaker bluetooth"),
                collection_label="Valley Sound",
                google_category_id="249",
                google_category_path="Electronics > Audio > Audio Components > Speakers",
                target_items=250,
            ),
        ),
    ),
    CategoryPlan(
        category="Wearables",
        sources=(
            SourcePlan(
                domain_id="MLB-SMARTWATCHES",
                queries=(
                    "smart band",
                    "pulseira inteligente",
                    "relogio inteligente",
                    "smartwatch",
                    "watch fit",
                    "pulseira fitness",
                    "mi band",
                ),
                collection_label="Valley Motion",
                google_category_id="201",
                google_category_path="Apparel & Accessories > Jewelry > Watches",
                target_items=500,
            ),
        ),
    ),
    CategoryPlan(
        category="Casa",
        sources=(
            SourcePlan(
                domain_id="MLB-ROBOT_VACUUMS",
                queries=("aspirador robo", "robo aspirador", "aspirador inteligente", "aspirador automatico"),
                collection_label="Valley Casa",
                google_category_id="619",
                google_category_path="Home & Garden > Household Appliances > Vacuums",
                target_items=500,
            ),
        ),
    ),
    CategoryPlan(
        category="Creator Gear",
        sources=(
            SourcePlan(
                domain_id="MLB-CONTINUOUS_LIGHTING",
                queries=("ring light", "iluminador led", "luz de estudio", "painel de led fotografia"),
                collection_label="Valley Studio",
                google_category_id="42",
                google_category_path="Cameras & Optics > Photography > Lighting & Studio",
                target_items=250,
            ),
            SourcePlan(
                domain_id="MLB-MICROPHONES",
                queries=("microfone condensador", "microfone sem fio", "microfone podcast", "lapela sem fio"),
                collection_label="Valley Voice",
                google_category_id="234",
                google_category_path="Electronics > Audio > Audio Components > Microphones",
                target_items=250,
            ),
        ),
    ),
    CategoryPlan(
        category="Premium Tech",
        sources=(
            SourcePlan(
                domain_id="MLB-STREAMING_MEDIA_DEVICES",
                queries=("tv box", "fire tv", "roku streaming", "media streaming", "google tv"),
                collection_label="Valley Stream",
                google_category_id="5276",
                google_category_path="Electronics > Video > Video Players & Recorders > Streaming & Home Media Players",
                target_items=140,
            ),
            SourcePlan(
                domain_id="MLB-MOBILE_DEVICE_CHARGERS",
                queries=("carregador usb-c", "carregador turbo", "fonte carregador", "power adapter usb c"),
                collection_label="Valley Charge",
                google_category_id="505295",
                google_category_path="Electronics > Electronics Accessories > Power > Power Adapters & Chargers",
                target_items=360,
            ),
        ),
    ),
    CategoryPlan(
        category="Mobilidade",
        sources=(
            SourcePlan(
                domain_id="MLB-ELECTRIC_SCOOTERS",
                queries=("patinete eletrico", "scooter eletrica", "scooter eletrico adulto"),
                collection_label="Valley Ride",
                google_category_id="5879",
                google_category_path="Sporting Goods > Outdoor Recreation > Riding Scooters",
                target_items=300,
            ),
            SourcePlan(
                domain_id="MLB-KICK_SCOOTERS",
                queries=("patinete", "patinete adulto", "scooter dobravel"),
                collection_label="Valley Ride",
                google_category_id="5879",
                google_category_path="Sporting Goods > Outdoor Recreation > Riding Scooters",
                target_items=200,
            ),
        ),
    ),
    CategoryPlan(
        category="Smart Living",
        sources=(
            SourcePlan(
                domain_id="MLB-ELECTRICAL_OUTLETS",
                queries=("tomada inteligente", "plug inteligente", "wifi smart plug"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=100,
            ),
            SourcePlan(
                domain_id="MLB-LIGHT_BULBS",
                queries=("lampada inteligente", "lampada wifi", "lampada smart"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=100,
            ),
            SourcePlan(
                domain_id="MLB-SURVEILLANCE_CAMERAS",
                queries=("camera wifi inteligente", "camera seguranca wifi", "camera ip smart"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=120,
            ),
            SourcePlan(
                domain_id="MLB-HOME_ALARMS_AND_SENSORS",
                queries=("sensor porta inteligente", "alarme sensor casa", "sensor presença wifi"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=80,
            ),
            SourcePlan(
                domain_id="MLB-ELECTRIC_LOCKS",
                queries=("fechadura digital smart", "fechadura eletrica wifi", "fechadura biometrica"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=100,
            ),
        ),
    ),
)


CJ_CATEGORY_PLANS: tuple[CjCategoryPlan, ...] = (
    CjCategoryPlan(
        category="Smartphones",
        sources=(
            CjSourcePlan(
                queries=("android smartphone", "5g smartphone", "unlocked smartphone"),
                collection_label="Valley Edge",
                google_category_id="267",
                google_category_path="Electronics > Communications > Telephony > Mobile Phones",
                target_items=120,
                allowed_category_terms=("mobile phones",),
                required_title_terms=("phone", "smartphone"),
                blocked_title_terms=("case", "cover", "protector", "film", "holder", "battery pack", "screen"),
                min_listed_num=10,
            ),
        ),
    ),
    CjCategoryPlan(
        category="Audio",
        sources=(
            CjSourcePlan(
                queries=("wireless headphones", "bluetooth earbuds", "gaming headset"),
                collection_label="Valley Pulse",
                google_category_id="543626",
                google_category_path="Electronics > Audio > Audio Components > Headphones & Headsets > Headphones",
                target_items=140,
                allowed_category_terms=("headphones", "earphones", "smart wearable accessories"),
                required_title_terms=("headphone", "earphone", "earbud", "headset"),
                blocked_title_terms=("case", "cover", "holder", "sticker", "bag"),
                min_listed_num=20,
            ),
        ),
    ),
    CjCategoryPlan(
        category="Wearables",
        sources=(
            CjSourcePlan(
                queries=("smart watch", "fitness band", "smartwatch"),
                collection_label="Valley Motion",
                google_category_id="201",
                google_category_path="Apparel & Accessories > Jewelry > Watches",
                target_items=140,
                allowed_category_terms=("smart watches", "smart wearable accessories"),
                required_title_terms=("watch", "band"),
                blocked_title_terms=("strap", "case", "protector"),
                min_listed_num=20,
            ),
        ),
    ),
    CjCategoryPlan(
        category="Casa",
        sources=(
            CjSourcePlan(
                queries=("robot vacuum", "smart robot vacuum"),
                collection_label="Valley Casa",
                google_category_id="619",
                google_category_path="Home & Garden > Household Appliances > Vacuums",
                target_items=90,
                allowed_category_terms=("vacuum", "home appliance", "power tools"),
                required_title_terms=("robot", "vacuum"),
                blocked_title_terms=("accessories", "parts", "kit", "filter", "brush", "mop", "cover", "tube"),
                min_listed_num=15,
            ),
        ),
    ),
    CjCategoryPlan(
        category="Creator Gear",
        sources=(
            CjSourcePlan(
                queries=("ring light", "led ring light"),
                collection_label="Valley Studio",
                google_category_id="42",
                google_category_path="Cameras & Optics > Photography > Lighting & Studio",
                target_items=70,
                allowed_category_terms=("camera & photo", "camera & photo accessories"),
                required_title_terms=("ring", "light"),
                blocked_title_terms=("zircon", "jewelry", "wedding", "female ring", "sunflower ring"),
                blocked_category_terms=("fashion jewelry", "rings"),
                min_listed_num=15,
            ),
            CjSourcePlan(
                queries=("podcast microphone", "microphone", "wireless microphone"),
                collection_label="Valley Voice",
                google_category_id="234",
                google_category_path="Electronics > Audio > Audio Components > Microphones",
                target_items=80,
                allowed_category_terms=("microphones",),
                required_title_terms=("microphone",),
                blocked_title_terms=("doll", "bracket", "holder", "stand", "foam", "windscreen", "cover"),
                min_listed_num=15,
            ),
        ),
    ),
    CjCategoryPlan(
        category="Premium Tech",
        sources=(
            CjSourcePlan(
                queries=("phone charger", "wireless charger", "usb c charger"),
                collection_label="Valley Charge",
                google_category_id="505295",
                google_category_path="Electronics > Electronics Accessories > Power > Power Adapters & Chargers",
                target_items=150,
                allowed_category_terms=("chargers",),
                required_title_terms=("charger",),
                blocked_title_terms=("repair", "board", "adapter board"),
                min_listed_num=20,
            ),
        ),
    ),
    CjCategoryPlan(
        category="Smart Living",
        sources=(
            CjSourcePlan(
                queries=("smart plug", "wifi smart plug", "smart socket"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=110,
                allowed_category_terms=("home electronic accessories", "home appliance parts", "camera"),
                required_title_terms=("smart plug", "smart socket", "wifi"),
                blocked_title_terms=("extension cable", "adapter only"),
                min_listed_num=15,
            ),
            CjSourcePlan(
                queries=("wifi security camera", "smart security camera"),
                collection_label="Valley Sense",
                google_category_id="2413",
                google_category_path="Hardware > Power & Electrical Supplies > Home Automation Kits",
                target_items=70,
                allowed_category_terms=("camera", "surveillance"),
                required_title_terms=("camera",),
                blocked_title_terms=("mount", "case", "tripod"),
                min_listed_num=15,
            ),
        ),
    ),
)


def fetch_usd_brl_rate() -> tuple[float, str]:
    end_date = date.today()
    start_date = end_date - timedelta(days=7)
    url = (
        f"{PTAX_BASE_URL}/CotacaoMoedaPeriodo(moeda=@moeda,dataInicial=@dataInicial,"
        f"dataFinalCotacao=@dataFinalCotacao)?"
        + urllib.parse.urlencode(
            {
                "@moeda": "'USD'",
                "@dataInicial": f"'{start_date:%m-%d-%Y}'",
                "@dataFinalCotacao": f"'{end_date:%m-%d-%Y}'",
                "$format": "json",
            }
        )
    )
    request = Request(url, headers={"Accept": "application/json"})
    with urlopen(request, timeout=45) as response:
        payload = json.loads(response.read().decode("utf-8", errors="replace"))
    values = payload.get("value")
    if not isinstance(values, list) or not values:
        raise RuntimeError("Banco Central não retornou cotação PTAX USD/BRL.")
    latest = max(
        (
            value
            for value in values
            if isinstance(value, dict) and value.get("cotacaoVenda") is not None
        ),
        key=lambda value: str(value.get("dataHoraCotacao") or ""),
    )
    rate = float(latest["cotacaoVenda"])
    reference = str(latest.get("dataHoraCotacao") or "")
    return rate, reference


class MercadoLivreClient:
    def __init__(self, integrations: list[dict[str, Any]], secrets: dict[str, Any]) -> None:
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == MERCADOLIVRE_KEY),
            None,
        )
        provider_secrets = secrets.get(MERCADOLIVRE_KEY) if isinstance(secrets, dict) else None
        if not isinstance(provider, dict) or not isinstance(provider_secrets, dict):
            raise RuntimeError("Integração do Mercado Livre não está ativa com credenciais persistidas.")

        self.base_url = str(provider.get("baseUrl") or MERCADOLIVRE_BASE_URL).rstrip("/")
        self.client_id = str(provider.get("clientId") or "").strip()
        self.client_secret = str(provider_secrets.get("clientSecret") or "").strip()
        self.access_token = str(provider_secrets.get("accessToken") or "").strip()
        self.refresh_token = str(provider_secrets.get("refreshToken") or "").strip()
        if not self.client_id or not self.client_secret or not self.access_token or not self.refresh_token:
            raise RuntimeError("Credenciais OAuth do Mercado Livre estão incompletas.")
        self._lock = threading.Lock()

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.access_token}",
            "User-Agent": "Mozilla/5.0 Valley/1.0",
            "Accept": "application/json",
        }

    def _refresh_access_token(self) -> None:
        body = urllib.parse.urlencode(
            {
                "grant_type": "refresh_token",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "refresh_token": self.refresh_token,
            }
        ).encode("utf-8")
        request = Request(
            f"{self.base_url}/oauth/token",
            data=body,
            headers={
                "accept": "application/json",
                "content-type": "application/x-www-form-urlencoded",
            },
            method="POST",
        )
        with urlopen(request, timeout=45) as response:
            payload = json.loads(response.read().decode("utf-8"))
        access_token = str(payload.get("access_token") or "").strip()
        refresh_token = str(payload.get("refresh_token") or "").strip()
        if not access_token or not refresh_token:
            raise RuntimeError("Refresh token do Mercado Livre retornou payload incompleto.")
        self.access_token = access_token
        self.refresh_token = refresh_token
        secrets_payload = load_json(SECRETS_PATH, {})
        secrets_payload.setdefault(MERCADOLIVRE_KEY, {})
        secrets_payload[MERCADOLIVRE_KEY]["accessToken"] = access_token
        secrets_payload[MERCADOLIVRE_KEY]["refreshToken"] = refresh_token
        secrets_payload[MERCADOLIVRE_KEY]["updated_at_utc"] = utc_now_iso()
        write_json(SECRETS_PATH, secrets_payload)

    def get_json(self, path: str, params: dict[str, Any] | None = None, retry: bool = True) -> dict[str, Any] | list[Any]:
        query = urllib.parse.urlencode({key: value for key, value in (params or {}).items() if value is not None})
        url = f"{self.base_url}{path}"
        if query:
            url = f"{url}?{query}"
        request = Request(url, headers=self._headers())
        try:
            with urlopen(request, timeout=45) as response:
                return json.loads(response.read().decode("utf-8", errors="replace"))
        except HTTPError as error:
            if error.code == 401 and retry:
                with self._lock:
                    self._refresh_access_token()
                return self.get_json(path, params=params, retry=False)
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{error.code} {path}: {detail}") from error
        except URLError as error:
            raise RuntimeError(f"Erro de rede para {path}: {error}") from error


class CJDropshippingClient:
    def __init__(self, integrations: list[dict[str, Any]], secrets: dict[str, Any]) -> None:
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == CJDROPSHIPPING_KEY),
            None,
        )
        provider_secrets = secrets.get(CJDROPSHIPPING_KEY) if isinstance(secrets, dict) else None
        if not isinstance(provider, dict) or not isinstance(provider_secrets, dict):
            raise RuntimeError("Integração do CJ não está ativa com credenciais persistidas.")

        self.base_url = str(provider.get("baseUrl") or CJDROPSHIPPING_BASE_URL).rstrip("/")
        self.api_root = f"{self.base_url}/api2.0/v1"
        self.access_token = str(provider_secrets.get("accessToken") or "").strip()
        self.refresh_token = str(provider_secrets.get("refreshToken") or "").strip()
        self.open_id = str(provider_secrets.get("openId") or "").strip()
        if not self.access_token:
            raise RuntimeError("Access token do CJDropshipping está ausente.")
        self._lock = threading.Lock()
        self._last_request_at = 0.0

    def _throttle(self) -> None:
        with self._lock:
            wait = CJ_MIN_INTERVAL_SECONDS - (time.monotonic() - self._last_request_at)
            if wait > 0:
                time.sleep(wait)
            self._last_request_at = time.monotonic()

    def get_json(self, path: str, params: dict[str, Any] | None = None, retry_count: int = 0) -> dict[str, Any]:
        self._throttle()
        query = urllib.parse.urlencode({key: value for key, value in (params or {}).items() if value is not None})
        url = f"{self.api_root}{path}"
        if query:
            url = f"{url}?{query}"
        request = Request(
            url,
            headers={
                "CJ-Access-Token": self.access_token,
                "Accept": "application/json",
                "User-Agent": "Valley/1.0",
            },
        )
        try:
            with urlopen(request, timeout=60) as response:
                return json.loads(response.read().decode("utf-8", errors="replace"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            if error.code == 429 and retry_count < 4:
                time.sleep(max(CJ_MIN_INTERVAL_SECONDS * (retry_count + 2), 2.0))
                return self.get_json(path, params=params, retry_count=retry_count + 1)
            raise RuntimeError(f"{error.code} {path}: {detail}") from error
        except URLError as error:
            raise RuntimeError(f"Erro de rede para {path}: {error}") from error


def offer_snapshot(client: MercadoLivreClient, product_id: str) -> dict[str, Any] | None:
    try:
        payload = client.get_json(f"/products/{product_id}/items")
    except RuntimeError as error:
        if "404 /products/" in str(error) or "No winners found" in str(error):
            return None
        return None

    if not isinstance(payload, dict):
        return None
    results = payload.get("results")
    paging = payload.get("paging")
    if not isinstance(results, list) or not results:
        return None
    first = results[0] if isinstance(results[0], dict) else {}
    if not isinstance(first, dict):
        return None
    return {
        "offer_count": int((paging or {}).get("total") or len(results)),
        "first_offer": first,
    }


def build_ml_stock_item(
    product: dict[str, Any],
    source: SourcePlan,
    category: str,
    offer_data: dict[str, Any],
) -> dict[str, Any]:
    attributes = product.get("attributes") if isinstance(product.get("attributes"), list) else []
    pictures = product.get("pictures") if isinstance(product.get("pictures"), list) else []
    first_offer = offer_data["first_offer"]

    brand = first_attr_value(attributes, "BRAND") or first_attr_value(attributes, "MANUFACTURER") or source.collection_label
    model = first_attr_value(attributes, "MODEL") or first_attr_value(attributes, "LINE") or str(product.get("name") or "")
    price_brl = float(first_offer.get("price") or 0.0)
    compare_at_brl = float(first_offer.get("original_price") or price_brl or 0.0)
    free_shipping = bool(((first_offer.get("shipping") or {}) if isinstance(first_offer.get("shipping"), dict) else {}).get("free_shipping"))
    image_url = ""
    gallery_urls: list[str] = []
    for picture in pictures:
        if not isinstance(picture, dict):
            continue
        picture_url = str(picture.get("url") or picture.get("secure_url") or "").strip()
        if picture_url:
            gallery_urls.append(picture_url)
            if not image_url:
                image_url = picture_url
    if not image_url:
        image_url = "https://http2.mlstatic.com/D_NQ_NP_2X_821651-MLA78637300531_082024-F.webp"
    if not gallery_urls:
        gallery_urls = [image_url]

    offer_count = int(offer_data["offer_count"])
    seller_id = str(first_offer.get("seller_id") or "").strip()
    official_store_id = str(first_offer.get("official_store_id") or "").strip()
    raw_status = "Frete grátis" if free_shipping else "Entrega nacional"
    warranty = str(first_offer.get("warranty") or "").strip()

    return {
        "id": stable_uuid(f"{category}:{product.get('id')}"),
        "module_id": "STOCK",
        "title": str(product.get("name") or "").strip(),
        "brand": brand,
        "category": category,
        "price_brl": round(price_brl, 2),
        "compare_at_brl": round(compare_at_brl, 2),
        "stock": offer_count,
        "merchant_name": "Valley",
        "image_url": image_url,
        "video_url": "",
        "video_count": 0,
        "status": f"{offer_count} ofertas ativas • {raw_status}",
        "tags": build_tags(category, brand, model, free_shipping),
        "cta_label": "Abrir",
        "cta_path": "",
        "media_path": "",
        "description": build_description(category, brand, model, offer_count, first_offer),
        "gallery_urls": gallery_urls,
        "profile_id": "",
        "features": [
            f"Catálogo real {SITE_ID}",
            f"{offer_count} ofertas ativas",
            "Frete grátis" if free_shipping else "Entrega nacional",
            warranty or "Garantia conforme anúncio",
        ],
        "seller": {
            "name": "Valley Curadoria",
            "headline": "Oferta operacional validada para o catálogo Valley.",
            "avatar_url": image_url,
            "rating": 4.8,
            "city": "Brasil",
        },
        "checkout": {
            "headline": "Resumo operacional",
            "shipping_brl": 0.0 if free_shipping else float(((first_offer.get("shipping") or {}) if isinstance(first_offer.get("shipping"), dict) else {}).get("cost") or 0.0),
            "service_brl": 0.0,
            "installments": 12,
            "eta": "Consulte disponibilidade ao abrir a oferta",
        },
        "raw_badge": "STOCK",
        "collection_label": source.collection_label,
        "model_name": model,
        "google_product_category_id": source.google_category_id,
        "google_product_category_path": source.google_category_path,
        "google_product_category": source.google_category_path,
        "provider_key": MERCADOLIVRE_KEY,
        "provider_status": "active",
        "supplier_name": "Mercado Livre",
        "supplier_type": "Marketplace nacional",
        "supplier_model": "Catálogo público com buy box ativa",
        "supplier_visibility": "internal",
        "channel_label": "Canal MLB",
        "price_band": normalize_band(price_brl),
        "offer_count": offer_count,
        "availability_label": f"{offer_count} ofertas ativas",
        "shipping_free": free_shipping,
        "official_store_id": official_store_id,
        "source_product_id": str(product.get("id") or ""),
        "source_parent_id": str(product.get("parent_id") or ""),
        "source_domain_id": str(product.get("domain_id") or ""),
        "source_category_id": str(first_offer.get("category_id") or ""),
        "source_item_id": str(first_offer.get("item_id") or ""),
        "source_seller_id": seller_id,
        "source_status": str(product.get("status") or ""),
        "source_permalink": str(product.get("permalink") or ""),
        "source_collected_at_utc": utc_now_iso(),
        "tracking_capable": True,
        "tracking_mode": "orders_shipments_webhook",
        "tracking_webhook_enabled": True,
        "tracking_status": "active",
        "source_relevance_score": offer_count,
        "provider_priority": 80,
    }


def cj_item_category_text(item: dict[str, Any]) -> str:
    return normalize_text(
        " ".join(
            [
                str(item.get("oneCategoryName") or ""),
                str(item.get("twoCategoryName") or ""),
                str(item.get("threeCategoryName") or ""),
            ]
        )
    )


def cj_item_title_text(item: dict[str, Any]) -> str:
    return normalize_text(
        " ".join(
            [
                str(item.get("nameEn") or ""),
                clean_text(str(item.get("description") or "")),
            ]
        )
    )


def cj_matches_source(item: dict[str, Any], source: CjSourcePlan) -> bool:
    title_text = cj_item_title_text(item)
    category_text = cj_item_category_text(item)
    listed_num = safe_int(item.get("listedNum"))
    stock = safe_int(item.get("warehouseInventoryNum")) or safe_int(item.get("totalVerifiedInventory"))

    if source.min_listed_num and listed_num < source.min_listed_num:
        return False
    if stock <= 0:
        return False
    if source.allowed_category_terms and not any(term in category_text for term in source.allowed_category_terms):
        return False
    if source.required_title_terms and not any(term in title_text for term in source.required_title_terms):
        return False
    if any(term in title_text for term in source.blocked_title_terms):
        return False
    if any(term in category_text for term in source.blocked_category_terms):
        return False
    return True


def build_cj_description(category: str, source: CjSourcePlan, item: dict[str, Any]) -> str:
    inventory = safe_int(item.get("totalVerifiedInventory")) or safe_int(item.get("warehouseInventoryNum"))
    listed_num = safe_int(item.get("listedNum"))
    delivery_cycle = str(item.get("deliveryCycle") or "").strip()
    description = clean_text(str(item.get("description") or ""))
    fragments = [
        f"Curadoria Valley para {category.lower()} com estoque sincronizado via CJ.",
        f"Categoria fonte: {item.get('threeCategoryName') or item.get('twoCategoryName') or category}.",
        f"{inventory} unidades em estoque." if inventory else "",
        f"{listed_num} listagens sincronizadas." if listed_num else "",
        f"Prazo operacional informado: {delivery_cycle}." if delivery_cycle else "",
        description[:220] if description else "",
    ]
    return " ".join(fragment for fragment in fragments if fragment).strip()


def build_cj_video_url(video_list: Any) -> str:
    if not isinstance(video_list, list) or not video_list:
        return ""
    first = video_list[0]
    if isinstance(first, str):
        return first.strip()
    if isinstance(first, dict):
        return str(first.get("url") or first.get("videoUrl") or "").strip()
    return ""


def build_cj_stock_item(
    item: dict[str, Any],
    source: CjSourcePlan,
    category: str,
    usd_brl_rate: float,
    fx_reference: str,
    cj_open_id: str,
) -> dict[str, Any]:
    title = clean_text(str(item.get("nameEn") or "")).strip()
    listed_num = safe_int(item.get("listedNum"))
    verified_inventory = safe_int(item.get("totalVerifiedInventory"))
    raw_inventory = safe_int(item.get("warehouseInventoryNum"))
    stock = verified_inventory or raw_inventory
    min_usd, max_usd = parse_price_window(item.get("sellPrice"))
    discount_min_usd, _ = parse_price_window(item.get("discountPrice"))
    if discount_min_usd and min_usd and discount_min_usd < min_usd:
        active_usd = discount_min_usd
        compare_usd = min_usd
    else:
        active_usd = min_usd
        compare_usd = active_usd
    price_brl = round(active_usd * usd_brl_rate, 2)
    compare_at_brl = round(compare_usd * usd_brl_rate, 2)
    gallery_urls = parse_string_array(item.get("productImages") or item.get("productImage"))
    image_url = str(item.get("bigImage") or "").strip()
    if not image_url and gallery_urls:
        image_url = gallery_urls[0]
    if image_url and image_url not in gallery_urls:
        gallery_urls.insert(0, image_url)
    video_url = build_cj_video_url(item.get("videoList"))
    title_text = normalize_text(title)
    model_name = str(item.get("threeCategoryName") or item.get("twoCategoryName") or title).strip()
    tags = ["Catalogo real", category]
    if item.get("threeCategoryName"):
        tags.append(str(item["threeCategoryName"]))
    if video_url:
        tags.append("Video")
    if listed_num:
        tags.append("Alta demanda" if listed_num >= 500 else "Operacao ativa")
    features = [
        "Estoque global sincronizado",
        f"{stock} unidades disponíveis" if stock else "Disponibilidade sob consulta",
        f"{listed_num} listagens ativas" if listed_num else "Listagem ativa",
        "Tracking automatizado por webhook",
    ]
    return {
        "id": stable_uuid(f"{category}:cj:{item.get('id')}"),
        "module_id": "STOCK",
        "title": title,
        "brand": source.collection_label,
        "category": category,
        "price_brl": price_brl,
        "compare_at_brl": compare_at_brl,
        "stock": stock,
        "merchant_name": "Valley",
        "image_url": image_url,
        "video_url": video_url,
        "video_count": len(item.get("videoList") or []) if isinstance(item.get("videoList"), list) else 0,
        "status": f"{stock} em estoque • tracking ativo",
        "tags": tags,
        "cta_label": "Abrir",
        "cta_path": "",
        "media_path": "",
        "description": build_cj_description(category, source, item),
        "gallery_urls": gallery_urls,
        "profile_id": "",
        "features": features,
        "seller": {
            "name": "Valley Curadoria",
            "headline": "Oferta sincronizada com estoque e tracking automatizados.",
            "avatar_url": image_url,
            "rating": 4.7,
            "city": "Operação global",
        },
        "checkout": {
            "headline": "Resumo operacional",
            "shipping_brl": 0.0,
            "service_brl": 0.0,
            "installments": 12,
            "eta": "Prazo dinâmico na etapa de pedido",
        },
        "raw_badge": "STOCK",
        "collection_label": source.collection_label,
        "model_name": model_name,
        "google_product_category_id": source.google_category_id,
        "google_product_category_path": source.google_category_path,
        "google_product_category": source.google_category_path,
        "provider_key": CJDROPSHIPPING_KEY,
        "provider_status": "active",
        "supplier_name": "CJDropshipping",
        "supplier_type": "Catálogo global dropshipping",
        "supplier_model": "API Key + webhook logístico",
        "supplier_visibility": "internal",
        "channel_label": "CJ Global",
        "price_band": normalize_band(price_brl),
        "offer_count": listed_num,
        "availability_label": f"{stock} em estoque",
        "shipping_free": False,
        "official_store_id": "",
        "source_product_id": str(item.get("id") or ""),
        "source_parent_id": str(item.get("spu") or ""),
        "source_domain_id": str(item.get("categoryId") or ""),
        "source_category_id": str(item.get("categoryId") or ""),
        "source_item_id": str(item.get("sku") or ""),
        "source_seller_id": cj_open_id,
        "source_status": str(item.get("saleStatus") or item.get("autStatus") or ""),
        "source_permalink": "",
        "source_collected_at_utc": utc_now_iso(),
        "source_currency": "USD",
        "fx_rate_brl_per_usd": round(usd_brl_rate, 6),
        "fx_reference_date": fx_reference,
        "tracking_capable": True,
        "tracking_mode": "logistics_webhook",
        "tracking_webhook_enabled": True,
        "tracking_status": "active",
        "source_inventory_verified": verified_inventory,
        "source_inventory_unverified": safe_int(item.get("totalUnVerifiedInventory")),
        "source_verified_warehouses": safe_int(item.get("verifiedWarehouse")),
        "source_relevance_score": listed_num,
        "provider_priority": 70,
    }


def round_robin_preview(items: list[dict[str, Any]], limit: int) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in items:
        grouped[str(item.get("category") or "Outros")].append(item)
    ordered_categories = sorted(grouped)
    preview: list[dict[str, Any]] = []
    index = 0
    while len(preview) < limit and ordered_categories:
        category = ordered_categories[index % len(ordered_categories)]
        bucket = grouped[category]
        if bucket:
            preview.append(bucket.pop(0))
        if not bucket:
            ordered_categories.remove(category)
            if not ordered_categories:
                break
            index -= 1
        index += 1
    return preview[:limit]


def collect_ml_source_items(
    client: MercadoLivreClient,
    source: SourcePlan,
    category: str,
    global_seen: set[str],
) -> list[dict[str, Any]]:
    collected: list[dict[str, Any]] = []
    local_seen: set[str] = set()

    for query in source.queries:
        if len(collected) >= source.target_items:
            break

        offset = 0
        total = math.inf
        while len(collected) < source.target_items and offset < total and offset <= 950:
            search_payload = client.get_json(
                "/products/search",
                params={
                    "site_id": SITE_ID,
                    "status": "active",
                    "q": query,
                    "domain_id": source.domain_id,
                    "limit": SEARCH_PAGE_SIZE,
                    "offset": offset,
                },
            )
            if not isinstance(search_payload, dict):
                break
            results = search_payload.get("results")
            paging = search_payload.get("paging")
            if not isinstance(results, list) or not results:
                break
            total = int((paging or {}).get("total") or 0)

            candidate_products = []
            for product in results:
                if not isinstance(product, dict):
                    continue
                product_id = str(product.get("id") or "").strip()
                identity = stock_identity(MERCADOLIVRE_KEY, product_id)
                if not product_id or identity in global_seen or identity in local_seen:
                    continue
                candidate_products.append(product)

            with ThreadPoolExecutor(max_workers=THREAD_POOL_SIZE) as executor:
                future_map = {
                    executor.submit(offer_snapshot, client, str(product.get("id"))): product
                    for product in candidate_products
                }
                for future in as_completed(future_map):
                    if len(collected) >= source.target_items:
                        break
                    product = future_map[future]
                    product_id = str(product.get("id") or "")
                    identity = stock_identity(MERCADOLIVRE_KEY, product_id)
                    try:
                        offer_data = future.result()
                    except Exception:
                        offer_data = None
                    local_seen.add(identity)
                    if not offer_data:
                        continue
                    item = build_ml_stock_item(product, source, category, offer_data)
                    collected.append(item)
                    global_seen.add(identity)

            offset += SEARCH_PAGE_SIZE

    collected.sort(
        key=lambda item: (
            -int(item.get("source_relevance_score") or item.get("offer_count") or 0),
            float(item.get("price_brl") or 0.0),
            str(item.get("title") or ""),
        )
    )
    return collected[: source.target_items]


def collect_cj_source_items(
    client: CJDropshippingClient,
    source: CjSourcePlan,
    category: str,
    global_seen: set[str],
    usd_brl_rate: float,
    fx_reference: str,
) -> list[dict[str, Any]]:
    collected: list[dict[str, Any]] = []
    local_seen: set[str] = set()
    pages_per_query = max(
        3,
        math.ceil(source.target_items / max(CJ_PAGE_SIZE * max(len(source.queries), 1), 1)) * 3,
    )

    for query in source.queries:
        if len(collected) >= source.target_items:
            break
        page = 1
        total_records = math.inf
        empty_streak = 0
        while (
            len(collected) < source.target_items
            and (page - 1) * CJ_PAGE_SIZE < total_records
            and page <= pages_per_query
        ):
            payload = client.get_json(
                "/product/listV2",
                params={
                    "page": page,
                    "size": CJ_PAGE_SIZE,
                    "keyWord": query,
                    "features": "enable_category",
                },
            )
            data = payload.get("data") if isinstance(payload, dict) else None
            if not isinstance(data, dict):
                break
            total_records = int(data.get("totalRecords") or 0)
            content = data.get("content")
            if not isinstance(content, list) or not content:
                break

            page_items: list[dict[str, Any]] = []
            for entry in content:
                if not isinstance(entry, dict):
                    continue
                product_list = entry.get("productList")
                if not isinstance(product_list, list):
                    continue
                for item in product_list:
                    if not isinstance(item, dict):
                        continue
                    source_product_id = str(item.get("id") or "").strip()
                    identity = stock_identity(CJDROPSHIPPING_KEY, source_product_id)
                    if not source_product_id or identity in global_seen or identity in local_seen:
                        continue
                    if not cj_matches_source(item, source):
                        continue
                    page_items.append(item)

            for item in page_items:
                if len(collected) >= source.target_items:
                    break
                source_product_id = str(item.get("id") or "").strip()
                identity = stock_identity(CJDROPSHIPPING_KEY, source_product_id)
                local_seen.add(identity)
                catalog_item = build_cj_stock_item(
                    item,
                    source,
                    category,
                    usd_brl_rate,
                    fx_reference,
                    client.open_id,
                )
                collected.append(catalog_item)
                global_seen.add(identity)

            if page_items:
                empty_streak = 0
            else:
                empty_streak += 1
                if empty_streak >= 2:
                    break

            page += 1

    collected.sort(
        key=lambda item: (
            -int(item.get("source_relevance_score") or 0),
            -int(item.get("stock") or 0),
            float(item.get("price_brl") or 0.0),
            str(item.get("title") or ""),
        )
    )
    return collected[: source.target_items]


def dedupe_stock_items(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    best_by_signature: dict[tuple[str, str], dict[str, Any]] = {}
    for item in items:
        title_signature = normalize_text(str(item.get("title") or ""))
        category = str(item.get("category") or "")
        signature = (category, title_signature)
        current = best_by_signature.get(signature)
        if current is None:
            best_by_signature[signature] = item
            continue
        left_score = (
            int(current.get("provider_priority") or 0),
            int(current.get("source_relevance_score") or current.get("offer_count") or 0),
            int(current.get("stock") or 0),
        )
        right_score = (
            int(item.get("provider_priority") or 0),
            int(item.get("source_relevance_score") or item.get("offer_count") or 0),
            int(item.get("stock") or 0),
        )
        if right_score > left_score:
            best_by_signature[signature] = item
    deduped = list(best_by_signature.values())
    deduped.sort(
        key=lambda item: (
            str(item.get("category") or ""),
            -int(item.get("provider_priority") or 0),
            -int(item.get("source_relevance_score") or item.get("offer_count") or 0),
            -int(item.get("stock") or 0),
            float(item.get("price_brl") or 0.0),
            str(item.get("title") or ""),
        )
    )
    return deduped


def load_existing_provider_items(provider_key: str) -> list[dict[str, Any]]:
    runtime_payload = load_json(FULL_STOCK_PATH, {})
    items = runtime_payload.get("items") if isinstance(runtime_payload, dict) else None
    if not isinstance(items, list):
        return []
    return [
        item
        for item in items
        if isinstance(item, dict)
        and item.get("module_id") == "STOCK"
        and item.get("provider_key") == provider_key
    ]


def collect_global_seen(items: list[dict[str, Any]]) -> set[str]:
    seen: set[str] = set()
    for item in items:
        if not isinstance(item, dict):
            continue
        provider_key = str(item.get("provider_key") or "").strip()
        source_product_id = str(item.get("source_product_id") or "").strip()
        if provider_key and source_product_id:
            seen.add(stock_identity(provider_key, source_product_id))
    return seen


def collect_mercadolivre_catalog(
    integrations: list[dict[str, Any]],
    provider_secrets: dict[str, Any],
) -> list[dict[str, Any]]:
    client = MercadoLivreClient(integrations, provider_secrets)
    global_seen: set[str] = set()
    stock_items: list[dict[str, Any]] = []
    for category_plan in MERCADOLIVRE_CATEGORY_PLANS:
        for source in category_plan.sources:
            source_items = collect_ml_source_items(client, source, category_plan.category, global_seen)
            stock_items.extend(source_items)
            print(
                f"[stock-import] ML {category_plan.category} / {source.domain_id} -> "
                f"{len(source_items)}/{source.target_items}"
            )
    return stock_items


def collect_cj_catalog(
    integrations: list[dict[str, Any]],
    provider_secrets: dict[str, Any],
    existing_global_seen: set[str],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    client = CJDropshippingClient(integrations, provider_secrets)
    usd_brl_rate, fx_reference = fetch_usd_brl_rate()
    global_seen = set(existing_global_seen)
    stock_items: list[dict[str, Any]] = []
    for category_plan in CJ_CATEGORY_PLANS:
        for source in category_plan.sources:
            source_items = collect_cj_source_items(
                client,
                source,
                category_plan.category,
                global_seen,
                usd_brl_rate,
                fx_reference,
            )
            stock_items.extend(source_items)
            print(
                f"[stock-import] CJ {category_plan.category} / {source.queries[0]} -> "
                f"{len(source_items)}/{source.target_items}"
            )
    return stock_items, {"usd_brl_rate": usd_brl_rate, "reference": fx_reference}


def enabled_catalog_provider_keys(integrations: list[dict[str, Any]]) -> set[str]:
    keys: set[str] = set()
    for integration in integrations:
        if not isinstance(integration, dict):
            continue
        if not integration.get("enabled"):
            continue
        if not integration.get("importCatalog"):
            continue
        key = str(integration.get("key") or "").strip()
        if key:
            keys.add(key)
    return keys


def import_real_stock_catalog(refresh_mercado: bool = False) -> dict[str, Any]:
    catalog = load_json(CATALOG_PATH, {})
    if not isinstance(catalog, dict):
        raise RuntimeError("Catálogo base do produto não está legível.")
    existing_runtime = load_json(FULL_STOCK_PATH, {})
    existing_indexes = (
        existing_runtime.get("indexes")
        if isinstance(existing_runtime, dict) and isinstance(existing_runtime.get("indexes"), dict)
        else {}
    )

    integrations = load_json(INTEGRATIONS_PATH, [])
    provider_secrets = load_json(SECRETS_PATH, {})
    active_catalog_keys = enabled_catalog_provider_keys(integrations if isinstance(integrations, list) else [])

    merged_stock_items: list[dict[str, Any]] = []
    provider_counts: dict[str, int] = {}
    import_notes: list[str] = []
    provider_errors: dict[str, str] = {}

    mercado_items: list[dict[str, Any]] = []
    if MERCADOLIVRE_KEY in active_catalog_keys:
        existing_mercado_items = load_existing_provider_items(MERCADOLIVRE_KEY)
        if not refresh_mercado:
            mercado_items = existing_mercado_items
        if mercado_items:
            import_notes.append("Mercado Livre reutilizado do runtime atual.")
        else:
            try:
                mercado_items = collect_mercadolivre_catalog(
                    integrations if isinstance(integrations, list) else [],
                    provider_secrets if isinstance(provider_secrets, dict) else {},
                )
                import_notes.append("Mercado Livre recarregado via API.")
            except Exception as error:  # noqa: BLE001
                provider_errors[MERCADOLIVRE_KEY] = str(error)
                if existing_mercado_items:
                    mercado_items = existing_mercado_items
                    import_notes.append(
                        "Mercado Livre reaproveitado do runtime anterior após falha na API."
                    )
                else:
                    import_notes.append(
                        "Mercado Livre sem dados reutilizáveis após falha na API."
                    )
        provider_counts[MERCADOLIVRE_KEY] = len(mercado_items)
        merged_stock_items.extend(mercado_items)

    cj_items: list[dict[str, Any]] = []
    cj_fx_meta: dict[str, Any] = {}
    if CJDROPSHIPPING_KEY in active_catalog_keys:
        existing_cj_items = load_existing_provider_items(CJDROPSHIPPING_KEY)
        existing_fx_meta = (
            existing_runtime.get("ptax_usd_brl")
            if isinstance(existing_runtime, dict) and isinstance(existing_runtime.get("ptax_usd_brl"), dict)
            else {}
        )
        try:
            cj_items, cj_fx_meta = collect_cj_catalog(
                integrations if isinstance(integrations, list) else [],
                provider_secrets if isinstance(provider_secrets, dict) else {},
                collect_global_seen(merged_stock_items),
            )
            import_notes.append("CJ sincronizado com estoque, preço em BRL via PTAX e tracking por webhook.")
        except Exception as error:  # noqa: BLE001
            provider_errors[CJDROPSHIPPING_KEY] = str(error)
            cj_items = existing_cj_items
            cj_fx_meta = existing_fx_meta
            if cj_items:
                import_notes.append(
                    "CJ reaproveitado do runtime anterior após falha/limite da API."
                )
            else:
                import_notes.append(
                    "CJ sem dados reutilizáveis após falha/limite da API."
                )
        provider_counts[CJDROPSHIPPING_KEY] = len(cj_items)
        merged_stock_items.extend(cj_items)

    unsupported_active_keys = sorted(
        provider_key
        for provider_key in active_catalog_keys
        if provider_key not in {MERCADOLIVRE_KEY, CJDROPSHIPPING_KEY}
    )
    for provider_key in unsupported_active_keys:
        import_notes.append(
            f"{provider_key} autenticado/configurado, mas ainda sem coletor oficial no importador do STOCK."
        )
        provider_counts.setdefault(provider_key, 0)

    merged_stock_items = dedupe_stock_items(merged_stock_items)

    preview_items = round_robin_preview(
        [sanitize_public_stock_item(item) for item in merged_stock_items],
        PREVIEW_LIMIT,
    )
    existing_items = catalog.get("items") if isinstance(catalog.get("items"), list) else []
    non_stock_items = [
        item for item in existing_items if isinstance(item, dict) and str(item.get("module_id")) != "STOCK"
    ]
    catalog["items"] = preview_items + non_stock_items

    summary = catalog.get("summary") if isinstance(catalog.get("summary"), dict) else {}
    summary["products"] = len(merged_stock_items) + len(non_stock_items)
    catalog["summary"] = summary
    hero = catalog.get("hero") if isinstance(catalog.get("hero"), dict) else {}
    hero["title"] = "Valley Stock | Catalogo proprietario"
    hero["subtitle"] = (
        "Curadoria Valley com catálogo real multi-provedor, agrupado por categoria e taxonomia Google, "
        "com sincronização de estoque, preço e tracking sem exposição pública do fornecedor."
    )
    catalog["hero"] = hero
    catalog["generated_at_utc"] = utc_now_iso()

    providers_active = sorted(provider_counts)
    runtime_payload = {
        "status": "ok",
        "service": "valley-stock-real-catalog",
        "generated_at_utc": utc_now_iso(),
        "provider": "multi_provider_catalog" if len(providers_active) > 1 else (providers_active[0] if providers_active else "runtime"),
        "providers_active": providers_active,
        "provider_counts": provider_counts,
        "ptax_usd_brl": cj_fx_meta,
        "tracking_sync": {
            "mercado_livre_webhook": MERCADOLIVRE_KEY in providers_active,
            "cjdropshipping_webhook": CJDROPSHIPPING_KEY in providers_active,
        },
        "indexes": existing_indexes,
        "notes": import_notes,
        "provider_errors": provider_errors,
        "items_total": len(merged_stock_items),
        "categories_total": len({str(item.get("category") or "") for item in merged_stock_items}),
        "items": merged_stock_items,
    }

    write_json(CATALOG_PATH, catalog)
    write_json(FULL_STOCK_PATH, runtime_payload)
    return {
        "catalog_path": str(CATALOG_PATH.relative_to(ROOT)),
        "runtime_path": str(FULL_STOCK_PATH.relative_to(ROOT)),
        "preview_items": len(preview_items),
        "stock_items_total": len(merged_stock_items),
        "provider_counts": provider_counts,
        "providers_active": providers_active,
        "ptax_usd_brl": cj_fx_meta,
        "provider_errors": provider_errors,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Atualiza o runtime real do STOCK.")
    parser.add_argument(
        "--refresh-mercado",
        action="store_true",
        help="Reconsulta o Mercado Livre em vez de reutilizar o runtime já coletado.",
    )
    args = parser.parse_args()
    payload = import_real_stock_catalog(refresh_mercado=args.refresh_mercado)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
