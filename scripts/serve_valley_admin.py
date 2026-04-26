#!/usr/bin/env python3
"""Servidor HTTP endurecido para o painel admin do Valley."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "admin"
DEFAULT_DATA_PATH = DEFAULT_ROOT / "valley_admin_data.json"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
BRIDGE_STATUS_PATH = RUNTIME_DIR / "codex-live-status.json"
WORK_STATUS_PATH = RUNTIME_DIR / "bridge-work-status.json"
PUBLIC_RUNTIME_PATH = RUNTIME_DIR / "valley-admin-public-runtime.json"
PRODUCT_PUBLIC_RUNTIME_PATH = RUNTIME_DIR / "valley-product-public-runtime.json"
PRODUCT_PUBLICATION_PATH = RUNTIME_DIR / "valley-product-web-publication.json"
PRODUCT_CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
PRODUCT_INTERACTIONS_PATH = RUNTIME_DIR / "valley-product-interactions.jsonl"
PRODUCT_MVP_MODULES = {"STOCK", "MARKETPLACE", "CHAT"}
PRODUCT_LIST_LIMIT = 80


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_json_file(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.exists():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def write_json_file(path: Path | None, payload: dict[str, Any]) -> None:
    if path is None:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


class ExclusiveThreadingHTTPServer(ThreadingHTTPServer):
    """Impede bind reaproveitado para nao disputar porta com outro processo."""

    allow_reuse_address = False


class ValleyAdminHandler(SimpleHTTPRequestHandler):
    """Expande o SimpleHTTPRequestHandler com endpoints operacionais."""

    server_version = "ValleyAdminHTTP/1.1"

    def __init__(
        self,
        *args,
        directory: str | None = None,
        project_root: Path | None = None,
        data_path: Path | None = None,
        startup_file: Path | None = None,
        started_at_utc: str | None = None,
        **kwargs,
    ) -> None:
        self.project_root = project_root or ROOT
        self.data_path = data_path or DEFAULT_DATA_PATH
        self.startup_file = startup_file
        self.started_at_utc = started_at_utc or utc_now_iso()
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        route = parsed.path

        if route in ("/health", "/healthz", "/readyz", "/meta/runtime", "/api/runtime"):
            self._write_json(HTTPStatus.OK, self._runtime_payload())
            return

        if route == "/api/product-shell":
            self._write_json(HTTPStatus.OK, self._product_shell_payload())
            return

        if route == "/api/product-catalog-summary":
            self._write_json(HTTPStatus.OK, self._product_catalog_summary_payload())
            return

        if route == "/api/bridge/status":
            self._write_json(HTTPStatus.OK, self._bridge_status_payload())
            return

        if route == "/api/work-status":
            self._write_json(HTTPStatus.OK, self._work_status_payload())
            return

        if route in ("/api/admin-data", "/api/admin-data.json"):
            if not self.data_path.exists():
                self._write_json(
                    HTTPStatus.NOT_FOUND,
                    {
                        "status": "missing_data",
                        "service": "valley-admin",
                        "data_file": str(self.data_path),
                    },
                )
                return

            body = self.data_path.read_bytes()
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        route = parsed.path
        query = parse_qs(parsed.query)

        if route == "/api/actions/pulse-telegram":
            self._write_json(
                HTTPStatus.OK,
                self._run_bridge_command("pulse", action="pulse-telegram"),
            )
            return

        if route == "/api/actions/poll-bridge":
            self._write_json(
                HTTPStatus.OK,
                self._run_bridge_command("poll-once", action="poll-bridge"),
            )
            return

        if route == "/api/actions/whatsapp-status":
            self._write_json(
                HTTPStatus.OK,
                self._run_bridge_command("whatsapp-status", action="whatsapp-status"),
            )
            return

        if route == "/api/actions/product-interest":
            self._write_json(
                HTTPStatus.OK,
                self._product_interest_payload(query),
            )
            return

        if route == "/api/actions/open-media":
            self._write_json(
                HTTPStatus.OK,
                self._open_media_payload(query),
            )
            return

        self._write_json(
            HTTPStatus.NOT_FOUND,
            {"status": "not_found", "route": route, "service": "valley-admin"},
        )

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        message = format % args
        print(f"[valley-admin] {self.address_string()} {message}")

    def _runtime_payload(self) -> dict[str, Any]:
        root_path = Path(self.directory or DEFAULT_ROOT).resolve()
        startup_manifest = load_json_file(self.startup_file)
        return {
            "status": "ok",
            "service": "valley-admin",
            "pid": os.getpid(),
            "started_at_utc": self.started_at_utc,
            "project_root": str(self.project_root),
            "root": str(root_path),
            "root_exists": root_path.exists(),
            "data_file": str(self.data_path),
            "data_exists": self.data_path.exists(),
            "startup_file": str(self.startup_file) if self.startup_file else None,
            "startup_file_exists": bool(self.startup_file and self.startup_file.exists()),
            "startup_manifest": startup_manifest,
        }

    def _bridge_status_payload(self) -> dict[str, Any]:
        return load_json_file(BRIDGE_STATUS_PATH) or {
            "status": "missing",
            "service": "valley-bridge",
        }

    def _work_status_payload(self) -> dict[str, Any]:
        return load_json_file(WORK_STATUS_PATH) or {
            "activity_name": "Valley",
            "progress_percent": 0,
            "status": "missing",
        }

    def _public_runtime_payload(self) -> dict[str, Any]:
        return load_json_file(PUBLIC_RUNTIME_PATH) or {}

    def _product_public_runtime_payload(self) -> dict[str, Any]:
        publication = load_json_file(PRODUCT_PUBLICATION_PATH) or {}
        runtime = load_json_file(PRODUCT_PUBLIC_RUNTIME_PATH) or {}

        if publication:
            payload = dict(runtime)
            payload.update(
                {
                    "status": publication.get("status", payload.get("status", "ok")),
                    "service": payload.get("service", "valley-product-public"),
                    "provider": publication.get("provider", payload.get("provider")),
                    "public_url": publication.get("public_url", payload.get("public_url")),
                    "public_api_url": publication.get("api_url", payload.get("public_api_url")),
                    "temporary": publication.get("temporary", payload.get("temporary")),
                    "provider_status": publication.get(
                        "provider_status",
                        payload.get("provider_status"),
                    ),
                    "generated_at": publication.get("generated_at", payload.get("generated_at")),
                }
            )
            return payload

        if runtime:
            return runtime

        return self._public_runtime_payload()

    def _product_shell_payload(self) -> dict[str, Any]:
        catalog = load_json_file(PRODUCT_CATALOG_PATH) or {}
        hero = (catalog.get("hero") or {}) if isinstance(catalog, dict) else {}
        payload = {
            "status": "ok",
            "service": "valley-product",
            "generated_at_utc": utc_now_iso(),
            "title": hero.get("title", "Valley"),
            "subtitle": hero.get(
                "subtitle",
                "Compra, explore e acesse seus modulos em uma unica experiencia.",
            ),
            "public_runtime": self._product_public_runtime_payload(),
        }
        if isinstance(catalog, dict):
            payload.update(catalog)
            payload["public_runtime"] = self._product_public_runtime_payload()
            payload["status"] = "ok"
            payload["service"] = "valley-product"
            payload = self._compact_product_shell_payload(payload)
        return payload

    def _compact_product_shell_payload(self, payload: dict[str, Any]) -> dict[str, Any]:
        """Mantem a API leve e alinhada ao MVP para mobile e tunel remoto."""
        active_modules = PRODUCT_MVP_MODULES
        compact = dict(payload)

        modules = compact.get("modules", [])
        if isinstance(modules, list):
            compact["modules"] = [
                module
                for module in modules
                if isinstance(module, dict) and module.get("id") in active_modules
            ]

        module_screens = compact.get("module_screens", [])
        if isinstance(module_screens, list):
            compact["module_screens"] = [
                screen
                for screen in module_screens
                if isinstance(screen, dict) and screen.get("module_id") in active_modules
            ]

        items = compact.get("items", [])
        used_profile_ids: set[str] = set()
        if isinstance(items, list):
            filtered_items = [
                item
                for item in items
                if isinstance(item, dict) and item.get("module_id") in active_modules
            ][:PRODUCT_LIST_LIMIT]
            compact["items"] = filtered_items
            used_profile_ids = {
                str(item.get("profile_id"))
                for item in filtered_items
                if item.get("profile_id")
            }

        profiles = compact.get("profiles", [])
        if isinstance(profiles, list):
            compact["profiles"] = [
                profile
                for profile in profiles
                if isinstance(profile, dict)
                and (
                    not used_profile_ids
                    or str(profile.get("id")) in used_profile_ids
                    or str(profile.get("user_id")) in used_profile_ids
                )
            ][:PRODUCT_LIST_LIMIT]

        for key in ("feed_entries", "conversations", "statement_entries"):
            entries = compact.get(key, [])
            if isinstance(entries, list):
                compact[key] = entries[:40]

        return compact

    def _product_catalog_summary_payload(self) -> dict[str, Any]:
        catalog = load_json_file(PRODUCT_CATALOG_PATH) or {}
        items = catalog.get("items", []) if isinstance(catalog, dict) else []

        if not isinstance(items, list) or not items:
            return {
                "status": "missing",
                "service": "valley-product-catalog-summary",
                "generated_at_utc": utc_now_iso(),
                "items_total": 0,
                "modules": [],
            }

        def as_float(value: Any) -> float:
            try:
                return float(value or 0)
            except (TypeError, ValueError):
                return 0.0

        totals = {
            "items_total": 0,
            "inventory_units": 0.0,
            "inventory_value_brl": 0.0,
            "compare_value_brl": 0.0,
            "margin_potential_brl": 0.0,
        }
        module_rollup: dict[str, dict[str, Any]] = {}
        category_rollup: dict[str, dict[str, float]] = defaultdict(lambda: {"items": 0.0, "value_brl": 0.0, "units": 0.0})
        merchant_rollup: dict[str, dict[str, float]] = defaultdict(lambda: {"items": 0.0, "value_brl": 0.0})
        top_stock_item: dict[str, Any] | None = None
        top_ticket_item: dict[str, Any] | None = None
        top_margin_item: dict[str, Any] | None = None
        top_inventory_value_item: dict[str, Any] | None = None

        for raw_item in items:
            if not isinstance(raw_item, dict):
                continue

            module_id = str(raw_item.get("module_id") or "UNKNOWN").upper()
            title = str(raw_item.get("title") or "Item sem titulo")
            category = str(raw_item.get("category") or "Sem categoria")
            merchant_name = str(raw_item.get("merchant_name") or "Origem nao informada")
            price_brl = as_float(raw_item.get("price_brl"))
            compare_at_brl = as_float(raw_item.get("compare_at_brl"))
            stock = as_float(raw_item.get("stock"))
            inventory_value = price_brl * stock
            unit_margin = max(compare_at_brl - price_brl, 0.0)
            total_margin = unit_margin * stock

            totals["items_total"] += 1
            totals["inventory_units"] += stock
            totals["inventory_value_brl"] += inventory_value
            totals["compare_value_brl"] += compare_at_brl * stock
            totals["margin_potential_brl"] += total_margin

            module_entry = module_rollup.setdefault(
                module_id,
                {
                    "module_id": module_id,
                    "items_total": 0,
                    "inventory_units": 0.0,
                    "inventory_value_brl": 0.0,
                    "avg_price_brl": 0.0,
                    "margin_potential_brl": 0.0,
                    "top_item_title": title,
                    "top_item_value_brl": inventory_value,
                },
            )
            module_entry["items_total"] += 1
            module_entry["inventory_units"] += stock
            module_entry["inventory_value_brl"] += inventory_value
            module_entry["avg_price_brl"] += price_brl
            module_entry["margin_potential_brl"] += total_margin
            if inventory_value >= float(module_entry.get("top_item_value_brl", 0.0)):
                module_entry["top_item_title"] = title
                module_entry["top_item_value_brl"] = inventory_value

            category_rollup[category]["items"] += 1
            category_rollup[category]["units"] += stock
            category_rollup[category]["value_brl"] += inventory_value
            merchant_rollup[merchant_name]["items"] += 1
            merchant_rollup[merchant_name]["value_brl"] += inventory_value

            item_view = {
                "id": raw_item.get("id"),
                "title": title,
                "module_id": module_id,
                "category": category,
                "merchant_name": merchant_name,
                "price_brl": round(price_brl, 2),
                "compare_at_brl": round(compare_at_brl, 2),
                "stock": round(stock, 2),
                "inventory_value_brl": round(inventory_value, 2),
                "unit_margin_brl": round(unit_margin, 2),
                "total_margin_brl": round(total_margin, 2),
            }
            if top_stock_item is None or stock >= float(top_stock_item["stock"]):
                top_stock_item = item_view
            if top_ticket_item is None or price_brl >= float(top_ticket_item["price_brl"]):
                top_ticket_item = item_view
            if top_margin_item is None or total_margin >= float(top_margin_item["total_margin_brl"]):
                top_margin_item = item_view
            if top_inventory_value_item is None or inventory_value >= float(top_inventory_value_item["inventory_value_brl"]):
                top_inventory_value_item = item_view

        modules = []
        for module_entry in module_rollup.values():
            items_total = int(module_entry["items_total"])
            avg_price = module_entry["avg_price_brl"] / items_total if items_total else 0.0
            modules.append(
                {
                    **module_entry,
                    "items_total": items_total,
                    "inventory_units": round(module_entry["inventory_units"], 2),
                    "inventory_value_brl": round(module_entry["inventory_value_brl"], 2),
                    "avg_price_brl": round(avg_price, 2),
                    "margin_potential_brl": round(module_entry["margin_potential_brl"], 2),
                    "top_item_value_brl": round(module_entry["top_item_value_brl"], 2),
                }
            )

        modules.sort(key=lambda item: (-float(item["inventory_value_brl"]), item["module_id"]))
        top_categories = [
            {
                "category": category,
                "items_total": int(values["items"]),
                "inventory_units": round(values["units"], 2),
                "inventory_value_brl": round(values["value_brl"], 2),
            }
            for category, values in sorted(category_rollup.items(), key=lambda item: (-item[1]["value_brl"], item[0]))[:8]
        ]
        top_merchants = [
            {
                "merchant_name": merchant_name,
                "items_total": int(values["items"]),
                "inventory_value_brl": round(values["value_brl"], 2),
            }
            for merchant_name, values in sorted(merchant_rollup.items(), key=lambda item: (-item[1]["value_brl"], item[0]))[:8]
        ]
        stock_summary = next((module for module in modules if module["module_id"] == "STOCK"), None)

        return {
            "status": "ok",
            "service": "valley-product-catalog-summary",
            "generated_at_utc": utc_now_iso(),
            "items_total": totals["items_total"],
            "inventory_units": round(totals["inventory_units"], 2),
            "inventory_value_brl": round(totals["inventory_value_brl"], 2),
            "compare_value_brl": round(totals["compare_value_brl"], 2),
            "margin_potential_brl": round(totals["margin_potential_brl"], 2),
            "modules": modules[:12],
            "top_categories": top_categories,
            "top_merchants": top_merchants,
            "top_stock_item": top_stock_item,
            "top_ticket_item": top_ticket_item,
            "top_margin_item": top_margin_item,
            "top_inventory_value_item": top_inventory_value_item,
            "stock_module": stock_summary,
        }

    def _product_interest_payload(self, query: dict[str, list[str]]) -> dict[str, Any]:
        item_id = (query.get("item_id") or [""])[0]
        catalog = load_json_file(PRODUCT_CATALOG_PATH) or {}
        items = catalog.get("items", []) if isinstance(catalog, dict) else []
        item = next(
            (candidate for candidate in items if candidate.get("id") == item_id),
            None,
        )
        if item is None:
            return {
                "status": "failed",
                "action": "product-interest",
                "payload": {"message": "Item indisponivel."},
            }

        event = {
            "event": "product_interest",
            "item_id": item_id,
            "title": item.get("title"),
            "created_at_utc": utc_now_iso(),
        }
        PRODUCT_INTERACTIONS_PATH.parent.mkdir(parents=True, exist_ok=True)
        with PRODUCT_INTERACTIONS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")

        return {
            "status": "ok",
            "action": "product-interest",
            "payload": {
                "message": f"{item.get('title', 'Item')} reservado no servidor.",
            },
        }

    def _open_media_payload(self, query: dict[str, list[str]]) -> dict[str, Any]:
        item_id = (query.get("item_id") or [""])[0]
        catalog = load_json_file(PRODUCT_CATALOG_PATH) or {}
        items = catalog.get("items", []) if isinstance(catalog, dict) else []
        item = next(
            (candidate for candidate in items if candidate.get("id") == item_id),
            None,
        )
        if item is None or not item.get("video_url"):
            return {
                "status": "failed",
                "action": "open-media",
                "payload": {"message": "Midia indisponivel."},
            }

        return {
            "status": "ok",
            "action": "open-media",
            "payload": {
                "message": "Abrindo demonstracao.",
                "url": item.get("video_url"),
            },
        }

    def _run_bridge_command(self, command: str, *, action: str) -> dict[str, Any]:
        script_path = ROOT / "scripts" / "valley_communication_bridge.py"
        try:
            result = subprocess.run(
                [sys.executable, str(script_path), command],
                cwd=ROOT,
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return {
                "status": "timeout",
                "action": action,
                "service": "valley-product",
            }

        payload: dict[str, Any] | None = None
        stdout = (result.stdout or "").strip()
        if stdout:
            try:
                payload = json.loads(stdout)
            except json.JSONDecodeError:
                payload = {"stdout": stdout}

        return {
            "status": "ok" if result.returncode == 0 else "failed",
            "action": action,
            "returncode": result.returncode,
            "payload": payload or {},
            "stderr": (result.stderr or "").strip(),
        }

    def _write_json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Servidor HTTP do painel admin Valley.")
    parser.add_argument("--host", default="127.0.0.1", help="Host de bind. Padrao: 127.0.0.1")
    parser.add_argument("--port", type=int, default=8080, help="Porta HTTP. Padrao: 8080")
    parser.add_argument("--root", default=str(DEFAULT_ROOT), help="Diretorio servido. Padrao: admin/")
    parser.add_argument(
        "--data",
        default=str(DEFAULT_DATA_PATH),
        help="Payload JSON servido em /api/admin-data. Padrao: admin/valley_admin_data.json",
    )
    parser.add_argument(
        "--startup-file",
        default="",
        help="Manifesto JSON opcional de runtime para automacao externa.",
    )
    return parser.parse_args()


def build_startup_payload(
    *,
    host: str,
    port: int,
    root: Path,
    data_path: Path,
    startup_file: Path | None,
    started_at_utc: str,
) -> dict[str, Any]:
    base_url = f"http://{host}:{port}"
    return {
        "status": "booting",
        "service": "valley-admin",
        "pid": os.getpid(),
        "started_at_utc": started_at_utc,
        "local": {
            "host": host,
            "port": port,
            "base_url": base_url,
            "health_url": f"{base_url}/healthz",
            "data_url": f"{base_url}/api/admin-data",
        },
        "paths": {
            "root": str(root),
            "data_file": str(data_path),
            "startup_file": str(startup_file) if startup_file else None,
        },
        "checks": {
            "root_exists": root.exists(),
            "data_exists": data_path.exists(),
        },
    }


def main() -> None:
    args = parse_args()
    root = Path(args.root).resolve()
    data_path = Path(args.data).resolve()
    startup_file = Path(args.startup_file).resolve() if args.startup_file else None
    started_at_utc = utc_now_iso()

    if not root.exists():
        raise SystemExit(f"Diretorio admin inexistente: {root}")

    handler = partial(
        ValleyAdminHandler,
        directory=str(root),
        project_root=ROOT,
        data_path=data_path,
        startup_file=startup_file,
        started_at_utc=started_at_utc,
    )

    try:
        server = ExclusiveThreadingHTTPServer((args.host, args.port), handler)
    except OSError as exc:
        raise SystemExit(
            f"Nao foi possivel abrir http://{args.host}:{args.port}: {exc}"
        ) from exc

    write_json_file(
        startup_file,
        build_startup_payload(
            host=args.host,
            port=args.port,
            root=root,
            data_path=data_path,
            startup_file=startup_file,
            started_at_utc=started_at_utc,
        ),
    )

    print(f"Servindo Valley Admin em http://{args.host}:{args.port}")
    print(f"Healthcheck: http://{args.host}:{args.port}/healthz")
    print(f"Payload JSON: http://{args.host}:{args.port}/api/admin-data")

    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        print("\nEncerrando Valley Admin.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
