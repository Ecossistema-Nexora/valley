#!/usr/bin/env python3
"""Traduz o runtime do catalogo STOCK para pt-BR com cache persistente."""

from __future__ import annotations

import hashlib
import json
import re
import sys
import time
import urllib.parse
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from import_real_stock_catalog import (
    CATALOG_PATH,
    FULL_STOCK_PATH,
    PREVIEW_LIMIT,
    RUNTIME_DIR,
    round_robin_preview,
    sanitize_public_stock_item,
    write_json,
)


TRANSLATED_STOCK_PATH = RUNTIME_DIR / "valley-stock-real-catalog-ptbr.json"
TRANSLATION_CACHE_PATH = RUNTIME_DIR / "valley-stock-translation-cache.json"
TRANSLATION_STATUS_PATH = RUNTIME_DIR / "valley-stock-translation-status.json"
PRICING_RUNTIME_PATH = RUNTIME_DIR / "valley-admin-imported-products-pricing.json"
STOCK_PUBLICATION_POLICY_PATH = RUNTIME_DIR.parents[1] / "config" / "stock_publication_policy.json"
BUNDLED_STOCK_RUNTIME_ASSET_PATH = (
    RUNTIME_DIR.parents[1]
    / "frontend"
    / "flutter"
    / "assets"
    / "data"
    / "valley_stock_runtime_ptbr.json"
)

TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=pt-BR&dt=t"
MYMEMORY_TRANSLATE_URL = "https://api.mymemory.translated.net/get"
TRANSLATE_TIMEOUT_SECONDS = 45
TRANSLATE_BATCH_LIMIT = 24
TRANSLATE_BATCH_CHARS = 6500
TRANSLATE_DELIMITER = "\n[[[VALLEY_PTBR_SPLIT]]]\n"

STRING_FIELDS = (
    "title",
    "description",
    "model_name",
    "availability_label",
    "google_product_category",
    "google_product_category_path",
)
LIST_FIELDS = (
    "tags",
)
PROVIDER_KEYS_REQUIRING_TRANSLATION = {
    "aliexpress",
    "alibaba",
    "amazon",
    "cjdropshipping",
    "shopee",
}

