#!/usr/bin/env python3
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
    "Nexora Prime",
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


def _module_screen(module: dict[str, object], index: int) -> dict[str, object]:
    code = str(module["code"])
    return {
        "module_id": code,
        "hero_title": f"{module['name']} em modo produto",
        "hero_subtitle": f"{module['subtitle']} com jornada pronta para usuario final, acoes vivas, feed contextual e continuidade elegante.",
        "accent_label": "Experiencia ativa",
        "stat_cards": [
            {"label": "Sessoes", "value": f"{1400 + index * 17}", "trend": "+12%"},
            {"label": "Conversoes", "value": f"{84 + index}", "trend": "+8%"},
            {"label": "Retorno", "value": f"R$ {4200 + index * 95}", "trend": "+15%"},
        ],
        "quick_actions": [
            {"label": "Abrir painel", "target": "module"},
            {"label": "Ver feed", "target": "feed"},
            {"label": "Conversar", "target": "chat"},
            {"label": "Extrato", "target": "statement"},
        ],
        "highlights": [
            f"Jornada premium pronta para {code.lower()}",
            "Transicoes discretas e leitura imediata",
            "Acesso rapido por dock flutuante",
        ],
    }


def build_demo_records() -> dict[str, object]:
    modules = load_modules()

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
            title = f"{brand} {category} {module_code} {module_serial:03d}"
            price = round(299 + (index * 17.45), 2)
            compare_price = round(price * 1.14, 2)
            stock = 12 + (index % 37)
            created_at = iso_at(index)
            city = CITIES[index % len(CITIES)]

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
                    "description": f"{title} com pronta entrega, demonstracao em video e fluxo de compra direto para o usuario final.",
                    "price_brl": price,
                    "compare_at_brl": compare_price,
                    "stock": stock,
                    "image_url": image_url,
                    "video_url": video_url,
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
                    "headline": f"{category} • {module_code} • experiencia premium",
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
                    "headline": f"{title} entrou em destaque",
                    "text": "Lancamento com video ativo, conversa direta, checkout simplificado e entrega no ecossistema Valley.",
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
                    "persona_mode": "MERCHANT",
                    "source_module": module_code,
                    "content_summary": f"Preferencia por vitrine premium e recompra rapida para {title}.",
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
        module = modules[index % len(modules)]
        profile = profiles[index]
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
                "merchant_name": users[index]["display_name"],
                "image_url": listing["image_url"],
                "video_url": listing["video_url"],
                "video_count": 1,
                "status": "disponivel" if index % 5 != 0 else "quase esgotado",
                "tags": [item["category"], str(module["code"]), "Premium"],
                "cta_label": "Abrir",
                "cta_path": f"/api/actions/product-interest?item_id={listing['listing_id']}",
                "media_path": f"/api/actions/open-media?item_id={listing['listing_id']}",
                "description": item["description"],
                "gallery_urls": [
                    listing["image_url"],
                    *[
                        IMAGE_POOL[(index + offset) % len(IMAGE_POOL)]
                        for offset in range(1, 3)
                    ],
                ][:3],
                "profile_id": profile["id"],
                "features": [
                    "Video demonstrativo pronto",
                    "Compra com checkout direto",
                    "Suporte via chat integrado",
                ],
                "seller": {
                    "name": profile["name"],
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
            }
        )

    catalog = {
        "generated_at_utc": iso_at(0),
        "hero": {
            "title": "Valley",
            "subtitle": "Compra, explore e acesse seus modulos em uma unica experiencia.",
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
