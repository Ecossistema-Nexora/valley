#!/usr/bin/env python3
# PROPOSITO: Automatizar generate valley product demo catalog no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/generate_valley_product_demo_catalog.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Gera catalogo demo de produto, seed SQL e seed MongoDB para modo usuario."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5


ROOT = Path(__file__).resolve().parents[1]
MODULES_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "modules_v47.json"
CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
POSTGRES_SEED_PATH = ROOT / "database" / "seeds" / "postgres" / "003_v47_product_mode_demo_seed.sql"
MONGO_SEED_PATH = ROOT / "database" / "seeds" / "mongodb" / "002_v47_product_mode_demo_seed.mongo.js"
ADMIN_INTEGRATIONS_PATH = ROOT / "tmp" / "runtime" / "valley-admin-integrations.json"

BASE_TIME = datetime(2026, 4, 23, 12, 0, tzinfo=UTC)

IMAGE_POOL = [
    "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1585386959984-a4155224a1ad?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1511499767150-a48a237f0083?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1550009158-9ebf69173e03?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1546868871-7041f2a55e12?auto=format&fit=crop&w=1200&q=80",
]

AVATAR_POOL = [
    "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=600&q=80",
]

VIDEO_POOL = [
    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
    "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
]

BRANDS = [
    "Valley Motion",
    "Aurora One",
    "Valley Prime",
    "Flux Home",
    "Linea Air",
    "Pulse Grid",
    "North Orbit",
    "Urban Core",
]

CATEGORIES = [
    "Smartphones",
    "Audio",
    "Wearables",
    "Casa",
    "Mobilidade",
    "Premium Tech",
    "Creator Gear",
    "Smart Living",
]

CITIES = ["Sao Paulo", "Campinas", "Santos", "Ribeirao Preto", "Sorocaba"]
PRESENCE = ["online", "em entrega", "em reuniao", "respondendo", "ativo agora"]

STOCK_PROVIDER_BLUEPRINTS = {
    "mercado_livre": {
        "provider_key": "mercado_livre",
        "provider_status": "active",
        "supplier_name": "Mercado Livre Oficial",
        "supplier_type": "Marketplace API nacional",
        "supplier_model": "Cross docking nacional",
        "channel_label": "Canal BR-01",
    },
    "aliexpress": {
        "provider_key": "aliexpress",
        "provider_status": "active",
        "supplier_name": "AliExpress Global Sourcing",
        "supplier_type": "Cross-border sourcing",
        "supplier_model": "Importacao programada",
        "channel_label": "Canal Global-02",
    },
    "amazon": {
        "provider_key": "amazon",
        "provider_status": "standby",
        "supplier_name": "Amazon Seller API",
        "supplier_type": "Marketplace internacional",
        "supplier_model": "Fulfillment parceiro",
        "channel_label": "Canal Global-03",
    },
    "alibaba": {
        "provider_key": "alibaba",
        "provider_status": "standby",
        "supplier_name": "Alibaba B2B",
        "supplier_type": "Fornecedor B2B",
        "supplier_model": "MOQ e importacao por lote",
        "channel_label": "Canal B2B-04",
    },
    "magalu": {
        "provider_key": "magalu",
        "provider_status": "standby",
        "supplier_name": "Magalu Parceiros",
        "supplier_type": "Marketplace nacional",
        "supplier_model": "Cross docking nacional",
        "channel_label": "Canal BR-05",
    },
    "shopee": {
        "provider_key": "shopee",
        "provider_status": "standby",
        "supplier_name": "Shopee Open Platform",
        "supplier_type": "Marketplace nacional",
        "supplier_model": "Sortimento dinamico",
        "channel_label": "Canal BR-06",
    },
    "cjdropshipping": {
        "provider_key": "cjdropshipping",
        "provider_status": "standby",
        "supplier_name": "CJDropshipping",
        "supplier_type": "Fulfillment dropshipping",
        "supplier_model": "Pedido automatizado",
        "channel_label": "Canal Fulfillment-07",
    },
}

STOCK_TAXONOMY_BLUEPRINTS = [
    {
        "category": "Smartphones",
        "collection_label": "Valley Edge",
        "model_root": "Edge Phone",
        "taxonomy_id": "267",
        "taxonomy_path": "Electronics > Communications > Telephony > Mobile Phones",
        "base_price": 1699.90,
    },
    {
        "category": "Audio",
        "collection_label": "Valley Pulse",
        "model_root": "Pulse Buds",
        "taxonomy_id": "543626",
        "taxonomy_path": "Electronics > Audio > Audio Components > Headphones & Headsets > Headphones",
        "base_price": 249.90,
    },
    {
        "category": "Audio",
        "collection_label": "Valley Sound",
        "model_root": "Sound Dock",
        "taxonomy_id": "249",
        "taxonomy_path": "Electronics > Audio > Audio Components > Speakers",
        "base_price": 329.90,
    },
    {
        "category": "Wearables",
        "collection_label": "Valley Motion",
        "model_root": "Motion Watch",
        "taxonomy_id": "201",
        "taxonomy_path": "Apparel & Accessories > Jewelry > Watches",
        "base_price": 489.90,
    },
    {
        "category": "Casa",
        "collection_label": "Valley Casa",
        "model_root": "Casa Vac",
        "taxonomy_id": "619",
        "taxonomy_path": "Home & Garden > Household Appliances > Vacuums",
        "base_price": 389.90,
    },
    {
        "category": "Creator Gear",
        "collection_label": "Valley Studio",
        "model_root": "Studio Ring",
        "taxonomy_id": "42",
        "taxonomy_path": "Cameras & Optics > Photography > Lighting & Studio",
        "base_price": 159.90,
    },
    {
        "category": "Premium Tech",
        "collection_label": "Valley Stream",
        "model_root": "Stream Hub",
        "taxonomy_id": "5276",
        "taxonomy_path": "Electronics > Video > Video Players & Recorders > Streaming & Home Media Players",
        "base_price": 459.90,
    },
    {
        "category": "Mobilidade",
        "collection_label": "Valley Ride",
        "model_root": "Ride Scooter",
        "taxonomy_id": "5879",
        "taxonomy_path": "Sporting Goods > Outdoor Recreation > Riding Scooters",
        "base_price": 899.90,
    },
    {
        "category": "Smart Living",
        "collection_label": "Valley Sense",
        "model_root": "Sense Kit",
        "taxonomy_id": "2413",
        "taxonomy_path": "Hardware > Power & Electrical Supplies > Home Automation Kits",
        "base_price": 279.90,
    },
    {
        "category": "Premium Tech",
        "collection_label": "Valley Charge",
        "model_root": "Charge Max",
        "taxonomy_id": "505295",
        "taxonomy_path": "Electronics > Electronics Accessories > Power > Power Adapters & Chargers",
        "base_price": 189.90,
    },
    {
        "category": "Smartphones",
        "collection_label": "Valley Guard",
        "model_root": "Guard Case",
        "taxonomy_id": "2353",
        "taxonomy_path": "Electronics > Communications > Telephony > Mobile Phone Accessories > Mobile Phone Cases",
        "base_price": 89.90,
    },
    {
        "category": "Creator Gear",
        "collection_label": "Valley Voice",
        "model_root": "Voice Mic",
        "taxonomy_id": "234",
        "taxonomy_path": "Electronics > Audio > Audio Components > Microphones",
        "base_price": 219.90,
    },
]