ENGLISH_HINT_PATTERN = re.compile(
    r"\b("
    r"wireless|bluetooth|headset|headphone|headphones|earbud|earbuds|earphone|earphones|"
    r"speaker|portable|waterproof|sports|gaming|smart|watch|charger|cable|mouse|keyboard|"
    r"fashion|women|woman|men|man|kids|baby|kitchen|home|car|case|bag|shoe|dress|shirt|"
    r"bass|extendable|luminous|on-ear|overview"
    r")\b",
    re.IGNORECASE,
)
PORTUGUESE_HINT_PATTERN = re.compile(
    r"\b("
    r"com|sem|para|fones|fone|ouvido|sem fio|estoque|curadoria|sincronizado|"
    r"categoria|produto|casa|cozinha|carregador"
    r")\b",
    re.IGNORECASE,
)
INVALID_TARGET_PREFIXES = (
    "'AUTO' IS AN INVALID SOURCE LANGUAGE",
)
GLOSSARY_SEGMENTS = {
    "Electronics": "Eletrônicos",
    "Audio": "Áudio",
    "Audio Components": "Componentes de áudio",
    "Headphones & Headsets": "Fones de ouvido e headsets",
    "Headphones": "Fones de ouvido",
    "Hardware": "Hardware",
    "Power & Electrical Supplies": "Energia e suprimentos elétricos",
    "Home Automation Kits": "Kits de automação residencial",
    "Communications": "Comunicações",
    "Telephony": "Telefonia",
    "Mobile Phones": "Celulares",
    "Apparel & Accessories": "Vestuário e acessórios",
    "Jewelry": "Joias",
    "Watches": "Relógios",
}
GLOSSARY_REPLACEMENTS = (
    ("home security", "segurança residencial"),
    ("smart home", "casa inteligente"),
    ("night vision", "visão noturna"),
    ("wireless bluetooth headphones", "fones de ouvido Bluetooth sem fio"),
    ("wireless headphones", "fones de ouvido sem fio"),
    ("wireless headset", "headset sem fio"),
    ("wireless earbuds", "fones intra-auriculares sem fio"),
    ("earphones & headphones", "fones de ouvido"),
    ("earphones", "fones de ouvido"),
    ("earbuds", "fones intra-auriculares"),
    ("headphones", "fones de ouvido"),
    ("headset", "headset"),
    ("smart watch", "relógio inteligente"),
    ("smartwatch", "relógio inteligente"),
    ("wireless charger", "carregador sem fio"),
    ("charger", "carregador"),
    ("mobile phone", "celular"),
    ("phone watch", "relógio com telefone"),
    ("smart phone", "smartphone"),
    ("security camera", "câmera de segurança"),
    ("surveillance camera", "câmera de vigilância"),
    ("camera", "câmera"),
    ("waterproof", "à prova d'água"),
    ("sports", "esportivo"),
    ("sport", "esporte"),
    ("portable", "portátil"),
    ("outdoor", "externa"),
    ("indoor", "interna"),
    ("children", "infantil"),
    ("kids", "infantil"),
    ("women", "feminino"),
    ("men", "masculino"),
    ("heart rate", "frequência cardíaca"),
    ("blood pressure", "pressão arterial"),
    ("sleep monitoring", "monitoramento do sono"),
    ("remote control", "controle remoto"),
    ("wireless", "sem fio"),
    ("security", "segurança"),
    ("monitor", "monitoramento"),
    ("watch band", "pulseira do relógio"),
    ("watch", "relógio"),
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


def sha1_text(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def should_translate_text(value: str) -> bool:
    text = str(value or "").strip()
    if not text:
        return False
    if text.startswith("http://") or text.startswith("https://"):
        return False
    return any(character.isalpha() for character in text)


def item_requires_translation(item: dict[str, Any]) -> bool:
    provider_key = str(item.get("provider_key") or "").strip().lower()
    return provider_key in PROVIDER_KEYS_REQUIRING_TRANSLATION


def load_cache() -> dict[str, dict[str, Any]]:
    payload = load_json(TRANSLATION_CACHE_PATH, {})
    entries = payload.get("entries") if isinstance(payload, dict) else None
    if not isinstance(entries, dict):
        return {}
    normalized: dict[str, dict[str, Any]] = {}
    for key, entry in entries.items():
        if not isinstance(entry, dict):
            continue
        source = str(entry.get("source") or "")
        target = str(entry.get("target") or "")
        if (
            source
            and target
            and not is_invalid_cached_target(target)
            and not should_retry_same_source_translation(source, target)
        ):
            normalized[str(key)] = {
                "source": source,
                "target": target,
                "updated_at_utc": str(entry.get("updated_at_utc") or ""),
            }
    return normalized


def persist_cache(cache_entries: dict[str, dict[str, Any]]) -> None:
    write_json(
        TRANSLATION_CACHE_PATH,
        {
            "status": "ok",
            "locale": "pt-BR",
            "updated_at_utc": utc_now_iso(),
            "entries_total": len(cache_entries),
            "entries": cache_entries,
        },
    )


def should_retry_same_source_translation(source: str, target: str) -> bool:
    normalized_source = str(source or "").strip()
    normalized_target = str(target or "").strip()
    if not normalized_source or normalized_source != normalized_target:
        return False
    if not should_translate_text(normalized_source):
        return False
    if ENGLISH_HINT_PATTERN.search(normalized_source):
        return True
    if PORTUGUESE_HINT_PATTERN.search(normalized_source):
        return False
    ascii_words = re.findall(r"[A-Za-z]{4,}", normalized_source)
    return len(ascii_words) >= 3 and len(normalized_source) >= 18


def is_invalid_cached_target(target: str) -> bool:
    normalized_target = str(target or "").strip()
    return any(normalized_target.startswith(prefix) for prefix in INVALID_TARGET_PREFIXES)


def translate_blob(blob: str) -> str:
    body = urllib.parse.urlencode({"q": blob}).encode("utf-8")
    request = Request(
        TRANSLATE_URL,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "User-Agent": "Mozilla/5.0",
        },
    )
    with urlopen(request, timeout=TRANSLATE_TIMEOUT_SECONDS) as response:
        payload = json.loads(response.read().decode("utf-8"))
    segments = payload[0] if isinstance(payload, list) and payload else []
    translated = []
    if isinstance(segments, list):
        for segment in segments:
            if isinstance(segment, list) and segment:
                translated.append(str(segment[0] or ""))
    return "".join(translated)


def translate_batch(texts: list[str]) -> list[str]:
    blob = TRANSLATE_DELIMITER.join(texts)
    translated_blob = translate_blob(blob)
    parts = translated_blob.split(TRANSLATE_DELIMITER)
    if len(parts) == len(texts):
        return [part.strip() for part in parts]
    return [translate_blob(text).strip() for text in texts]


def translate_blob_mymemory(text: str) -> str:
    query = urllib.parse.urlencode({"q": text, "langpair": "en|pt-BR"})
    request = Request(
        f"{MYMEMORY_TRANSLATE_URL}?{query}",
        headers={"User-Agent": "Mozilla/5.0"},
        method="GET",
    )
    with urlopen(request, timeout=TRANSLATE_TIMEOUT_SECONDS) as response:
        payload = json.loads(response.read().decode("utf-8"))
    response_data = payload.get("responseData") if isinstance(payload, dict) else None
    translated = (
        str((response_data or {}).get("translatedText") or "").strip()
        if isinstance(response_data, dict)
        else ""
    )
    if not translated:
        raise ValueError("MyMemory nao retornou translatedText.")
    return translated


def translate_single_with_fallback(text: str) -> str:
    attempts = 0
    while attempts < 3:
        attempts += 1
        try:
            return translate_blob_mymemory(text).strip()
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, ValueError):
            time.sleep(min(0.8 * attempts, 2.4))
    return translate_with_glossary(text)


