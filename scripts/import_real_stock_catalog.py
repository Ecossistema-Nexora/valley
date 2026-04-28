#!/usr/bin/env python3
"""Substitui o STOCK demo por um catalogo real do Mercado Livre.

Mantem o shell embarcado leve com uma vitrine reduzida, mas grava o catalogo
completo em runtime para consumo via API publica.
"""

from __future__ import annotations

import json
import math
import threading
import urllib.parse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import UTC, datetime
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
PREVIEW_LIMIT = 80


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


def short_currency(value: float) -> str:
    return f"R$ {value:,.2f}".replace(",", "_").replace(".", ",").replace("_", ".")


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


CATEGORY_PLANS: tuple[CategoryPlan, ...] = (
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


def build_stock_item(
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
        "gallery_urls": gallery_urls[:6],
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


def collect_source_items(
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

            candidate_products = [
                product
                for product in results
                if isinstance(product, dict)
                and str(product.get("id") or "").strip()
                and str(product.get("id")) not in global_seen
                and str(product.get("id")) not in local_seen
            ]

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
                    try:
                        offer_data = future.result()
                    except Exception:
                        offer_data = None
                    local_seen.add(product_id)
                    if not offer_data:
                        continue
                    item = build_stock_item(product, source, category, offer_data)
                    collected.append(item)
                    global_seen.add(product_id)

            offset += SEARCH_PAGE_SIZE

    collected.sort(
        key=lambda item: (
            -int(item.get("offer_count") or 0),
            float(item.get("price_brl") or 0.0),
            str(item.get("title") or ""),
        )
    )
    return collected[: source.target_items]


def import_real_stock_catalog() -> dict[str, Any]:
    catalog = load_json(CATALOG_PATH, {})
    if not isinstance(catalog, dict):
        raise RuntimeError("Catálogo base do produto não está legível.")

    integrations = load_json(INTEGRATIONS_PATH, [])
    provider_secrets = load_json(SECRETS_PATH, {})
    client = MercadoLivreClient(integrations, provider_secrets)

    global_seen: set[str] = set()
    stock_items: list[dict[str, Any]] = []

    for category_plan in CATEGORY_PLANS:
        for source in category_plan.sources:
            source_items = collect_source_items(client, source, category_plan.category, global_seen)
            stock_items.extend(source_items)
            print(
                f"[stock-import] {category_plan.category} / {source.domain_id} -> "
                f"{len(source_items)}/{source.target_items}"
            )

    stock_items.sort(
        key=lambda item: (
            str(item.get("category") or ""),
            -int(item.get("offer_count") or 0),
            float(item.get("price_brl") or 0.0),
            str(item.get("title") or ""),
        )
    )

    preview_items = round_robin_preview(stock_items, PREVIEW_LIMIT)
    existing_items = catalog.get("items") if isinstance(catalog.get("items"), list) else []
    non_stock_items = [
        item for item in existing_items if isinstance(item, dict) and str(item.get("module_id")) != "STOCK"
    ]
    catalog["items"] = preview_items + non_stock_items

    summary = catalog.get("summary") if isinstance(catalog.get("summary"), dict) else {}
    summary["products"] = len(stock_items) + len(non_stock_items)
    catalog["summary"] = summary
    hero = catalog.get("hero") if isinstance(catalog.get("hero"), dict) else {}
    hero["title"] = "Valley Stock | Catalogo proprietario"
    hero["subtitle"] = (
        "Curadoria Valley com produtos reais do catálogo ativo, agrupados por categoria e taxonomia Google, "
        "sem exposição pública do fornecedor de origem."
    )
    catalog["hero"] = hero
    catalog["generated_at_utc"] = utc_now_iso()

    runtime_payload = {
        "status": "ok",
        "service": "valley-stock-real-catalog",
        "generated_at_utc": utc_now_iso(),
        "provider": "mercado_livre_catalog",
        "site_id": SITE_ID,
        "items_total": len(stock_items),
        "categories_total": len({str(item.get("category") or "") for item in stock_items}),
        "items": stock_items,
    }

    write_json(CATALOG_PATH, catalog)
    write_json(FULL_STOCK_PATH, runtime_payload)
    return {
        "catalog_path": str(CATALOG_PATH.relative_to(ROOT)),
        "runtime_path": str(FULL_STOCK_PATH.relative_to(ROOT)),
        "preview_items": len(preview_items),
        "stock_items_total": len(stock_items),
    }


def main() -> None:
    payload = import_real_stock_catalog()
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