DATA_HOME_LABELS = {
    "postgres": "Postgres relacional",
    "postgres_mongo": "Postgres + Mongo",
    "mongo": "Mongo documental",
}

DATA_HOME_NOTES = {
    "postgres": "A trilha critica fica em consistencia relacional para saldo, contrato e prova operacional.",
    "postgres_mongo": "Pedidos, dinheiro e contexto operacional seguem juntos na camada hibrida com continuidade entre eventos e consistencia.",
    "mongo": "Memoria, eventos e leitura viva ficam na camada documental para preservar contexto e volume sem travar a experiencia.",
}

TIER_LABELS = {
    "foundation": "Foundation",
    "core": "Core",
    "expansion": "Expansion",
    "frontier": "Frontier",
}

FAMILY_PROFILES = {
    "ops_logistics": {
        "accent": "Operacao em compasso real",
        "stat_cards": [
            {"label": "Ordens ativas", "base": 118, "step": 3, "trend": "SLA 97%", "format": "int"},
            {"label": "Fluxos em campo", "base": 26, "step": 1, "trend": "+9%", "format": "int"},
            {"label": "Receita em curso", "base": 8400, "step": 145, "trend": "+11%", "format": "brl"},
        ],
        "quick_actions": [
            {"label": "Painel operacional", "target": "detail"},
            {"label": "Fluxo ao vivo", "target": "feed"},
            {"label": "Coordenacao", "target": "chat"},
            {"label": "Extrato", "target": "statement"},
        ],
    },
    "commerce_store": {
        "accent": "Comercio em rotacao",
        "stat_cards": [
            {"label": "Vitrines ativas", "base": 84, "step": 2, "trend": "+8%", "format": "int"},
            {"label": "Conversoes", "base": 46, "step": 1, "trend": "+6%", "format": "int"},
            {"label": "GMV protegido", "base": 12600, "step": 210, "trend": "+14%", "format": "brl"},
        ],
        "quick_actions": [
            {"label": "Painel comercial", "target": "detail"},
            {"label": "Vitrine viva", "target": "feed"},
            {"label": "Negociacao", "target": "chat"},
            {"label": "Extrato", "target": "statement"},
        ],
    },
    "finance_core": {
        "accent": "Ledger em pulso",
        "stat_cards": [
            {"label": "Saldo orquestrado", "base": 148000, "step": 3200, "trend": "+12%", "format": "brl"},
            {"label": "Liquidacoes", "base": 128, "step": 2, "trend": "D+0 92%", "format": "int"},
            {"label": "Limites ativos", "base": 84, "step": 1, "trend": "+5%", "format": "int"},
        ],
        "quick_actions": [
            {"label": "Painel financeiro", "target": "detail"},
            {"label": "Movimento vivo", "target": "feed"},
            {"label": "Suporte", "target": "chat"},
            {"label": "Extrato", "target": "statement"},
        ],
    },
    "asset_ops": {
        "accent": "Ativo com lastro",
        "stat_cards": [
            {"label": "Carteiras em foco", "base": 62, "step": 1, "trend": "+7%", "format": "int"},
            {"label": "Contratos vivos", "base": 34, "step": 1, "trend": "+4%", "format": "int"},
            {"label": "Volume protegido", "base": 21400, "step": 280, "trend": "+10%", "format": "brl"},
        ],
        "quick_actions": [
            {"label": "Painel patrimonial", "target": "detail"},
            {"label": "Mercado ativo", "target": "feed"},
            {"label": "Negociacao", "target": "chat"},
            {"label": "Extrato", "target": "statement"},
        ],
    },
    "care_services": {
        "accent": "Cuidado com contexto",
        "stat_cards": [
            {"label": "Jornadas ativas", "base": 92, "step": 2, "trend": "+8%", "format": "int"},
            {"label": "Retencao", "base": 87, "step": 1, "trend": "+3 pts", "format": "percent"},
            {"label": "SLA humano", "base": 14, "step": 0, "trend": "min", "format": "minutes"},
        ],
        "quick_actions": [
            {"label": "Painel de cuidado", "target": "detail"},
            {"label": "Contexto ativo", "target": "feed"},
            {"label": "Atendimento", "target": "chat"},
            {"label": "Historico", "target": "statement"},
        ],
    },
    "people_journey": {
        "accent": "Jornada que evolui",
        "stat_cards": [
            {"label": "Trilhas ativas", "base": 108, "step": 2, "trend": "+9%", "format": "int"},
            {"label": "Conclusoes", "base": 38, "step": 1, "trend": "+6%", "format": "int"},
            {"label": "Retencao", "base": 79, "step": 1, "trend": "+4 pts", "format": "percent"},
        ],
        "quick_actions": [
            {"label": "Painel de jornada", "target": "detail"},
            {"label": "Rede ativa", "target": "feed"},
            {"label": "Conversa", "target": "chat"},
            {"label": "Historico", "target": "statement"},
        ],
    },
    "growth_media": {
        "accent": "Audiencia em movimento",
        "stat_cards": [
            {"label": "Alcance", "base": 18200, "step": 320, "trend": "+16%", "format": "int"},
            {"label": "Engajamento", "base": 1240, "step": 18, "trend": "+9%", "format": "int"},
            {"label": "Receita criativa", "base": 9800, "step": 165, "trend": "+13%", "format": "brl"},
        ],
        "quick_actions": [
            {"label": "Painel creator", "target": "detail"},
            {"label": "Feed ao vivo", "target": "feed"},
            {"label": "Campanhas", "target": "chat"},
            {"label": "Payout", "target": "statement"},
        ],
    },
    "civic_city": {
        "accent": "Cidade em resposta",
        "stat_cards": [
            {"label": "Chamados ativos", "base": 72, "step": 1, "trend": "+5%", "format": "int"},
            {"label": "Cobertura", "base": 91, "step": 0, "trend": "bairros", "format": "percent"},
            {"label": "Tempo de resposta", "base": 9, "step": 0, "trend": "min", "format": "minutes"},
        ],
        "quick_actions": [
            {"label": "Painel urbano", "target": "detail"},
            {"label": "Mapa vivo", "target": "feed"},
            {"label": "Atendimento", "target": "chat"},
            {"label": "Historico", "target": "statement"},
        ],
    },
    "legal_safe": {
        "accent": "Camada juridica",
        "stat_cards": [
            {"label": "Casos ativos", "base": 44, "step": 1, "trend": "+4%", "format": "int"},
            {"label": "Prazos vivos", "base": 21, "step": 1, "trend": "sem atraso", "format": "int"},
            {"label": "Registros", "base": 860, "step": 14, "trend": "+7%", "format": "int"},
        ],
        "quick_actions": [
            {"label": "Painel juridico", "target": "detail"},
            {"label": "Fluxo seguro", "target": "feed"},
            {"label": "Consulta", "target": "chat"},
            {"label": "Registros", "target": "statement"},
        ],
    },
    "connected_frontier": {
        "accent": "Camada conectada",
        "stat_cards": [
            {"label": "Eventos vivos", "base": 1240, "step": 20, "trend": "+11%", "format": "int"},
            {"label": "Ativos conectados", "base": 128, "step": 2, "trend": "+7%", "format": "int"},
            {"label": "Eficiencia", "base": 82, "step": 1, "trend": "+3 pts", "format": "percent"},
        ],
        "quick_actions": [
            {"label": "Painel conectado", "target": "detail"},
            {"label": "Telemetria", "target": "feed"},
            {"label": "Automacao", "target": "chat"},
            {"label": "Historico", "target": "statement"},
        ],
    },
    "helena_core": {
        "accent": "Helena em contexto",
        "stat_cards": [
            {"label": "Memorias uteis", "base": 164, "step": 3, "trend": "+10%", "format": "int"},
            {"label": "Acoes sugeridas", "base": 58, "step": 1, "trend": "+6%", "format": "int"},
            {"label": "Consentimentos", "base": 93, "step": 0, "trend": "validos", "format": "percent"},
        ],
        "quick_actions": [
            {"label": "Painel Helena", "target": "detail"},
            {"label": "Contexto vivo", "target": "feed"},
            {"label": "Conversar", "target": "chat"},
            {"label": "Historico", "target": "statement"},
        ],
    },
    "platform_flow": {
        "accent": "Fluxo versionado",
        "stat_cards": [
            {"label": "Fluxos ativos", "base": 76, "step": 2, "trend": "+8%", "format": "int"},
            {"label": "Regras publicadas", "base": 32, "step": 1, "trend": "+5%", "format": "int"},
            {"label": "Logs uteis", "base": 940, "step": 16, "trend": "+9%", "format": "int"},
        ],
        "quick_actions": [
            {"label": "Painel de fluxo", "target": "detail"},
            {"label": "Regras ativas", "target": "feed"},
            {"label": "Suporte", "target": "chat"},
            {"label": "Logs", "target": "statement"},
        ],
    },
}