def translate_with_glossary(text: str) -> str:
    source = str(text or "").strip()
    if not source:
        return ""

    translated = source
    if ">" in translated:
        segments = [segment.strip() for segment in translated.split(">")]
        translated_segments = [
            GLOSSARY_SEGMENTS.get(segment, segment)
            for segment in segments
            if segment
        ]
        translated = " > ".join(translated_segments)

    for source_term, target_term in GLOSSARY_REPLACEMENTS:
        translated = re.sub(
            rf"\b{re.escape(source_term)}\b",
            target_term,
            translated,
            flags=re.IGNORECASE,
        )

    translated = re.sub(r"\s+", " ", translated).strip()
    return translated if translated != source else ""


def batched(texts: list[str]) -> list[list[str]]:
    batches: list[list[str]] = []
    current: list[str] = []
    current_chars = 0
    delimiter_chars = len(TRANSLATE_DELIMITER)
    for text in texts:
        candidate_chars = current_chars + len(text) + (delimiter_chars if current else 0)
        if current and (
            len(current) >= TRANSLATE_BATCH_LIMIT or candidate_chars >= TRANSLATE_BATCH_CHARS
        ):
            batches.append(current)
            current = []
            current_chars = 0
        current.append(text)
        current_chars += len(text) + (delimiter_chars if len(current) > 1 else 0)
    if current:
        batches.append(current)
    return batches


