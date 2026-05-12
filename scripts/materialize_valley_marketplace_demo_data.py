#!/usr/bin/env python3
"""Materializa dados comerciais ficticios para o modulo Marketplace."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
REAL_STOCK_RUNTIME_PATH = ROOT / "tmp" / "runtime" / "valley-stock-real-catalog.json"
BUNDLED_STOCK_RUNTIME_PATH = (
    ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_stock_runtime_ptbr.json"
)
RUNTIME_PATH = ROOT / "tmp" / "runtime" / "valley-marketplace-demo-fixtures.json"
ASSET_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_marketplace_demo_fixtures.json"
FIXTURE_SOURCE = "valley_release_marketplace_v037"


def utc_now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def stable_id(value: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"valley-marketplace::{value}"))


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def item_count(payload: object) -> int:
    if not isinstance(payload, dict):
        return 0
    items = payload.get("items")
    return len(items) if isinstance(items, list) else 0


def read_optional_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return read_json(path)
    except Exception:
        return {}


def sync_bundled_stock_runtime() -> int:
    real_stock = read_optional_json(REAL_STOCK_RUNTIME_PATH)
    bundled_stock = read_optional_json(BUNDLED_STOCK_RUNTIME_PATH)
    real_count = item_count(real_stock)
    bundled_count = item_count(bundled_stock)
    if real_count > bundled_count:
        public_runtime = real_stock.get("public_runtime")
        if isinstance(public_runtime, dict):
            public_runtime["public_url"] = "https://brasildesconto.com.br"
            public_runtime["public_api_url"] = "https://brasildesconto.com.br/api/product-shell"
            public_runtime.pop("local_api_url", None)
        write_json(BUNDLED_STOCK_RUNTIME_PATH, real_stock)
        return real_count
    return bundled_count


def sanitize_public_runtime(catalog: dict) -> None:
    public_runtime = catalog.get("public_runtime")
    if not isinstance(public_runtime, dict):
        return
    public_runtime["public_url"] = "https://brasildesconto.com.br"
    public_runtime["public_api_url"] = "https://brasildesconto.com.br/api/product-shell"
    public_runtime.pop("local_api_url", None)


MERCHANTS = [
    {
        "id": "loja-moda-centro",
        "name": "Moda Centro Brasil",
        "segment": "Vestuário e acessórios",
        "city": "São Paulo",
        "rating": 4.8,
        "sla": "Despacho em 24h",
    },
    {
        "id": "casa-pratica",
        "name": "Casa Prática Express",
        "segment": "Casa, utilidades e decoração",
        "city": "Campinas",
        "rating": 4.7,
        "sla": "Entrega regional em 48h",
    },
    {
        "id": "tech-vitrine",
        "name": "Tech Vitrine Pro",
        "segment": "Eletrônicos e acessórios",
        "city": "Santos",
        "rating": 4.9,
        "sla": "Retirada e entrega no mesmo dia",
    },
    {
        "id": "servicos-urbanos",
        "name": "Serviços Urbanos Valley",
        "segment": "Serviços locais",
        "city": "Belo Horizonte",
        "rating": 4.6,
        "sla": "Agenda sob demanda",
    },
]

SERVICES = [
    {
        "id": "instalacao-smart-home",
        "merchant_id": "servicos-urbanos",
        "title": "Instalação smart home residencial",
        "category": "Serviços",
        "price_brl": 189.90,
        "description": "Instalação de câmera, sensor, tomada inteligente e configuração inicial no aplicativo do cliente.",
    },
    {
        "id": "montagem-moveis",
        "merchant_id": "casa-pratica",
        "title": "Montagem de móveis compactos",
        "category": "Serviços",
        "price_brl": 149.90,
        "description": "Serviço local para montagem de rack, mesa, cadeira, cômoda e organização pós-entrega.",
    },
    {
        "id": "retirada-troca-expressa",
        "merchant_id": "tech-vitrine",
        "title": "Retirada para troca expressa",
        "category": "Logística reversa",
        "price_brl": 39.90,
        "description": "Coleta agendada para troca, devolução ou garantia com rastreio pelo marketplace.",
    },
]

PRODUCTS = [
    {
        "id": "vestido-midi-valley",
        "merchant_id": "loja-moda-centro",
        "title": "Vestido midi canelado Valley",
        "brand": "Moda Centro",
        "category": "Moda",
        "price_brl": 119.90,
        "compare_at_brl": 159.90,
        "stock": 42,
        "image_url": "https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?auto=format&fit=crop&w=1200&q=80",
        "features": ["Grade P ao GG", "Troca facilitada", "Envio em 24h"],
    },
    {
        "id": "kit-organizador-cozinha",
        "merchant_id": "casa-pratica",
        "title": "Kit organizador de cozinha com 8 peças",
        "brand": "Casa Prática",
        "category": "Casa",
        "price_brl": 84.90,
        "compare_at_brl": 109.90,
        "stock": 88,
        "image_url": "https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=1200&q=80",
        "features": ["BPA free", "Empilhável", "Controle de estoque por volume"],
    },
    {
        "id": "fone-bluetooth-pro",
        "merchant_id": "tech-vitrine",
        "title": "Fone bluetooth Pro ANC",
        "brand": "Tech Vitrine",
        "category": "Eletrônicos",
        "price_brl": 229.90,
        "compare_at_brl": 279.90,
        "stock": 31,
        "image_url": "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=1200&q=80",
        "features": ["Cancelamento ativo", "Garantia de 12 meses", "Pronto para retirada"],
    },
    {
        "id": "camera-wifi-interna",
        "merchant_id": "tech-vitrine",
        "title": "Câmera Wi-Fi interna 2K",
        "brand": "Tech Vitrine",
        "category": "Segurança",
        "price_brl": 179.90,
        "compare_at_brl": 219.90,
        "stock": 56,
        "image_url": "https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=1200&q=80",
        "features": ["Visão noturna", "Áudio bidirecional", "Instalação opcional"],
    },
]


def merchant_by_id(merchant_id: str) -> dict:
    return next(merchant for merchant in MERCHANTS if merchant["id"] == merchant_id)


def product_to_catalog_item(product: dict) -> dict:
    merchant = merchant_by_id(str(product["merchant_id"]))
    return {
        "id": stable_id(str(product["id"])),
        "module_id": "MARKETPLACE",
        "fixture_source": FIXTURE_SOURCE,
        "title": product["title"],
        "brand": product["brand"],
        "category": product["category"],
        "price_brl": product["price_brl"],
        "compare_at_brl": product["compare_at_brl"],
        "stock": product["stock"],
        "merchant_name": merchant["name"],
        "image_url": product["image_url"],
        "video_url": "",
        "video_count": 0,
        "status": "Publicado no marketplace",
        "tags": ["Marketplace", merchant["segment"], merchant["city"]],
        "cta_label": "Comprar",
        "cta_path": "/checkout",
        "media_path": "",
        "description": f"{product['title']} vendido por {merchant['name']} com operação Valley.",
        "gallery_urls": [product["image_url"]],
        "profile_id": merchant["id"],
        "features": product["features"],
        "seller": {
            "name": merchant["name"],
            "headline": f"{merchant['segment']} - {merchant['sla']}",
            "avatar_url": product["image_url"],
            "rating": merchant["rating"],
            "city": merchant["city"],
        },
        "checkout": {
            "headline": "Compra protegida Valley",
            "shipping_brl": 19.90,
            "service_brl": 0.0,
            "installments": 10,
            "eta": merchant["sla"],
        },
        "raw_badge": "MARKETPLACE",
        "collection_label": "Brasil Desconto",
        "model_name": product["title"],
        "google_product_category_id": "",
        "google_product_category_path": product["category"],
        "google_product_category": product["category"],
        "availability_label": f"{product['stock']} unidades disponíveis",
        "price_band": "Marketplace",
    }


def main() -> None:
    real_stock_total = sync_bundled_stock_runtime()
    catalog = read_json(CATALOG_PATH)
    sanitize_public_runtime(catalog)
    current_items = catalog.get("items") if isinstance(catalog.get("items"), list) else []
    current_items = [
        item
        for item in current_items
        if not (isinstance(item, dict) and item.get("fixture_source") == FIXTURE_SOURCE)
    ]
    marketplace_items = [product_to_catalog_item(product) for product in PRODUCTS]
    catalog["items"] = current_items + marketplace_items
    summary = catalog.get("summary") if isinstance(catalog.get("summary"), dict) else {}
    summary["products"] = len(catalog["items"])
    summary["visible_products"] = len(catalog["items"])
    summary["real_supplier_products"] = max(
        real_stock_total,
        int(summary.get("real_supplier_products") or 0),
        len([item for item in current_items if isinstance(item, dict) and item.get("module_id") == "STOCK"]),
    )
    summary["marketplace_merchants"] = len(MERCHANTS)
    summary["marketplace_services"] = len(SERVICES)
    catalog["summary"] = summary
    catalog["generated_at_utc"] = utc_now_iso()

    payload = {
        "status": "ok",
        "service": "valley-marketplace-demo-fixtures",
        "generated_at_utc": utc_now_iso(),
        "fixture_source": FIXTURE_SOURCE,
        "merchants": MERCHANTS,
        "services": SERVICES,
        "products": PRODUCTS,
        "catalog_items_total": len(marketplace_items),
        "real_supplier_products": summary["real_supplier_products"],
    }
    write_json(CATALOG_PATH, catalog)
    write_json(RUNTIME_PATH, payload)
    write_json(ASSET_PATH, payload)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