DOMAIN_FAMILY_MAP = {
    "logistics_erp_operations": "ops_logistics",
    "commerce_fintech_assets": "commerce_store",
    "services_health_human": "care_services",
    "education_work_social": "people_journey",
    "media_social_growth": "growth_media",
    "city_mobility_security": "civic_city",
    "frontier_iot_energy": "connected_frontier",
    "ai_memory_operations": "helena_core",
    "platform_developer": "platform_flow",
}

MODULE_FAMILY_OVERRIDES = {
    "MARKETPLACE": "commerce_store",
    "PAY": "finance_core",
    "DIGITAL": "asset_ops",
    "REAL_ESTATE": "asset_ops",
    "INSURANCE": "asset_ops",
    "FINANCAS": "finance_core",
    "PLUG": "finance_core",
    "UP": "finance_core",
    "LEGAL": "legal_safe",
}


def stable_uuid(name: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"valley-demo::{name}"))


def iso_at(index: int, minutes: int = 11) -> str:
    return (BASE_TIME + timedelta(minutes=index * minutes)).isoformat().replace("+00:00", "Z")


def sql_literal(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (dict, list)):
        text = json.dumps(value, ensure_ascii=False)
    else:
        text = str(value)
    return "'" + text.replace("'", "''") + "'"


def load_modules() -> list[dict[str, object]]:
    payload = json.loads(MODULES_PATH.read_text(encoding="utf-8"))
    return payload["modules"]