def ensure_translations(
    unique_texts: list[str],
    cache_entries: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    missing = []
    for text in unique_texts:
        cache_key = sha1_text(text)
        entry = cache_entries.get(cache_key)
        if not entry or entry.get("source") != text or not entry.get("target"):
            missing.append(text)

    translated_now = 0
    failed = 0
    batches = batched(missing)
    for batch in batches:
        attempts = 0
        while True:
            attempts += 1
            try:
                translated_batch = translate_batch(batch)
                now = utc_now_iso()
                for source, target in zip(batch, translated_batch, strict=True):
                    cache_entries[sha1_text(source)] = {
                        "source": source,
                        "target": target or source,
                        "updated_at_utc": now,
                    }
                    translated_now += 1
                persist_cache(cache_entries)
                time.sleep(0.2)
                break
            except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as error:
                if attempts >= 2:
                    sys.stderr.write(f"[translate-stock] batch failed after retries: {error}\n")
                    for source in batch:
                        translated = translate_single_with_fallback(source)
                        if translated:
                            cache_entries[sha1_text(source)] = {
                                "source": source,
                                "target": translated,
                                "updated_at_utc": utc_now_iso(),
                            }
                            translated_now += 1
                        else:
                            failed += 1
                            sys.stderr.write(
                                f"[translate-stock] single fallback failed: {source[:120]}\n"
                            )
                    persist_cache(cache_entries)
                    break
                time.sleep(min(2**attempts, 4))

    return {
        "missing_total": len(missing),
        "translated_now": translated_now,
        "failed_total": failed,
        "batch_total": len(batches),
    }


def collect_unique_texts(runtime_payload: dict[str, Any]) -> list[str]:
    seen: set[str] = set()
    unique: list[str] = []
    items = runtime_payload.get("items")
    if not isinstance(items, list):
        return unique

    for item in items:
        if not isinstance(item, dict) or item.get("module_id") != "STOCK":
            continue
        if not item_requires_translation(item):
            continue
        for field in STRING_FIELDS:
            value = item.get(field)
            if isinstance(value, str) and should_translate_text(value) and value not in seen:
                seen.add(value)
                unique.append(value)
        for field in LIST_FIELDS:
            values = item.get(field)
            if not isinstance(values, list):
                continue
            for value in values:
                if isinstance(value, str) and should_translate_text(value) and value not in seen:
                    seen.add(value)
                    unique.append(value)
    return unique


def translated_value(value: str, cache_entries: dict[str, dict[str, Any]]) -> str:
    if not should_translate_text(value):
        return value
    entry = cache_entries.get(sha1_text(value))
    if entry and entry.get("source") == value:
        target = str(entry.get("target") or "").strip()
        if target and not is_invalid_cached_target(target):
            return target
    glossary_target = translate_with_glossary(value)
    return glossary_target or value


def build_translated_runtime(
    runtime_payload: dict[str, Any],
    cache_entries: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    translated = dict(runtime_payload)
    items = runtime_payload.get("items")
    translated_items: list[dict[str, Any]] = []
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict) or item.get("module_id") != "STOCK":
            if isinstance(item, dict):
                translated_items.append(dict(item))
            continue
        translated_item = dict(item)
        if not item_requires_translation(item):
            translated_items.append(translated_item)
            continue
        for field in STRING_FIELDS:
            value = translated_item.get(field)
            if isinstance(value, str):
                translated_item[field] = translated_value(value, cache_entries)
        for field in LIST_FIELDS:
            values = translated_item.get(field)
            if isinstance(values, list):
                translated_item[field] = [
                    translated_value(value, cache_entries) if isinstance(value, str) else value
                    for value in values
                ]
        translated_items.append(translated_item)

    translated["items"] = translated_items
    translated["translation_locale"] = "pt-BR"
    translated["translation_engine"] = "google-translate-public"
    translated["translation_generated_at_utc"] = utc_now_iso()
    return translated


def update_public_preview(translated_runtime: dict[str, Any]) -> None:
    catalog = load_json(CATALOG_PATH, {})
    if not isinstance(catalog, dict):
        return
    existing_items = catalog.get("items") if isinstance(catalog.get("items"), list) else []
    non_stock_items = [
        item
        for item in existing_items
        if isinstance(item, dict) and str(item.get("module_id") or "") != "STOCK"
    ]
    stock_items = [
        item
        for item in translated_runtime.get("items", [])
        if isinstance(item, dict) and item.get("module_id") == "STOCK"
    ]
    pricing_runtime = load_json(PRICING_RUNTIME_PATH, {})
    pricing_items = pricing_runtime.get("items") if isinstance(pricing_runtime, dict) else None
    pricing_index = {}
    if isinstance(pricing_items, list):
        pricing_index = {
            str(item.get("id") or ""): item
            for item in pricing_items
            if isinstance(item, dict)
        }
    publication_policy = load_json(STOCK_PUBLICATION_POLICY_PATH, {})
    publication_policy = publication_policy if isinstance(publication_policy, dict) else {}
    auto_approve_imported_catalog = bool(publication_policy.get("auto_approve_imported_catalog"))
    auto_approval_reason_code = str(
        publication_policy.get("reason_code") or "auto_approved_mvp_total_delivery"
    )
    auto_approval_reason_label = str(
        publication_policy.get("reason_label")
        or "Catalogo importado aprovado automaticamente nesta instancia MVP."
    )
    curated_stock_items = []
    for item in stock_items:
        pricing_row = pricing_index.get(str(item.get("id") or ""))
        publication_status = str((pricing_row or {}).get("publication_status") or "").strip().lower()
        if publication_status == "do_not_publish" and not auto_approve_imported_catalog:
            continue
        merged = dict(item)
        if auto_approve_imported_catalog:
            merged["publication_status"] = "approved"
            merged["publication_status_label"] = str(
                publication_policy.get("publication_status_label")
                or "Aprovado automaticamente"
            )
            merged["publication_reason_codes"] = [auto_approval_reason_code]
            merged["publication_reasons"] = [auto_approval_reason_label]
        elif pricing_row:
            merged["publication_status"] = publication_status
            merged["estimated_net_revenue_brl"] = pricing_row.get("estimated_net_revenue_brl")
            merged["liquidity_score"] = pricing_row.get("liquidity_score")
        curated_stock_items.append(merged)
    if curated_stock_items:
        stock_items = curated_stock_items
    stock_items.sort(
        key=lambda item: (
            0 if str(item.get("publication_status") or "") == "approved" else 1,
            -float(item.get("estimated_net_revenue_brl") or 0.0),
            -float(item.get("liquidity_score") or 0.0),
            str(item.get("title") or ""),
        )
    )
    preview_items = round_robin_preview(
        [sanitize_public_stock_item(item) for item in stock_items],
        PREVIEW_LIMIT,
    )
    catalog["items"] = preview_items + non_stock_items
    summary = catalog.get("summary") if isinstance(catalog.get("summary"), dict) else {}
    summary["products"] = len(stock_items) + len(non_stock_items)
    catalog["summary"] = summary
    catalog["generated_at_utc"] = utc_now_iso()
    bundled_runtime = dict(translated_runtime)
    bundled_runtime["items"] = [
        sanitize_public_stock_item(item)
        if isinstance(item, dict) and item.get("module_id") == "STOCK"
        else item
        for item in translated_runtime.get("items", [])
        if isinstance(item, dict)
    ]
    write_json(CATALOG_PATH, catalog)
    write_json(BUNDLED_STOCK_RUNTIME_ASSET_PATH, bundled_runtime)


def main() -> None:
    rebuild_only = "--rebuild-only" in sys.argv[1:]
    runtime_payload = load_json(FULL_STOCK_PATH, {})
    if not isinstance(runtime_payload, dict):
        print(
            json.dumps(
                {
                    "status": "missing",
                    "detail": "Runtime STOCK inexistente.",
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return

    cache_entries = load_cache()
    unique_texts = collect_unique_texts(runtime_payload)
    if rebuild_only:
        translation_stats = {
            "missing_total": 0,
            "translated_now": 0,
            "failed_total": 0,
            "batch_total": 0,
            "rebuild_only": True,
        }
    else:
        translation_stats = ensure_translations(unique_texts, cache_entries)
        persist_cache(cache_entries)

    translated_runtime = build_translated_runtime(runtime_payload, cache_entries)
    write_json(TRANSLATED_STOCK_PATH, translated_runtime)
    update_public_preview(translated_runtime)

    status_payload = {
        "status": "ok",
        "locale": "pt-BR",
        "source_items_total": int(runtime_payload.get("items_total") or 0),
        "translated_items_total": len(
            [
                item
                for item in translated_runtime.get("items", [])
                if isinstance(item, dict) and item.get("module_id") == "STOCK"
            ]
        ),
        "unique_texts_total": len(unique_texts),
        "cache_entries_total": len(cache_entries),
        "translation": translation_stats,
        "generated_at_utc": utc_now_iso(),
    }
    write_json(TRANSLATION_STATUS_PATH, status_payload)
    print(json.dumps(status_payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
