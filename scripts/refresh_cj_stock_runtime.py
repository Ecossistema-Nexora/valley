#!/usr/bin/env python3
"""Atualiza incrementalmente o runtime do STOCK para itens do CJDropshipping."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any

from import_real_stock_catalog import (
    CATALOG_PATH,
    CJ_CATEGORY_PLANS,
    CJDROPSHIPPING_KEY,
    CJDropshippingClient,
    FULL_STOCK_PATH,
    INTEGRATIONS_PATH,
    PREVIEW_LIMIT,
    ROOT,
    SECRETS_PATH,
    build_cj_stock_item,
    cj_matches_source,
    dedupe_stock_items,
    fetch_usd_brl_rate,
    load_json,
    round_robin_preview,
    sanitize_public_stock_item,
    utc_now_iso,
    write_json,
)

RUNTIME_CJ_INDEX_KEY = "cjdropshipping"


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", value or "")).strip()


def parse_json_array(raw_value: Any) -> list[str]:
    if isinstance(raw_value, list):
        return [str(item).strip() for item in raw_value if str(item).strip()]
    text = str(raw_value or "").strip()
    if not text:
        return []
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return [text]
    if isinstance(payload, list):
        return [str(item).strip() for item in payload if str(item).strip()]
    return [text]


def split_category_path(category_name: str) -> tuple[str, str, str]:
    segments = [segment.strip() for segment in category_name.split("/") if segment.strip()]
    padded = (segments + ["", "", ""])[:3]
    return padded[0], padded[1], padded[2]


def safe_int(value: Any, default: int = 0) -> int:
    try:
        if value is None or value == "":
            return default
        return int(float(str(value).strip()))
    except (TypeError, ValueError):
        return default


def derive_stock_from_variants(variants: list[dict[str, Any]]) -> tuple[int, int, int]:
    cj_inventory_total = 0
    verified_warehouses = 0
    total_inventory = 0
    for variant in variants:
        inventories = variant.get("inventories")
        if not isinstance(inventories, list):
            continue
        for inventory in inventories:
            if not isinstance(inventory, dict):
                continue
            cj_inventory_total += safe_int(inventory.get("cjInventory"))
            total_inventory += safe_int(inventory.get("totalInventory"))
            verified_warehouses += safe_int(inventory.get("verifiedWarehouse"))
    return cj_inventory_total, total_inventory, verified_warehouses


def detail_to_cj_item(detail: dict[str, Any]) -> dict[str, Any]:
    category_name = str(detail.get("categoryName") or "").strip()
    one_category, two_category, three_category = split_category_path(category_name)
    variants = detail.get("variants") if isinstance(detail.get("variants"), list) else []
    cj_inventory_total, total_inventory, verified_warehouses = derive_stock_from_variants(variants)
    images = parse_json_array(detail.get("productImage"))
    big_image = str(detail.get("bigImage") or (images[0] if images else "")).strip()
    product_video = str(detail.get("productVideo") or "").strip()
    return {
        "id": str(detail.get("pid") or "").strip(),
        "nameEn": str(detail.get("productNameEn") or "").strip(),
        "sku": str(detail.get("productSku") or "").strip(),
        "listedNum": safe_int(detail.get("listedNum")),
        "bigImage": big_image,
        "sellPrice": detail.get("sellPrice"),
        "productType": detail.get("productType"),
        "categoryId": str(detail.get("categoryId") or "").strip(),
        "threeCategoryName": three_category or two_category or one_category,
        "twoCategoryId": "",
        "twoCategoryName": two_category or one_category,
        "oneCategoryId": "",
        "oneCategoryName": one_category,
        "supplierName": str(detail.get("supplierName") or "").strip() or None,
        "videoList": [product_video] if product_video else [],
        "warehouseInventoryNum": total_inventory,
        "totalVerifiedInventory": cj_inventory_total,
        "totalUnVerifiedInventory": max(total_inventory - cj_inventory_total, 0),
        "verifiedWarehouse": verified_warehouses,
        "description": clean_text(str(detail.get("description") or "")),
        "spu": str(detail.get("productSku") or "").strip(),
        "saleStatus": str(detail.get("status") or "").strip(),
        "variants": variants,
    }


def resolve_source_for_detail(detail_item: dict[str, Any], existing_item: dict[str, Any] | None) -> tuple[str, Any]:
    for category_plan in CJ_CATEGORY_PLANS:
        for source in category_plan.sources:
            if cj_matches_source(detail_item, source):
                return category_plan.category, source

    if existing_item is not None:
        fallback_source = next(
            source
            for category_plan in CJ_CATEGORY_PLANS
            for source in category_plan.sources
            if source.collection_label == str(existing_item.get("collection_label") or source.collection_label)
        )
        return str(existing_item.get("category") or "Smart Living"), fallback_source

    fallback_category_plan = CJ_CATEGORY_PLANS[0]
    fallback_source = fallback_category_plan.sources[0]
    return fallback_category_plan.category, fallback_source


def find_existing_item(items: list[dict[str, Any]], pid: str) -> dict[str, Any] | None:
    return next(
        (
            item
            for item in items
            if isinstance(item, dict)
            and item.get("provider_key") == CJDROPSHIPPING_KEY
            and str(item.get("source_product_id") or "").strip() == pid
        ),
        None,
    )


def load_runtime_indexes(runtime: dict[str, Any]) -> dict[str, Any]:
    indexes = runtime.get("indexes")
    if isinstance(indexes, dict):
        return indexes
    return {}


def load_cj_vid_pid_index(runtime: dict[str, Any]) -> dict[str, str]:
    indexes = load_runtime_indexes(runtime)
    cj_index = indexes.get(RUNTIME_CJ_INDEX_KEY)
    if not isinstance(cj_index, dict):
        return {}
    vid_to_pid = cj_index.get("vid_to_pid")
    if not isinstance(vid_to_pid, dict):
        return {}
    return {
        str(vid).strip(): str(pid).strip()
        for vid, pid in vid_to_pid.items()
        if str(vid).strip() and str(pid).strip()
    }


def update_cj_vid_pid_index(index: dict[str, str], detail: dict[str, Any]) -> None:
    pid = str(detail.get("pid") or "").strip()
    if not pid:
        return
    variants = detail.get("variants")
    if not isinstance(variants, list):
        return
    for variant in variants:
        if not isinstance(variant, dict):
            continue
        vid = str(variant.get("vid") or "").strip()
        if vid:
            index[vid] = pid


def persist_runtime_indexes(runtime_payload: dict[str, Any], vid_to_pid: dict[str, str]) -> None:
    indexes = load_runtime_indexes(runtime_payload)
    cj_index = indexes.get(RUNTIME_CJ_INDEX_KEY)
    if not isinstance(cj_index, dict):
        cj_index = {}
    cj_index["vid_to_pid"] = dict(sorted(vid_to_pid.items()))
    cj_index["updated_at_utc"] = utc_now_iso()
    indexes[RUNTIME_CJ_INDEX_KEY] = cj_index
    runtime_payload["indexes"] = indexes


def query_pid_by_vid(client: CJDropshippingClient, vid: str) -> str | None:
    payload = client.get_json("/product/variant/queryByVid", params={"vid": vid, "features": "enable_inventory"})
    data = payload.get("data") if isinstance(payload, dict) else None
    if isinstance(data, dict):
        pid = str(data.get("pid") or "").strip()
        return pid or None
    return None


def query_detail_by_pid(client: CJDropshippingClient, pid: str) -> dict[str, Any] | None:
    payload = client.get_json("/product/query", params={"pid": pid, "features": "enable_video,enable_inventory"})
    if not isinstance(payload, dict):
        return None
    if int(payload.get("code") or 0) != 200:
        return None
    data = payload.get("data")
    if isinstance(data, dict):
        return data
    return None


def update_bundle_preview(stock_items: list[dict[str, Any]]) -> None:
    catalog = load_json(CATALOG_PATH, {})
    if not isinstance(catalog, dict):
        return
    existing_items = catalog.get("items") if isinstance(catalog.get("items"), list) else []
    non_stock_items = [
        item for item in existing_items if isinstance(item, dict) and str(item.get("module_id")) != "STOCK"
    ]
    preview_items = round_robin_preview(
        [sanitize_public_stock_item(item) for item in stock_items],
        PREVIEW_LIMIT,
    )
    catalog["items"] = preview_items + non_stock_items
    summary = catalog.get("summary") if isinstance(catalog.get("summary"), dict) else {}
    summary["products"] = len(stock_items) + len(non_stock_items)
    catalog["summary"] = summary
    catalog["generated_at_utc"] = utc_now_iso()
    write_json(CATALOG_PATH, catalog)


def refresh_runtime_by_targets(pids: list[str], vids: list[str]) -> dict[str, Any]:
    runtime = load_json(FULL_STOCK_PATH, {})
    runtime_items = runtime.get("items") if isinstance(runtime, dict) and isinstance(runtime.get("items"), list) else []
    integrations = load_json(INTEGRATIONS_PATH, [])
    secrets = load_json(SECRETS_PATH, {})
    client = CJDropshippingClient(integrations if isinstance(integrations, list) else [], secrets if isinstance(secrets, dict) else {})
    fx_rate, fx_reference = fetch_usd_brl_rate()
    vid_to_pid = load_cj_vid_pid_index(runtime if isinstance(runtime, dict) else {})

    resolved_pids = {pid.strip() for pid in pids if pid and pid.strip()}
    for vid in {vid.strip() for vid in vids if vid and vid.strip()}:
        pid = vid_to_pid.get(vid) or query_pid_by_vid(client, vid)
        if pid:
            resolved_pids.add(pid)
            vid_to_pid[vid] = pid

    if not resolved_pids:
        return {"status": "noop", "detail": "Nenhum pid/vid valido informado."}

    updated = 0
    removed = 0
    touched: list[str] = []
    remaining_items = [item for item in runtime_items if isinstance(item, dict)]

    for pid in sorted(resolved_pids):
        existing_item = find_existing_item(remaining_items, pid)
        detail = query_detail_by_pid(client, pid)
        if detail is None:
            before = len(remaining_items)
            remaining_items = [
                item
                for item in remaining_items
                if not (
                    item.get("provider_key") == CJDROPSHIPPING_KEY
                    and str(item.get("source_product_id") or "").strip() == pid
                )
            ]
            if len(remaining_items) < before:
                removed += 1
                touched.append(pid)
            continue

        update_cj_vid_pid_index(vid_to_pid, detail)
        cj_item = detail_to_cj_item(detail)
        category, source = resolve_source_for_detail(cj_item, existing_item)
        new_item = build_cj_stock_item(
            cj_item,
            source,
            category,
            fx_rate,
            fx_reference,
            client.open_id,
        )
        remaining_items = [
            item
            for item in remaining_items
            if not (
                item.get("provider_key") == CJDROPSHIPPING_KEY
                and str(item.get("source_product_id") or "").strip() == pid
            )
        ]
        remaining_items.append(new_item)
        updated += 1
        touched.append(pid)

    deduped_items = dedupe_stock_items(remaining_items)
    provider_counts: dict[str, int] = {}
    for item in deduped_items:
        if not isinstance(item, dict):
            continue
        provider_key = str(item.get("provider_key") or "unknown")
        provider_counts[provider_key] = provider_counts.get(provider_key, 0) + 1

    runtime_payload = runtime if isinstance(runtime, dict) else {}
    runtime_payload.update(
        {
            "status": "ok",
            "service": "valley-stock-real-catalog",
            "generated_at_utc": utc_now_iso(),
            "provider": "multi_provider_catalog" if len(provider_counts) > 1 else (next(iter(provider_counts), "runtime")),
            "providers_active": sorted(provider_counts),
            "provider_counts": provider_counts,
            "ptax_usd_brl": {
                "usd_brl_rate": fx_rate,
                "reference": fx_reference,
            },
            "items_total": len(deduped_items),
            "categories_total": len({str(item.get("category") or "") for item in deduped_items}),
            "items": deduped_items,
        }
    )
    persist_runtime_indexes(runtime_payload, vid_to_pid)

    write_json(FULL_STOCK_PATH, runtime_payload)
    update_bundle_preview(deduped_items)
    return {
        "status": "ok",
        "updated": updated,
        "removed": removed,
        "touched_pids": touched,
        "index_size": len(vid_to_pid),
        "provider_counts": provider_counts,
        "items_total": len(deduped_items),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refresh incremental do catálogo CJ no runtime STOCK.")
    parser.add_argument("--pid", action="append", default=[], help="PID CJ para refresh incremental.")
    parser.add_argument("--vid", action="append", default=[], help="VID CJ para refresh incremental.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    payload = refresh_runtime_by_targets(args.pid, args.vid)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