def _load_active_stock_channels() -> list[dict[str, str]]:
    if not ADMIN_INTEGRATIONS_PATH.exists():
        return [
            dict(STOCK_PROVIDER_BLUEPRINTS["mercado_livre"]),
            dict(STOCK_PROVIDER_BLUEPRINTS["aliexpress"]),
        ]

    try:
        payload = json.loads(ADMIN_INTEGRATIONS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        payload = []

    enabled_keys = [
        str(item.get("key"))
        for item in payload
        if isinstance(item, dict) and item.get("enabled")
    ]
    enabled_channels = [
        dict(STOCK_PROVIDER_BLUEPRINTS[key])
        for key in enabled_keys
        if key in STOCK_PROVIDER_BLUEPRINTS
    ]
    if enabled_channels:
        return enabled_channels
    return [dict(STOCK_PROVIDER_BLUEPRINTS["mercado_livre"])]


def _build_stock_item_blueprint(
    local_index: int,
    module_serial: int,
    provider_pool: list[dict[str, str]],
) -> dict[str, object]:
    template = STOCK_TAXONOMY_BLUEPRINTS[local_index % len(STOCK_TAXONOMY_BLUEPRINTS)]
    provider = provider_pool[local_index % len(provider_pool)]
    release_wave = local_index // len(STOCK_TAXONOMY_BLUEPRINTS)
    brand = str(template["collection_label"])
    merchant_name = "Valley"
    model_root = str(template["model_root"])
    model_name = f"{model_root} {module_serial:03d}"
    title = f"{brand} {model_name}"
    price = round(float(template["base_price"]) + (release_wave * 34.5) + ((local_index % 5) * 7.9), 2)
    compare_price = round(price * 1.18, 2)
    stock = 18 + ((local_index * 3) % 42)
    stock_statuses = [
        "Pronto para vitrine",
        "Reposicao em validacao",
        "Buffer de estoque",
        "Janela promocional",
    ]
    return {
        "brand": brand,
        "merchant_name": merchant_name,
        "category": str(template["category"]),
        "collection_label": brand,
        "model_name": model_name,
        "title": title,
        "price_brl": price,
        "compare_at_brl": compare_price,
        "stock": stock,
        "status": stock_statuses[local_index % len(stock_statuses)],
        "description": (
            f"{title} em linha proprietaria Valley com curadoria por taxonomia Google, "
            "precificacao protegida e operacao omnicanal sem expor origem de fornecedor na vitrine."
        ),
        "features": [
            "Marca propria Valley",
            "Classificacao por taxonomia Google",
            "Curadoria de estoque omnicanal",
        ],
        "seller_name": "Curadoria Valley",
        "seller_headline": "Colecao proprietaria com operacao integrada e sortimento governado por categoria.",
        "google_product_category_id": str(template["taxonomy_id"]),
        "google_product_category_path": str(template["taxonomy_path"]),
        "provider_key": str(provider["provider_key"]),
        "provider_status": str(provider["provider_status"]),
        "supplier_name": str(provider["supplier_name"]),
        "supplier_type": str(provider["supplier_type"]),
        "supplier_model": str(provider["supplier_model"]),
        "channel_label": str(provider["channel_label"]),
        "supplier_visibility": "internal",
        "price_band": (
            "Ate R$ 199"
            if price < 200
            else "R$ 200 a R$ 499"
            if price < 500
            else "R$ 500 a R$ 999"
            if price < 1000
            else "Acima de R$ 1.000"
        ),
    }


def _module_family(module: dict[str, object]) -> str:
    code = str(module["code"])
    if code in MODULE_FAMILY_OVERRIDES:
        return MODULE_FAMILY_OVERRIDES[code]
    domain = str(module["domain"])
    if domain in DOMAIN_FAMILY_MAP:
        return DOMAIN_FAMILY_MAP[domain]
    return "commerce_store"


def _join_codes(values: list[str]) -> str:
    if not values:
        return "sem vinculos declarados"
    if len(values) == 1:
        return values[0]
    if len(values) == 2:
        return f"{values[0]} e {values[1]}"
    return f"{values[0]}, {values[1]} e {values[2]}"


def _format_metric_value(metric: dict[str, object], index: int) -> str:
    base = int(metric["base"])
    step = int(metric.get("step", 0))
    value = base + (index * step)
    fmt = str(metric.get("format", "int"))
    if fmt == "brl":
        return f"R$ {value:,.0f}".replace(",", ".")
    if fmt == "percent":
        return f"{value}%"
    if fmt == "minutes":
        return f"{value} min"
    return str(value)


def _data_home_label(value: str) -> str:
    return DATA_HOME_LABELS.get(value, value)


def _tier_label(value: str) -> str:
    return TIER_LABELS.get(value, value.title())


def _module_context_copy(module: dict[str, object]) -> dict[str, object]:
    code = str(module["code"])
    family = _module_family(module)
    profile = FAMILY_PROFILES[family]
    description = str(module["description_ptbr"]).rstrip(".")
    data_home = str(module["data_home"])
    depends_on = [str(item) for item in module.get("depends_on", [])]
    integrates_with = [str(item) for item in module.get("integrates_with", [])]
    tier = str(module["tier"])

    stat_cards = [
        {
            "label": str(metric["label"]),
            "value": _format_metric_value(metric, index=0),
            "trend": str(metric["trend"]),
        }
        for metric in profile["stat_cards"]
    ]

    return {
        "code": code,
        "family": family,
        "accent_label": str(profile["accent"]),
        "stat_card_templates": profile["stat_cards"],
        "quick_actions": profile["quick_actions"],
        "description": description,
        "depends_on": depends_on,
        "integrates_with": integrates_with,
        "hero_subtitle": (
            f"{description}. Depende de {_join_codes(depends_on)} e conversa com "
            f"{_join_codes(integrates_with)}. {DATA_HOME_NOTES.get(data_home, '')}".strip()
        ),
        "highlights": [
            description,
            f"Integra {_join_codes(integrates_with)} para continuidade sem quebrar a mesma trilha de uso.",
            f"Camada {_tier_label(tier).lower()} ancorada em {_data_home_label(data_home).lower()}.",
        ],
        "helena_hint": (
            f"Helena observa {str(module['subtitle']).lower()} e so assume navegacao quando voce pedir "
            f"para abrir uma proxima etapa ou conectar {code} a {_join_codes(integrates_with[:2])}."
        ),
        "operator_note": (
            f"{str(module['name'])} fica na camada {_tier_label(tier)} e usa {_data_home_label(data_home)} "
            f"como base para manter contexto, prova e continuidade."
        ),
        "stat_cards": stat_cards,
    }


def _module_screen(module: dict[str, object], index: int) -> dict[str, object]:
    code = str(module["code"])
    context = _module_context_copy(module)
    stat_cards = []
    for metric in context["stat_card_templates"]:
        metric = dict(metric)
        stat_cards.append(
            {
                "label": str(metric["label"]),
                "value": _format_metric_value(metric, index),
                "trend": str(metric["trend"]),
            }
        )
    hero_title = str(module["name"])
    hero_subtitle = str(context["hero_subtitle"])
    accent_label = str(context["accent_label"])
    highlights = context["highlights"]
    if code == "STOCK":
        hero_title = "Valley Stock | Catalogo proprietario"
        hero_subtitle = (
            "Sortimento unificado por categoria e taxonomia Google, com canais de "
            "abastecimento internos e marca propria Valley na vitrine."
        )
        accent_label = "Marca propria com taxonomia viva"
        highlights = [
            "Vitrine unificada por categoria, nao por fornecedor.",
            "Classificacao oficial por Google product category para busca, feed e governanca.",
            "Origem do abastecimento fica restrita a operacao interna do Valley.",
        ]
    return {
        "module_id": code,
        "hero_title": hero_title,
        "hero_subtitle": hero_subtitle,
        "accent_label": accent_label,
        "stat_cards": stat_cards,
        "quick_actions": context["quick_actions"],
        "highlights": highlights,
        "description": context["description"],
        "domain": str(module["domain"]),
        "tier": str(module["tier"]),
        "data_home": str(module["data_home"]),
        "depends_on": context["depends_on"],
        "integrates_with": context["integrates_with"],
        "operator_note": str(context["operator_note"]),
        "helena_hint": str(context["helena_hint"]),
    }


def build_demo_records() -> dict[str, object]:
    modules = load_modules()
    stock_channels = _load_active_stock_channels()

    users: list[dict[str, object]] = []
    wallets: list[dict[str, object]] = []
    suppliers: list[dict[str, object]] = []
    warehouses: list[dict[str, object]] = []
    storefronts: list[dict[str, object]] = []
    inventory_items: list[dict[str, object]] = []
    lots: list[dict[str, object]] = []
    listings: list[dict[str, object]] = []
    controls: list[dict[str, object]] = []
    competitors: list[dict[str, object]] = []
    social_videos: list[dict[str, object]] = []
    ai_memory: list[dict[str, object]] = []
    influencer_metrics: list[dict[str, object]] = []
    telemetry_logs: list[dict[str, object]] = []
    profiles: list[dict[str, object]] = []
    feed_entries: list[dict[str, object]] = []
    statement_entries: list[dict[str, object]] = []

    for module_index, module in enumerate(modules):
        for local_index in range(100):
            index = (module_index * 100) + local_index
            number = index + 1
            module_serial = local_index + 1
            module_code = str(module["code"])
            merchant_id = stable_uuid(f"user-{number}")
            wallet_id = stable_uuid(f"wallet-{number}")
            supplier_id = stable_uuid(f"supplier-{number}")
            warehouse_id = stable_uuid(f"warehouse-{number}")
            storefront_id = stable_uuid(f"storefront-{number}")
            item_id = stable_uuid(f"item-{number}")
            lot_id = stable_uuid(f"lot-{number}")
            listing_id = stable_uuid(f"listing-{number}")
            control_id = stable_uuid(f"listing-control-{number}")
            competitor_id = stable_uuid(f"competitor-{number}")
            video_id = stable_uuid(f"video-{number}")
            memory_id = stable_uuid(f"memory-{number}")
            metric_id = stable_uuid(f"metric-{number}")
            telemetry_id = stable_uuid(f"telemetry-{number}")
            profile_id = stable_uuid(f"profile-{number}")
            feed_id = stable_uuid(f"feed-{number}")

            brand = BRANDS[index % len(BRANDS)]
            category = CATEGORIES[index % len(CATEGORIES)]
            image_url = IMAGE_POOL[index % len(IMAGE_POOL)]
            video_url = VIDEO_POOL[index % len(VIDEO_POOL)]
            avatar_url = AVATAR_POOL[index % len(AVATAR_POOL)]
            module_copy = _module_context_copy(module)
            title = f"{brand} {category} {module_code} {module_serial:03d}"
            price = round(299 + (index * 17.45), 2)
            compare_price = round(price * 1.14, 2)
            stock = 12 + (index % 37)
            created_at = iso_at(index)
            city = CITIES[index % len(CITIES)]
            stock_blueprint: dict[str, object] | None = None

            if module_code == "STOCK":
                stock_blueprint = _build_stock_item_blueprint(
                    local_index=local_index,
                    module_serial=module_serial,
                    provider_pool=stock_channels,
                )
                brand = str(stock_blueprint["brand"])
                category = str(stock_blueprint["category"])
                title = str(stock_blueprint["title"])
                price = float(stock_blueprint["price_brl"])
                compare_price = float(stock_blueprint["compare_at_brl"])
                stock = int(stock_blueprint["stock"])

            users.append(
                {
                    "user_id": merchant_id,
                    "user_kind": "PJ",
                    "account_status": "ACTIVE",
                    "kyc_status": "APPROVED",
                    "full_name": f"{brand} Comercio {number:03d}",
                    "display_name": brand,
                    "email": f"merchant{number:03d}@valley.demo",
                    "phone": f"+551199900{number:04d}",
                    "document_number": f"{number:014d}",
                    "created_at": created_at,
                }
            )
            wallets.append({"wallet_id": wallet_id, "user_id": merchant_id, "created_at": created_at})
            suppliers.append(
                {
                    "supplier_id": supplier_id,
                    "user_id": merchant_id,
                    "legal_name": f"{brand} Supply {number:03d}",
                    "created_at": created_at,
                }
            )
            warehouses.append(
                {
                    "warehouse_id": warehouse_id,
                    "owner_user_id": merchant_id,
                    "warehouse_code": f"WH-{number:03d}",
                    "warehouse_name": f"Hub {module_code} {module_serial:03d}",
                    "created_at": created_at,
                }
            )
            storefronts.append(
                {
                    "storefront_id": storefront_id,
                    "merchant_user_id": merchant_id,
                    "wallet_id": wallet_id,
                    "storefront_code": f"STORE-{number:03d}",
                    "storefront_name": f"{brand} Store {number:03d}",
                    "created_at": created_at,
                }
            )
            inventory_items.append(
                {
                    "item_id": item_id,
                    "merchant_user_id": merchant_id,
                    "sku": f"{module_code}-SKU-{module_serial:03d}",
                    "title": title,
                    "category": category,
                    "brand": brand,
                    "description": (
                        str(stock_blueprint["description"])
                        if stock_blueprint
                        else f"{title} com pronta entrega, demonstracao em video e fluxo de compra direto para o usuario final."
                    ),
                    "price_brl": price,
                    "compare_at_brl": compare_price,
                    "stock": stock,
                    "image_url": image_url,
                    "video_url": video_url,
                    "collection_label": (
                        str(stock_blueprint["collection_label"])
                        if stock_blueprint
                        else brand
                    ),
                    "model_name": (
                        str(stock_blueprint["model_name"])
                        if stock_blueprint
                        else f"{module_code} {module_serial:03d}"
                    ),
                    "public_merchant_name": (
                        str(stock_blueprint["merchant_name"])
                        if stock_blueprint
                        else brand
                    ),
                    "seller_name": (
                        str(stock_blueprint["seller_name"])
                        if stock_blueprint
                        else f"{brand} {module_serial:03d}"
                    ),
                    "seller_headline": (
                        str(stock_blueprint["seller_headline"])
                        if stock_blueprint
                        else "Seller validado para continuidade no Valley."
                    ),
                    "google_product_category_id": (
                        str(stock_blueprint["google_product_category_id"])
                        if stock_blueprint
                        else None
                    ),
                    "google_product_category_path": (
                        str(stock_blueprint["google_product_category_path"])
                        if stock_blueprint
                        else None
                    ),
                    "provider_key": (
                        str(stock_blueprint["provider_key"])
                        if stock_blueprint
                        else None
                    ),
                    "provider_status": (
                        str(stock_blueprint["provider_status"])
                        if stock_blueprint
                        else None
                    ),
                    "supplier_name": (
                        str(stock_blueprint["supplier_name"])
                        if stock_blueprint
                        else None
                    ),
                    "supplier_type": (
                        str(stock_blueprint["supplier_type"])
                        if stock_blueprint
                        else None
                    ),
                    "supplier_model": (
                        str(stock_blueprint["supplier_model"])
                        if stock_blueprint
                        else None
                    ),
                    "supplier_visibility": (
                        str(stock_blueprint["supplier_visibility"])
                        if stock_blueprint
                        else None
                    ),
                    "channel_label": (
                        str(stock_blueprint["channel_label"])
                        if stock_blueprint
                        else None
                    ),
                    "price_band": (
                        str(stock_blueprint["price_band"])
                        if stock_blueprint
                        else None
                    ),
                    "status_label": (
                        str(stock_blueprint["status"])
                        if stock_blueprint
                        else None
                    ),
                    "features": (
                        list(stock_blueprint["features"])
                        if stock_blueprint
                        else None
                    ),
                    "created_at": created_at,
                }
            )
            lots.append(
                {
                    "inventory_lot_id": lot_id,
                    "owner_user_id": merchant_id,
                    "item_id": item_id,
                    "warehouse_id": warehouse_id,
                    "supplier_id": supplier_id,
                    "lot_code": f"{module_code}-LOT-{module_serial:03d}",
                    "created_at": created_at,
                }
            )
            listings.append(
                {
                    "listing_id": listing_id,
                    "merchant_user_id": merchant_id,
                    "wallet_id": wallet_id,
                    "item_id": item_id,
                    "title": title,
                    "price_brl": price,
                    "stock": stock,
                    "image_url": image_url,
                    "video_url": video_url,
                    "created_at": created_at,
                }
            )
            controls.append(
                {
                    "listing_control_id": control_id,
                    "listing_id": listing_id,
                    "merchant_user_id": merchant_id,
                    "price_brl": price,
                    "created_at": created_at,
                }
            )
            competitors.append(
                {
                    "competitor_snapshot_id": competitor_id,
                    "listing_id": listing_id,
                    "item_id": item_id,
                    "merchant_user_id": merchant_id,
                    "price_brl": round(price * 1.08, 2),
                    "created_at": created_at,
                }
            )
            profiles.append(
                {
                    "id": profile_id,
                    "user_id": merchant_id,
                    "name": f"{brand} {number:03d}",
                    "headline": f"{module['subtitle']} • {module_code} • contexto ativo",
                    "avatar_url": avatar_url,
                    "cover_url": image_url,
                    "city": city,
                    "presence": PRESENCE[index % len(PRESENCE)],
                    "followers": 1200 + index * 19,
                    "rating": round(4.3 + ((index % 6) * 0.1), 1),
                }
            )
            feed_entries.append(
                {
                    "id": feed_id,
                    "profile_id": profile_id,
                    "module_id": module_code,
                    "author_name": f"{brand} {number:03d}",
                    "author_avatar": avatar_url,
                    "headline": f"{module['name']} colocou {title} em destaque",
                    "text": (
                        f"{module_copy['description']} agora aparece com video ativo, conversa direta "
                        "e continuidade sem perder o contexto do modulo."
                    ),
                    "media_url": image_url,
                    "video_url": video_url,
                    "item_id": listing_id,
                    "likes": 140 + index * 4,
                    "comments": 18 + (index % 13),
                    "shares": 9 + (index % 7),
                    "time_label": f"{(index % 12) + 1}h",
                }
            )
            statement_entries.append(
                {
                    "id": stable_uuid(f"statement-{number}"),
                    "title": "Recebimento de venda" if index % 2 == 0 else "Pagamento de servico",
                    "subtitle": f"{module_code} • {brand}",
                    "amount_brl": round(price if index % 2 == 0 else price * -0.42, 2),
                    "direction": "credit" if index % 2 == 0 else "debit",
                    "status": "processado" if index % 5 else "pendente",
                    "created_at": created_at,
                }
            )
            social_videos.append(
                {
                    "_id": {"$uuid": video_id},
                    "video_id": video_id,
                    "creator_user_id": merchant_id,
                    "owner_user_id": merchant_id,
                    "caption": f"{title} em demonstracao ativa.",
                    "hashtags": ["valley", "produto", module_code.lower()],
                    "media_url": video_url,
                    "thumbnail_url": image_url,
                    "visibility": "PUBLIC",
                    "commission_link": f"https://valley.demo/item/{listing_id}",
                    "product_refs": [{"item_id": item_id, "listing_id": listing_id, "module_code": module_code}],
                    "view_count": 1500 + index * 31,
                    "like_count": 180 + index * 7,
                    "share_count": 32 + index,
                    "comment_count": 14 + (index % 23),
                    "status": "ACTIVE",
                    "created_at": {"$date": created_at},
                    "updated_at": {"$date": created_at},
                }
            )
            ai_memory.append(
                {
                    "_id": {"$uuid": memory_id},
                    "memory_id": memory_id,
                    "user_id": merchant_id,
                    "memory_scope": "BUSINESS",
                    "helena_context_mode": "MERCHANT",
                    "source_module": module_code,
                    "content_summary": (
                        f"Preferencia por jornadas ligadas a {module_copy['description'].lower()} "
                        "com retomada simples e fechamento sem ruptura."
                    ),
                    "content_vector_ref": f"vector://valley/{memory_id}",
                    "importance_score": 0.82,
                    "consent_scope": "PROFILE",
                    "expires_at": None,
                    "created_at": {"$date": created_at},
                    "updated_at": {"$date": created_at},
                }
            )
            influencer_metrics.append(
                {
                    "_id": {"$uuid": metric_id},
                    "metric_id": metric_id,
                    "influencer_user_id": merchant_id,
                    "campaign_id": f"{module_code}-CAMP-{module_serial:03d}",
                    "period_start": {"$date": created_at},
                    "period_end": {"$date": iso_at(index, minutes=23)},
                    "impressions": 12000 + index * 55,
                    "views": 4200 + index * 29,
                    "clicks": 640 + index * 5,
                    "ctr": 0.054,
                    "conversions": 48 + (index % 17),
                    "gross_sales_brl": round(price * 14, 2),
                    "commission_brl": round(price * 1.4, 2),
                    "engagement_rate": 0.127,
                    "source_breakdown": {"social": 0.54, "direct": 0.21, "ads": 0.25},
                    "created_at": {"$date": created_at},
                }
            )
            telemetry_logs.append(
                {
                    "_id": {"$uuid": telemetry_id},
                    "telemetry_id": telemetry_id,
                    "user_id": merchant_id,
                    "rider_user_id": None,
                    "device_id": f"{module_code.lower()}-device-{module_serial:03d}",
                    "event_type": "GPS_PING",
                    "event_source": "MOBILE_APP",
                    "geo": {"type": "Point", "coordinates": [-46.63 + (index * 0.001), -23.55 + (index * 0.001)]},
                    "speed_kph": 18 + (index % 7),
                    "battery_level": 88 - (index % 11),
                    "sensor_payload": {"screen": "product_mode", "listing_id": listing_id},
                    "correlation_id": listing_id,
                    "event_time": {"$date": created_at},
                    "ingested_at": {"$date": created_at},
                }
            )

    conversations: list[dict[str, object]] = []
    for index, profile in enumerate(profiles):
        conversation_id = stable_uuid(f"conversation-{index + 1}")
        messages = []
        for message_index in range(4):
            sent_by_me = message_index % 2 == 0
            messages.append(
                {
                    "id": stable_uuid(f"conversation-{index + 1}-message-{message_index + 1}"),
                    "sender": "me" if sent_by_me else "contact",
                    "text": (
                        "Consegue entregar hoje ainda?"
                        if sent_by_me
                        else "Sim. Ja deixei a proposta pronta com o fluxo premium e o pagamento direto no app."
                    ),
                    "created_at": iso_at(index + message_index, minutes=7),
                }
            )
        conversations.append(
            {
                "id": conversation_id,
                "profile_id": profile["id"],
                "title": profile["name"],
                "subtitle": profile["headline"],
                "avatar_url": profile["avatar_url"],
                "unread_count": index % 4,
                "last_message_at": iso_at(index, minutes=7),
                "messages": messages,
            }
        )

    module_screens = [_module_screen(module, index) for index, module in enumerate(modules)]

    catalog_items = []
    for index, listing in enumerate(listings):
        item = inventory_items[index]
        module = modules[index // 100]
        profile = profiles[index]
        is_stock = str(module["code"]) == "STOCK"
        visible_merchant_name = str(item.get("public_merchant_name") or users[index]["display_name"])
        status_label = (
            str(item.get("status_label"))
            if is_stock and item.get("status_label")
            else ("disponivel" if index % 5 != 0 else "quase esgotado")
        )
        tags = (
            [
                "Marca Propria Valley",
                str(item["category"]),
                str(item.get("collection_label") or item["brand"]),
                str(module["code"]),
            ]
            if is_stock
            else [item["category"], str(module["code"]), "Premium"]
        )
        catalog_items.append(
            {
                "id": listing["listing_id"],
                "module_id": module["code"],
                "title": listing["title"],
                "brand": item["brand"],
                "category": item["category"],
                "price_brl": listing["price_brl"],
                "compare_at_brl": item["compare_at_brl"],
                "stock": listing["stock"],
                "merchant_name": visible_merchant_name,
                "image_url": listing["image_url"],
                "video_url": listing["video_url"],
                "video_count": 1,
                "status": status_label,
                "tags": tags,
                "cta_label": "Abrir",
                "cta_path": f"/api/actions/product-interest?item_id={listing['listing_id']}",
                "media_path": f"/api/actions/open-media?item_id={listing['listing_id']}",
                "description": (
                    str(item["description"])
                    if is_stock
                    else (
                        f"{item['title']} dentro de {module['name']}: {module['description_ptbr']} "
                        "Fluxo pronto para detalhe, conversa e continuidade no shell."
                    )
                ),
                "gallery_urls": [
                    listing["image_url"],
                    *[
                        IMAGE_POOL[(index + offset) % len(IMAGE_POOL)]
                        for offset in range(1, 3)
                    ],
                ][:3],
                "profile_id": profile["id"],
                "features": (
                    list(item.get("features") or [])
                    if is_stock
                    else [
                        "Video demonstrativo pronto",
                        "Compra com checkout direto",
                        "Suporte via chat integrado",
                    ]
                ),
                "seller": {
                    "name": str(item.get("seller_name") or profile["name"]),
                    "headline": str(item.get("seller_headline") or "Seller validado para continuidade no Valley."),
                    "avatar_url": profile["avatar_url"],
                    "rating": profile["rating"],
                    "city": profile["city"],
                },
                "checkout": {
                    "headline": "Resumo de compra",
                    "shipping_brl": 19.9 + (index % 4) * 6,
                    "service_brl": 4.9,
                    "installments": 12,
                    "eta": f"{2 + (index % 3)} dias",
                },
                "raw_badge": str(module["subtitle"]),
                "collection_label": item.get("collection_label"),
                "model_name": item.get("model_name"),
                "google_product_category_id": item.get("google_product_category_id"),
                "google_product_category_path": item.get("google_product_category_path"),
                "google_product_category": item.get("google_product_category_path"),
                "provider_key": item.get("provider_key"),
                "provider_status": item.get("provider_status"),
                "supplier_name": item.get("supplier_name"),
                "supplier_type": item.get("supplier_type"),
                "supplier_model": item.get("supplier_model"),
                "supplier_visibility": item.get("supplier_visibility"),
                "channel_label": item.get("channel_label"),
                "price_band": item.get("price_band"),
            }
        )

    catalog = {
        "generated_at_utc": iso_at(0),
        "hero": {
            "title": "Valley Stock | Catalogo proprietario",
            "subtitle": "Colecoes Valley organizadas por categoria e taxonomia Google, com operacao omnicanal e vitrine limpa de fornecedor.",
        },
        "modules": [
            {
                "id": module["code"],
                "label": module["name"],
                "subtitle": module["subtitle"],
                "badge": "ativo",
            }
            for module in modules
        ],
        "summary": {
            "products": len(catalog_items),
            "videos": len(social_videos),
            "merchants": len(users),
            "warehouses": len(warehouses),
        },
        "module_screens": module_screens,
        "profiles": profiles,
        "feed_entries": feed_entries,
        "conversations": conversations,
        "statement_entries": statement_entries,
        "items": catalog_items,
    }

    return {
        "catalog": catalog,
        "sql_tables": {
            "users": users,
            "wallets": wallets,
            "suppliers": suppliers,
            "warehouses": warehouses,
            "merchant_storefronts": storefronts,
            "inventory_items": inventory_items,
            "inventory_lots": lots,
            "marketplace_listings": listings,
            "marketplace_listing_controls": controls,
            "marketplace_competitor_snapshots": competitors,
        },
        "mongo": {
            "ai_memory": ai_memory,
            "social_videos": social_videos,
            "influencer_metrics": influencer_metrics,
            "telemetry_logs": telemetry_logs,
        },
    }


def build_postgres_seed(payload: dict[str, object]) -> str:
    sql_tables = payload["sql_tables"]
    users = sql_tables["users"]
    wallets = sql_tables["wallets"]
    suppliers = sql_tables["suppliers"]
    warehouses = sql_tables["warehouses"]
    storefronts = sql_tables["merchant_storefronts"]
    items = sql_tables["inventory_items"]
    lots = sql_tables["inventory_lots"]
    listings = sql_tables["marketplace_listings"]
    controls = sql_tables["marketplace_listing_controls"]
    competitors = sql_tables["marketplace_competitor_snapshots"]

    lines = [
        "-- Seed demo modo produto Valley.",
        "-- Gerado automaticamente por scripts/generate_valley_product_demo_catalog.py.",
        "BEGIN;",
        "SET search_path = public;",
    ]

    for row in users:
        lines.extend(
            [
                "INSERT INTO users (user_id, user_kind, account_status, kyc_status, full_name, display_name, email, phone_e164, document_country, document_type, document_number, primary_role, module_tier, created_at, updated_at)",
                f"VALUES ({sql_literal(row['user_id'])}, 'PJ', 'ACTIVE', 'APPROVED', {sql_literal(row['full_name'])}, {sql_literal(row['display_name'])}, {sql_literal(row['email'])}, {sql_literal(row['phone'])}, 'BR', 'CNPJ', {sql_literal(row['document_number'])}, 'MERCHANT', 'PRODUCT', {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (user_id) DO NOTHING;",
            ]
        )

    for row in wallets:
        lines.extend(
            [
                "INSERT INTO wallets (wallet_id, user_id, wallet_type, asset_code, wallet_status, balance_available_brl, daily_limit_brl, monthly_limit_brl, created_at, updated_at)",
                f"VALUES ({sql_literal(row['wallet_id'])}, {sql_literal(row['user_id'])}, 'CUSTODIAL', 'BRL', 'ACTIVE', 12500.0000, 5000.0000, 50000.0000, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (wallet_id) DO NOTHING;",
            ]
        )

    for row in suppliers:
        contact_email = f"contato@{str(row['legal_name']).lower().replace(' ', '-')}.demo"
        lines.extend(
            [
                "INSERT INTO suppliers (supplier_id, supplier_user_id, module_code, supplier_status, legal_name, trade_name, default_margin_rate, lead_time_days, rating_score, contact_json, compliance_json, created_at, updated_at)",
                f"VALUES ({sql_literal(row['supplier_id'])}, {sql_literal(row['user_id'])}, 'STOCK', 'ACTIVE', {sql_literal(row['legal_name'])}, {sql_literal(row['legal_name'])}, 0.2800, 3, 94.00, {sql_literal({'email': contact_email})}::jsonb, {sql_literal({'kyb': 'approved'})}::jsonb, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (supplier_id) DO NOTHING;",
            ]
        )

    for row in warehouses:
        lines.extend(
            [
                "INSERT INTO warehouses (warehouse_id, owner_user_id, module_code, warehouse_code, warehouse_name, warehouse_status, address_json, geo_json, capacity_units, metadata_json, created_at, updated_at)",
                f"VALUES ({sql_literal(row['warehouse_id'])}, {sql_literal(row['owner_user_id'])}, 'WMS', {sql_literal(row['warehouse_code'])}, {sql_literal(row['warehouse_name'])}, 'ACTIVE', {sql_literal({'city': 'Sao Paulo', 'district': 'Centro'})}::jsonb, {sql_literal({'type': 'Point', 'coordinates': [-46.63, -23.55]})}::jsonb, 1800.0000, {sql_literal({'temperature_control': True})}::jsonb, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (warehouse_id) DO NOTHING;",
            ]
        )

    for row in storefronts:
        lines.extend(
            [
                "INSERT INTO merchant_storefronts (storefront_id, merchant_user_id, wallet_id, module_code, storefront_code, storefront_name, storefront_status, address_json, geo_json, service_radius_km, service_modes, accepts_marketplace_sales, accepts_physical_sales, schedule_json, metadata_json, created_at, updated_at)",
                f"VALUES ({sql_literal(row['storefront_id'])}, {sql_literal(row['merchant_user_id'])}, {sql_literal(row['wallet_id'])}, 'MARKETPLACE', {sql_literal(row['storefront_code'])}, {sql_literal(row['storefront_name'])}, 'ACTIVE', {sql_literal({'city': 'Sao Paulo', 'state': 'SP'})}::jsonb, {sql_literal({'type': 'Point', 'coordinates': [-46.63, -23.55]})}::jsonb, 12.0000, ARRAY['DELIVERY','PICKUP']::text[], TRUE, TRUE, {sql_literal({'mon': '08-22', 'tue': '08-22'})}::jsonb, {sql_literal({'theme': 'product-mode'})}::jsonb, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (storefront_id) DO NOTHING;",
            ]
        )

    for row in items:
        attributes = {
            "brand": row["brand"],
            "category": row["category"],
            "gallery": [row["image_url"]],
            "demo_video_url": row["video_url"],
        }
        lines.extend(
            [
                "INSERT INTO inventory_items (item_id, merchant_user_id, module_code, item_sku, item_name, item_description, item_type, item_status, category_path, unit_of_measure, base_price_brl, cost_reference_brl, attributes_json, created_at, updated_at)",
                f"VALUES ({sql_literal(row['item_id'])}, {sql_literal(row['merchant_user_id'])}, 'MARKETPLACE', {sql_literal(row['sku'])}, {sql_literal(row['title'])}, {sql_literal(row['description'])}, 'PHYSICAL', 'ACTIVE', ARRAY[{sql_literal(row['category'])}]::text[], 'UNIT', {row['price_brl']:.4f}, {(row['price_brl'] * 0.68):.4f}, {sql_literal(attributes)}::jsonb, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (item_id) DO NOTHING;",
            ]
        )

    for row in lots:
        lines.extend(
            [
                "INSERT INTO inventory_lots (inventory_lot_id, owner_user_id, item_id, warehouse_id, supplier_id, lot_code, lot_status, quantity_available, quantity_reserved, quantity_damaged, unit_cost_brl, received_at, metadata_json, created_at, updated_at)",
                f"VALUES ({sql_literal(row['inventory_lot_id'])}, {sql_literal(row['owner_user_id'])}, {sql_literal(row['item_id'])}, {sql_literal(row['warehouse_id'])}, {sql_literal(row['supplier_id'])}, {sql_literal(row['lot_code'])}, 'AVAILABLE', 42.0000, 4.0000, 0.0000, 148.0000, {sql_literal(row['created_at'])}, {sql_literal({'dock': 'A1', 'demo_mode': True})}::jsonb, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (inventory_lot_id) DO NOTHING;",
            ]
        )

    for row in listings:
        lines.extend(
            [
                "INSERT INTO marketplace_listings (listing_id, merchant_user_id, wallet_id, item_id, module_code, listing_status, listing_title, listing_description, price_brl, commission_rate, stock_strategy, available_quantity_snapshot, published_at, created_at, updated_at)",
                f"VALUES ({sql_literal(row['listing_id'])}, {sql_literal(row['merchant_user_id'])}, {sql_literal(row['wallet_id'])}, {sql_literal(row['item_id'])}, 'MARKETPLACE', 'ACTIVE', {sql_literal(row['title'])}, {sql_literal('Entrega pronta e vitrine ativa.')}, {row['price_brl']:.4f}, 0.1200, 'REAL_TIME', {row['stock']:.4f}, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (listing_id) DO NOTHING;",
            ]
        )

    for row in controls:
        lines.extend(
            [
                "INSERT INTO marketplace_listing_controls (listing_control_id, listing_id, merchant_user_id, pricing_status, valley_cost_brl, target_margin_brl, minimum_price_brl, last_market_reference_brl, last_competitor_name, last_checked_at, auto_publish_enabled, metadata_json, created_at, updated_at)",
                f"VALUES ({sql_literal(row['listing_control_id'])}, {sql_literal(row['listing_id'])}, {sql_literal(row['merchant_user_id'])}, 'COMPETITIVE', {(row['price_brl'] * 0.64):.4f}, {(row['price_brl'] * 0.18):.4f}, {(row['price_brl'] * 0.92):.4f}, {(row['price_brl'] * 1.08):.4f}, 'Benchmark Store', {sql_literal(row['created_at'])}, TRUE, {sql_literal({'mode': 'product-demo'})}::jsonb, {sql_literal(row['created_at'])}, {sql_literal(row['created_at'])})",
                "ON CONFLICT (listing_control_id) DO NOTHING;",
            ]
        )

    for row in competitors:
        lines.extend(
            [
                "INSERT INTO marketplace_competitor_snapshots (competitor_snapshot_id, listing_id, item_id, merchant_user_id, competitor_name, competitor_url, competitor_sku, competitor_price_brl, shipping_price_brl, captured_at)",
                f"VALUES ({sql_literal(row['competitor_snapshot_id'])}, {sql_literal(row['listing_id'])}, {sql_literal(row['item_id'])}, {sql_literal(row['merchant_user_id'])}, 'Benchmark Store', 'https://benchmark.valley.demo', 'CMP-' || substr({sql_literal(row['item_id'])}, 1, 8), {row['price_brl']:.4f}, 19.9000, {sql_literal(row['created_at'])})",
                "ON CONFLICT (competitor_snapshot_id) DO NOTHING;",
            ]
        )

    lines.extend(["COMMIT;", ""])
    return "\n".join(lines)


def build_mongo_seed(payload: dict[str, object]) -> str:
    mongo = payload["mongo"]
    lines = [
        "// Seed demo modo produto Valley.",
        "// Gerado automaticamente por scripts/generate_valley_product_demo_catalog.py.",
        "const deserialize = (doc) => EJSON.deserialize(doc);",
        "db.ai_memory.bulkWrite([",
    ]
    lines.extend(
        [
            f"  {{ replaceOne: {{ filter: {{ memory_id: '{doc['memory_id']}' }}, replacement: deserialize({json.dumps(doc, ensure_ascii=False)}), upsert: true }} }},"
            for doc in mongo["ai_memory"]
        ]
    )
    lines.append("]);")
    lines.append("db.social_videos.bulkWrite([")
    lines.extend(
        [
            f"  {{ replaceOne: {{ filter: {{ video_id: '{doc['video_id']}' }}, replacement: deserialize({json.dumps(doc, ensure_ascii=False)}), upsert: true }} }},"
            for doc in mongo["social_videos"]
        ]
    )
    lines.append("]);")
    lines.append("db.influencer_metrics.bulkWrite([")
    lines.extend(
        [
            f"  {{ replaceOne: {{ filter: {{ metric_id: '{doc['metric_id']}' }}, replacement: deserialize({json.dumps(doc, ensure_ascii=False)}), upsert: true }} }},"
            for doc in mongo["influencer_metrics"]
        ]
    )
    lines.append("]);")
    lines.append("db.telemetry_logs.bulkWrite([")
    lines.extend(
        [
            f"  {{ replaceOne: {{ filter: {{ telemetry_id: '{doc['telemetry_id']}' }}, replacement: deserialize({json.dumps(doc, ensure_ascii=False)}), upsert: true }} }},"
            for doc in mongo["telemetry_logs"]
        ]
    )
    lines.append("]);")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    payload = build_demo_records()
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    POSTGRES_SEED_PATH.parent.mkdir(parents=True, exist_ok=True)
    MONGO_SEED_PATH.parent.mkdir(parents=True, exist_ok=True)

    CATALOG_PATH.write_text(
        json.dumps(payload["catalog"], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    POSTGRES_SEED_PATH.write_text(build_postgres_seed(payload), encoding="utf-8")
    MONGO_SEED_PATH.write_text(build_mongo_seed(payload), encoding="utf-8")

    print(
        json.dumps(
            {
                "status": "ok",
                "catalog": str(CATALOG_PATH.relative_to(ROOT)),
                "postgres_seed": str(POSTGRES_SEED_PATH.relative_to(ROOT)),
                "mongo_seed": str(MONGO_SEED_PATH.relative_to(ROOT)),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
