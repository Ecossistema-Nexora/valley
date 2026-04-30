#!/usr/bin/env python3
"""Servidor HTTP endurecido para o painel admin do Valley."""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
import secrets
import subprocess
import sys
import threading
import time
from collections import defaultdict
from datetime import datetime, timezone
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "admin"
DEFAULT_DATA_PATH = DEFAULT_ROOT / "valley_admin_data.json"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
BRIDGE_STATUS_PATH = RUNTIME_DIR / "codex-live-status.json"
WORK_STATUS_PATH = RUNTIME_DIR / "bridge-work-status.json"
PUBLIC_RUNTIME_PATH = RUNTIME_DIR / "valley-admin-public-runtime.json"
PRODUCT_PUBLIC_RUNTIME_PATH = RUNTIME_DIR / "valley-product-public-runtime.json"
PRODUCT_PUBLICATION_PATH = RUNTIME_DIR / "valley-product-web-publication.json"
ADMIN_INTEGRATIONS_PATH = RUNTIME_DIR / "valley-admin-integrations.json"
MARKETPLACE_OAUTH_RUNTIME_PATH = RUNTIME_DIR / "valley-marketplace-oauth-runtime.json"
SHOPEE_OAUTH_RUNTIME_PATH = RUNTIME_DIR / "valley-shopee-oauth-runtime.json"
ALIEXPRESS_OAUTH_RUNTIME_PATH = RUNTIME_DIR / "valley-aliexpress-oauth-runtime.json"
MAGALU_OAUTH_RUNTIME_PATH = RUNTIME_DIR / "valley-magalu-oauth-runtime.json"
ALIBABA_OAUTH_RUNTIME_PATH = RUNTIME_DIR / "valley-alibaba-oauth-runtime.json"
PROVIDER_SECRETS_PATH = RUNTIME_DIR / "valley-provider-secrets.json"
STOCK_REAL_CATALOG_PATH = RUNTIME_DIR / "valley-stock-real-catalog.json"
TRANSLATED_STOCK_REAL_CATALOG_PATH = RUNTIME_DIR / "valley-stock-real-catalog-ptbr.json"
MERCADOPAGO_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-mercadopago-notifications.jsonl"
MERCADOPAGO_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-mercadopago-notification-latest.json"
MERCADOPAGO_PREFERENCES_PATH = RUNTIME_DIR / "valley-mercadopago-preferences.jsonl"
MERCADOLIVRE_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-mercadolivre-notifications.jsonl"
MERCADOLIVRE_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-mercadolivre-notification-latest.json"
MERCADOLIVRE_PKCE_PATH = RUNTIME_DIR / "valley-mercadolivre-pkce.json"
ALIEXPRESS_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-aliexpress-notifications.jsonl"
ALIEXPRESS_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-aliexpress-notification-latest.json"
CJDROPSHIPPING_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-cjdropshipping-notifications.jsonl"
CJDROPSHIPPING_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-cjdropshipping-notification-latest.json"
STOCK_SYNC_STATE_PATH = RUNTIME_DIR / "valley-stock-sync-state.json"
STOCK_SYNC_EVENTS_PATH = RUNTIME_DIR / "valley-stock-sync-events.jsonl"
PRODUCT_CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
PRODUCT_INTERACTIONS_PATH = RUNTIME_DIR / "valley-product-interactions.jsonl"
PRODUCT_MVP_MODULES = {"STOCK", "MARKETPLACE", "CHAT"}
PRODUCT_LIST_LIMIT = 80
STOCK_INTERNAL_FIELDS = {
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

CATALOG_SYNC_MANAGER: "CatalogSyncManager | None" = None


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_json_file(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.exists():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def write_json_file(path: Path | None, payload: Any) -> None:
    if path is None:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def base64url_sha256(value: str) -> str:
    digest = hashlib.sha256(value.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def hmac_sha256_upper(secret: str, message: str) -> str:
    return hmac.new(
        secret.encode("utf-8"),
        message.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest().upper()


def top_md5_upper(secret: str, params: dict[str, Any]) -> str:
    parts: list[str] = []
    for key in sorted(params):
        value = params[key]
        if value is None:
            continue
        parts.append(f"{key}{value}")
    payload = secret + "".join(parts) + secret
    return hashlib.md5(payload.encode("utf-8")).hexdigest().upper()


def update_marketplace_integration(provider_key: str, updates: dict[str, Any]) -> None:
    saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
    items = saved if isinstance(saved, list) else []
    changed = False
    for item in items:
        if isinstance(item, dict) and item.get("key") == provider_key:
            item.update(updates)
            changed = True
            break

    if changed:
        write_json_file(ADMIN_INTEGRATIONS_PATH, items)


def active_catalog_providers() -> list[dict[str, Any]]:
    saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
    items = saved if isinstance(saved, list) else []
    return [
        item
        for item in items
        if isinstance(item, dict) and item.get("enabled") and item.get("importCatalog")
    ]


class CatalogSyncManager:
    """Debounce e agenda a atualização real do catálogo STOCK."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._cond = threading.Condition(self._lock)
        self._next_run_at = 0.0
        self._queued = False
        self._queued_reason = ""
        self._pending_pids: set[str] = set()
        self._pending_vids: set[str] = set()
        self._force_full_sync = False
        self._running = False
        self._stopped = False
        self._thread = threading.Thread(
            target=self._worker_loop,
            name="valley-stock-sync-worker",
            daemon=True,
        )
        self._periodic_thread = threading.Thread(
            target=self._periodic_loop,
            name="valley-stock-sync-periodic",
            daemon=True,
        )
        self._thread.start()
        self._periodic_thread.start()
        self._write_state({"status": "idle", "started_at_utc": utc_now_iso()})

    def schedule(
        self,
        reason: str,
        *,
        delay_seconds: float = 20.0,
        pids: list[str] | None = None,
        vids: list[str] | None = None,
        force_full_sync: bool = False,
    ) -> dict[str, Any]:
        scheduled_for = time.time() + max(delay_seconds, 0.0)
        with self._cond:
            self._queued = True
            self._force_full_sync = self._force_full_sync or force_full_sync
            for pid in pids or []:
                if pid and pid.strip():
                    self._pending_pids.add(pid.strip())
            for vid in vids or []:
                if vid and vid.strip():
                    self._pending_vids.add(vid.strip())
            if not self._queued_reason:
                self._queued_reason = reason
            elif reason not in self._queued_reason:
                self._queued_reason = f"{self._queued_reason}; {reason}"
            if self._next_run_at <= 0 or scheduled_for < self._next_run_at:
                self._next_run_at = scheduled_for
            self._write_state_locked(
                {
                    "status": "queued",
                    "queued": True,
                    "queued_reason": self._queued_reason,
                    "pending_pids": sorted(self._pending_pids),
                    "pending_vids": sorted(self._pending_vids),
                    "force_full_sync": self._force_full_sync,
                    "scheduled_for_utc": datetime.fromtimestamp(self._next_run_at, tz=timezone.utc)
                    .isoformat()
                    .replace("+00:00", "Z"),
                }
            )
            self._append_event_locked(
                {
                    "event": "schedule",
                    "reason": reason,
                    "delay_seconds": delay_seconds,
                    "pids": sorted(self._pending_pids),
                    "vids": sorted(self._pending_vids),
                    "force_full_sync": self._force_full_sync,
                    "scheduled_for_utc": datetime.fromtimestamp(scheduled_for, tz=timezone.utc)
                    .isoformat()
                    .replace("+00:00", "Z"),
                }
            )
            self._cond.notify_all()
            return {
                "queued": True,
                "reason": self._queued_reason,
                "pending_pids": sorted(self._pending_pids),
                "pending_vids": sorted(self._pending_vids),
                "force_full_sync": self._force_full_sync,
                "scheduled_for_utc": datetime.fromtimestamp(self._next_run_at, tz=timezone.utc)
                .isoformat()
                .replace("+00:00", "Z"),
                "running": self._running,
            }

    def snapshot(self) -> dict[str, Any]:
        return load_json_file(STOCK_SYNC_STATE_PATH) or {
            "status": "idle",
            "generated_at_utc": utc_now_iso(),
        }

    def stop(self) -> None:
        with self._cond:
            self._stopped = True
            self._cond.notify_all()

    def _periodic_loop(self) -> None:
        while not self._stopped:
            time.sleep(60)
            if self._stopped:
                break
            providers = active_catalog_providers()
            if not providers:
                continue
            cadence_minutes = min(
                max(int(provider.get("syncCadenceMinutes") or 30), 5)
                for provider in providers
            )
            snapshot = self.snapshot()
            last_success = str(snapshot.get("last_success_at_utc") or "").strip()
            if last_success:
                try:
                    last_dt = datetime.fromisoformat(last_success.replace("Z", "+00:00"))
                except ValueError:
                    last_dt = None
            else:
                last_dt = None
            if last_dt is None:
                self.schedule("periodic-bootstrap", delay_seconds=10)
                continue
            elapsed = datetime.now(timezone.utc) - last_dt
            if elapsed.total_seconds() >= cadence_minutes * 60:
                self.schedule("periodic-cadence", delay_seconds=10)

    def _worker_loop(self) -> None:
        while True:
            with self._cond:
                while not self._stopped and not self._queued:
                    self._cond.wait(timeout=5)
                if self._stopped:
                    return
                while not self._stopped:
                    wait = self._next_run_at - time.time()
                    if wait <= 0:
                        break
                    self._cond.wait(timeout=min(wait, 5))
                    if self._stopped:
                        return
                reason = self._queued_reason or "scheduled"
                pids = sorted(self._pending_pids)
                vids = sorted(self._pending_vids)
                force_full_sync = self._force_full_sync
                self._queued = False
                self._queued_reason = ""
                self._next_run_at = 0.0
                self._pending_pids.clear()
                self._pending_vids.clear()
                self._force_full_sync = False
                self._running = True
                started_at = utc_now_iso()
                self._write_state_locked(
                    {
                        "status": "running",
                        "running": True,
                        "queued": False,
                        "current_reason": reason,
                        "pending_pids": pids,
                        "pending_vids": vids,
                        "force_full_sync": force_full_sync,
                        "last_started_at_utc": started_at,
                    }
                )
                self._append_event_locked(
                    {
                        "event": "start",
                        "reason": reason,
                        "pids": pids,
                        "vids": vids,
                        "force_full_sync": force_full_sync,
                        "started_at_utc": started_at,
                    }
                )

            result = self._run_import(reason, pids=pids, vids=vids, force_full_sync=force_full_sync)

            with self._cond:
                finished_at = utc_now_iso()
                self._running = False
                success = result.get("status") == "ok"
                state_update = {
                    "status": "idle" if success else "failed",
                    "running": False,
                    "last_finished_at_utc": finished_at,
                    "last_run_reason": reason,
                    "last_result": result,
                }
                if success:
                    state_update["last_success_at_utc"] = finished_at
                self._write_state_locked(state_update)
                self._append_event_locked(
                    {
                        "event": "finish",
                        "reason": reason,
                        "finished_at_utc": finished_at,
                        "result": result,
                    }
                )

    def _run_import(
        self,
        reason: str,
        *,
        pids: list[str],
        vids: list[str],
        force_full_sync: bool,
    ) -> dict[str, Any]:
        script_path = ROOT / "scripts" / "import_real_stock_catalog.py"
        command = [sys.executable, str(script_path)]
        mode = "full"
        if not force_full_sync and (pids or vids):
            script_path = ROOT / "scripts" / "refresh_cj_stock_runtime.py"
            command = [sys.executable, str(script_path)]
            for pid in pids:
                command.extend(["--pid", pid])
            for vid in vids:
                command.extend(["--vid", vid])
            mode = "incremental_cj"
        try:
            result = subprocess.run(
                command,
                cwd=ROOT,
                capture_output=True,
                text=True,
                timeout=1800,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return {
                "status": "timeout",
                "reason": reason,
            }

        stdout = (result.stdout or "").strip()
        payload: dict[str, Any] | None = None
        if stdout:
            lines = [line for line in stdout.splitlines() if line.strip()]
            for line_index in range(len(lines) - 1, -1, -1):
                candidate = "\n".join(lines[line_index:])
                try:
                    payload = json.loads(candidate)
                    break
                except json.JSONDecodeError:
                    continue
        response = {
            "status": "ok" if result.returncode == 0 else "failed",
            "reason": reason,
            "mode": mode,
            "returncode": result.returncode,
            "payload": payload or {},
            "stderr": (result.stderr or "").strip(),
        }
        if result.returncode == 0:
            translation_script = ROOT / "scripts" / "translate_stock_catalog_ptbr.py"
            try:
                translation = subprocess.run(
                    [sys.executable, str(translation_script)],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    timeout=1800,
                    check=False,
                )
                translation_payload: dict[str, Any] | None = None
                translation_stdout = (translation.stdout or "").strip()
                if translation_stdout:
                    lines = [line for line in translation_stdout.splitlines() if line.strip()]
                    for line_index in range(len(lines) - 1, -1, -1):
                        candidate = "\n".join(lines[line_index:])
                        try:
                            translation_payload = json.loads(candidate)
                            break
                        except json.JSONDecodeError:
                            continue
                response["translation"] = {
                    "status": "ok" if translation.returncode == 0 else "failed",
                    "returncode": translation.returncode,
                    "payload": translation_payload or {},
                    "stderr": (translation.stderr or "").strip(),
                }
            except subprocess.TimeoutExpired:
                response["translation"] = {
                    "status": "timeout",
                    "detail": "Traducao pt-BR do catalogo excedeu a janela de execucao do worker.",
                }
        return response

    def _write_state(self, updates: dict[str, Any]) -> None:
        with self._lock:
            self._write_state_locked(updates)

    def _write_state_locked(self, updates: dict[str, Any]) -> None:
        current = load_json_file(STOCK_SYNC_STATE_PATH) or {}
        if not isinstance(current, dict):
            current = {}
        current.update(updates)
        current["generated_at_utc"] = utc_now_iso()
        write_json_file(STOCK_SYNC_STATE_PATH, current)

    def _append_event_locked(self, payload: dict[str, Any]) -> None:
        STOCK_SYNC_EVENTS_PATH.parent.mkdir(parents=True, exist_ok=True)
        envelope = {
            "received_at_utc": utc_now_iso(),
            **payload,
        }
        with STOCK_SYNC_EVENTS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(envelope, ensure_ascii=False) + "\n")


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
        route = self._normalize_public_route(parsed.path)

        if route in ("/", "/index.html") and parsed.query:
            params = parse_qs(parsed.query)
            if params.get("code") or params.get("error") or params.get("error_description"):
                root_redirect = self._public_admin_base_url().rstrip("/")
                self._write_mercadolivre_callback(parsed.query, redirect_uri_override=root_redirect)
                return

        if route in ("/health", "/healthz", "/readyz", "/meta/runtime", "/api/runtime"):
            self._write_json(HTTPStatus.OK, self._runtime_payload())
            return

        if route == "/api/product-shell":
            self._write_json(HTTPStatus.OK, self._product_shell_payload())
            return

        if route == "/api/stock-catalog":
            self._write_json(HTTPStatus.OK, self._stock_catalog_payload())
            return

        if route == "/api/product-catalog-summary":
            self._write_json(HTTPStatus.OK, self._product_catalog_summary_payload())
            return

        if route == "/api/stock-sync-status":
            self._write_json(HTTPStatus.OK, self._stock_sync_status_payload())
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

        if route == "/api/admin-integrations":
            self._write_json(HTTPStatus.OK, self._admin_integrations_payload())
            return

        if route == "/integrations/mercadolivre/callback":
            self._write_mercadolivre_callback(parsed.query)
            return

        if route == "/integrations/shopee/callback":
            self._write_shopee_callback(parsed.query)
            return

        if route == "/integrations/aliexpress/callback":
            self._write_aliexpress_callback(parsed.query)
            return

        if route == "/integrations/alibaba/authorize":
            self._redirect_alibaba_authorize()
            return

        if route == "/integrations/alibaba/callback":
            self._write_alibaba_callback(parsed.query)
            return

        if route == "/integrations/magalu/authorize":
            self._redirect_magalu_authorize()
            return

        if route == "/integrations/magalu/callback":
            self._write_magalu_callback(parsed.query)
            return

        if route == "/integrations/mercadopago/return":
            self._write_mercadopago_return_page(parsed.query)
            return

        if route == "/integrations/mercadopago/notifications":
            self._write_mercadopago_notification_probe()
            return

        if route == "/integrations/aliexpress/notifications":
            self._write_aliexpress_notification_probe()
            return

        if route == "/integrations/cjdropshipping/notifications":
            self._write_cjdropshipping_notification_probe()
            return

        if route == "/integrations/mercadolivre/authorize":
            self._redirect_mercadolivre_authorize()
            return

        if route == "/integrations/mercadolivre/notifications":
            self._write_mercadolivre_notification_probe()
            return

        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        route = self._normalize_public_route(parsed.path)
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

        if route == "/api/actions/checkout":
            self._write_json(
                HTTPStatus.OK,
                self._checkout_payload(query),
            )
            return

        if route == "/api/admin-integrations":
            payload = self._read_json_body()
            if not isinstance(payload, list):
                self._write_json(
                    HTTPStatus.BAD_REQUEST,
                    {
                        "status": "invalid_payload",
                        "service": "valley-admin",
                        "detail": "Expected JSON array.",
                    },
                )
                return

            write_json_file(ADMIN_INTEGRATIONS_PATH, payload)
            self._write_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "valley-admin",
                    "saved_at_utc": utc_now_iso(),
                    "path": str(ADMIN_INTEGRATIONS_PATH),
                    "items": len(payload),
                },
            )
            return

        if route == "/integrations/mercadolivre/notifications":
            self._write_mercadolivre_notification_event()
            return

        if route == "/integrations/aliexpress/notifications":
            self._write_aliexpress_notification_event()
            return

        if route == "/integrations/cjdropshipping/notifications":
            self._write_cjdropshipping_notification_event()
            return

        if route == "/integrations/mercadopago/notifications":
            self._write_mercadopago_notification_event(parsed.query)
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

    def _normalize_public_route(self, route: str) -> str:
        if route.startswith("/product/api/"):
            return route.removeprefix("/product")
        return route

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

    def _sanitize_stock_item(self, item: dict[str, Any]) -> dict[str, Any]:
        sanitized = dict(item)
        for key in STOCK_INTERNAL_FIELDS:
            sanitized.pop(key, None)
        item_id = str(item.get("id") or "").strip()
        media_url = self._derive_media_url(item)
        checkout_url = self._derive_checkout_url(item)
        mercadopago_ready = self._mercadopago_checkout_ready(item)
        checkout_ready = mercadopago_ready or bool(checkout_url)
        if item_id:
            sanitized["media_path"] = (
                f"/api/actions/open-media?{urlencode({'item_id': item_id})}"
                if media_url
                else ""
            )
            sanitized["cta_path"] = (
                f"/api/actions/checkout?{urlencode({'item_id': item_id})}"
                if checkout_ready
                else f"/api/actions/product-interest?{urlencode({'item_id': item_id})}"
            )
            sanitized["cta_label"] = "Abrir pagamento" if checkout_ready else "Registrar interesse"
            sanitized["checkout_ready"] = checkout_ready
            sanitized["payment_provider"] = (
                "mercado_pago"
                if mercadopago_ready
                else ("mercado_livre" if checkout_url else "")
            )
        return sanitized

    def _preferred_stock_catalog_path(self) -> Path:
        if TRANSLATED_STOCK_REAL_CATALOG_PATH.exists():
            if (
                not STOCK_REAL_CATALOG_PATH.exists()
                or TRANSLATED_STOCK_REAL_CATALOG_PATH.stat().st_mtime
                >= STOCK_REAL_CATALOG_PATH.stat().st_mtime
            ):
                return TRANSLATED_STOCK_REAL_CATALOG_PATH
        return STOCK_REAL_CATALOG_PATH

    def _load_stock_runtime_catalog(self) -> dict[str, Any] | None:
        payload = load_json_file(self._preferred_stock_catalog_path())
        return payload if isinstance(payload, dict) else None

    def _find_catalog_item(self, item_id: str) -> dict[str, Any] | None:
        normalized_item_id = str(item_id or "").strip()
        if not normalized_item_id:
            return None

        runtime_payload = self._load_stock_runtime_catalog()
        runtime_items = runtime_payload.get("items", []) if isinstance(runtime_payload, dict) else []
        for candidate in runtime_items:
            if isinstance(candidate, dict) and str(candidate.get("id") or "").strip() == normalized_item_id:
                return candidate

        if self._preferred_stock_catalog_path() != STOCK_REAL_CATALOG_PATH:
            fallback_runtime = load_json_file(STOCK_REAL_CATALOG_PATH) or {}
            fallback_items = fallback_runtime.get("items", []) if isinstance(fallback_runtime, dict) else []
            for candidate in fallback_items:
                if isinstance(candidate, dict) and str(candidate.get("id") or "").strip() == normalized_item_id:
                    return candidate

        catalog = load_json_file(PRODUCT_CATALOG_PATH) or {}
        items = catalog.get("items", []) if isinstance(catalog, dict) else []
        for candidate in items:
            if isinstance(candidate, dict) and str(candidate.get("id") or "").strip() == normalized_item_id:
                return candidate
        return None

    def _first_string_value(self, value: Any) -> str:
        if isinstance(value, list):
            for candidate in value:
                normalized = str(candidate or "").strip()
                if normalized:
                    return normalized
            return ""

        text = str(value or "").strip()
        if not text:
            return ""
        if text.startswith("[") and text.endswith("]"):
            try:
                parsed = json.loads(text.replace("'", '"'))
            except json.JSONDecodeError:
                return text
            if isinstance(parsed, list):
                for candidate in parsed:
                    normalized = str(candidate or "").strip()
                    if normalized:
                        return normalized
        return text

    def _is_http_url(self, value: str) -> bool:
        normalized = str(value or "").strip().lower()
        return normalized.startswith("http://") or normalized.startswith("https://")

    def _derive_media_url(self, item: dict[str, Any]) -> str:
        video_url = self._first_string_value(item.get("video_url"))
        return video_url if self._is_http_url(video_url) else ""

    def _derive_checkout_url(self, item: dict[str, Any]) -> str:
        source_permalink = str(item.get("source_permalink") or "").strip()
        if self._is_http_url(source_permalink):
            return source_permalink

        provider_key = str(item.get("provider_key") or "").strip().lower()
        source_product_id = str(item.get("source_product_id") or "").strip()
        source_item_id = str(item.get("source_item_id") or "").strip()

        if provider_key == "mercado_livre":
            if source_product_id.startswith("MLB"):
                return f"https://www.mercadolivre.com.br/p/{source_product_id}"
            if source_item_id.startswith("MLB"):
                return f"https://lista.mercadolivre.com.br/{source_item_id}"
        return ""

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
            filtered_items = [
                self._sanitize_stock_item(item)
                if isinstance(item, dict) and item.get("module_id") == "STOCK"
                else item
                for item in filtered_items
            ]
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

    def _stock_catalog_payload(self) -> dict[str, Any]:
        runtime_catalog = self._load_stock_runtime_catalog()
        if not isinstance(runtime_catalog, dict):
            return {
                "status": "missing",
                "service": "valley-stock-catalog",
                "generated_at_utc": utc_now_iso(),
                "items_total": 0,
                "categories_total": 0,
                "items": [],
            }

        items = runtime_catalog.get("items", [])
        sanitized_items = [
            self._sanitize_stock_item(item)
            for item in items
            if isinstance(item, dict) and item.get("module_id") == "STOCK"
        ]

        return {
            "status": "ok",
            "service": "valley-stock-catalog",
            "generated_at_utc": utc_now_iso(),
            "provider": runtime_catalog.get("provider", "runtime"),
            "locale": runtime_catalog.get("translation_locale") or "source",
            "items_total": len(sanitized_items),
            "categories_total": runtime_catalog.get("categories_total", 0),
            "items": sanitized_items,
        }

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

    def _admin_integrations_payload(self) -> dict[str, Any]:
        saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        items = saved if isinstance(saved, list) else []
        return {
            "status": "ok",
            "service": "valley-admin",
            "generated_at_utc": utc_now_iso(),
            "path": str(ADMIN_INTEGRATIONS_PATH),
            "items": items,
        }

    def _stock_sync_status_payload(self) -> dict[str, Any]:
        manager = CATALOG_SYNC_MANAGER
        snapshot = manager.snapshot() if manager is not None else (load_json_file(STOCK_SYNC_STATE_PATH) or {})
        payload = snapshot if isinstance(snapshot, dict) else {}
        payload.setdefault("status", "idle")
        payload.setdefault("service", "valley-stock-sync")
        payload.setdefault("generated_at_utc", utc_now_iso())
        return payload

    def _public_admin_base_url(self) -> str:
        runtime = load_json_file(PUBLIC_RUNTIME_PATH) or {}
        public_url = str(runtime.get("public_url") or "").strip()
        if public_url:
            return public_url.rstrip("/")
        return "https://admin.brasildesconto.com.br"

    def _provider_secrets_payload(self) -> dict[str, Any]:
        payload = load_json_file(PROVIDER_SECRETS_PATH) or {}
        return payload if isinstance(payload, dict) else {}

    def _mercadopago_secret_value(self, *candidates: str) -> str:
        for env_key in candidates:
            env_value = str(os.environ.get(env_key) or "").strip()
            if env_value:
                return env_value

        provider_secrets = self._provider_secrets_payload().get("mercado_pago")
        if not isinstance(provider_secrets, dict):
            return ""

        for candidate in candidates:
            normalized_keys = {
                candidate,
                candidate.lower(),
                candidate.replace("VALLEY_", "").lower(),
                candidate.replace("VALLEY_", "").replace("MERCADOPAGO_", "").lower(),
            }
            for key in normalized_keys:
                value = str(provider_secrets.get(key) or "").strip()
                if value:
                    return value

        return ""

    def _mercadopago_access_token(self) -> str:
        return self._mercadopago_secret_value(
            "VALLEY_MERCADOPAGO_ACCESS_TOKEN",
            "MERCADOPAGO_ACCESS_TOKEN",
            "MP_ACCESS_TOKEN",
            "accessToken",
            "access_token",
        )

    def _mercadopago_public_key(self) -> str:
        return self._mercadopago_secret_value(
            "VALLEY_MERCADOPAGO_PUBLIC_KEY",
            "MERCADOPAGO_PUBLIC_KEY",
            "MP_PUBLIC_KEY",
            "publicKey",
            "public_key",
        )

    def _mercadopago_notification_url(self) -> str:
        return (
            f"{self._public_admin_base_url()}/integrations/mercadopago/notifications"
            "?source_news=webhooks"
        )

    def _mercadopago_return_url(self, status: str, item_id: str) -> str:
        query = urlencode({"status": status, "item_id": item_id})
        return f"{self._public_admin_base_url()}/integrations/mercadopago/return?{query}"

    def _trim_checkout_text(self, value: Any, limit: int) -> str:
        text = " ".join(str(value or "").split())
        return text[:limit].strip()

    def _mercadopago_checkout_ready(self, item: dict[str, Any] | None) -> bool:
        if not isinstance(item, dict):
            return False
        access_token = self._mercadopago_access_token()
        title = self._trim_checkout_text(item.get("title"), 120)
        price_brl = float(item.get("price_brl") or 0)
        return bool(access_token and title and price_brl > 0)

    def _append_jsonl(self, path: Path, payload: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, ensure_ascii=False) + "\n")

    def _write_mercadopago_notification_probe(self) -> None:
        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "mercado_pago",
                "route": "/integrations/mercadopago/notifications",
                "method": "POST",
                "received_at_utc": utc_now_iso(),
                "detail": "Endpoint de notificacoes do Mercado Pago ativo.",
            },
        )

    def _write_mercadopago_notification_event(self, query: str) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(content_length) if content_length > 0 else b""
        text_body = raw_body.decode("utf-8", errors="replace")
        try:
            parsed_body = json.loads(text_body) if text_body else None
        except json.JSONDecodeError:
            parsed_body = None

        event = {
            "provider": "mercado_pago",
            "received_at_utc": utc_now_iso(),
            "query": parse_qs(query),
            "headers": {
                "content_type": self.headers.get("Content-Type"),
                "user_agent": self.headers.get("User-Agent"),
                "x_request_id": self.headers.get("X-Request-Id"),
                "x_signature": self.headers.get("X-Signature"),
                "x_topic": self.headers.get("X-Topic"),
                "x_idempotency_key": self.headers.get("X-Idempotency-Key"),
            },
            "body": parsed_body if parsed_body is not None else text_body,
        }
        self._append_jsonl(MERCADOPAGO_NOTIFICATIONS_PATH, event)
        write_json_file(MERCADOPAGO_NOTIFICATIONS_LATEST_PATH, event)

        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "mercado_pago",
                "received_at_utc": event["received_at_utc"],
                "detail": "Notificacao recebida e persistida.",
            },
        )

    def _write_mercadopago_return_page(self, query: str) -> None:
        params = parse_qs(query)
        status = str(
            (params.get("status") or params.get("collection_status") or ["pending"])[0]
            or "pending"
        ).strip().lower()
        item_id = str(
            (params.get("item_id") or params.get("external_reference") or [""])[0] or ""
        ).strip()
        title = {
            "approved": "Pagamento aprovado",
            "pending": "Pagamento pendente",
            "failure": "Pagamento não concluído",
            "rejected": "Pagamento recusado",
        }.get(status, "Retorno do pagamento")
        detail = {
            "approved": "O checkout do Valley recebeu a confirmação inicial do Mercado Pago.",
            "pending": "O pagamento foi criado e aguarda confirmação final do Mercado Pago.",
            "failure": "O pagamento não foi concluído. Você pode retornar ao produto e tentar novamente.",
            "rejected": "O Mercado Pago recusou a transação. Revise o meio de pagamento e tente novamente.",
        }.get(status, "O fluxo de pagamento retornou ao Valley.")
        payload = {
            "provider": "mercado_pago",
            "received_at_utc": utc_now_iso(),
            "status": status,
            "item_id": item_id,
            "query": {key: values for key, values in params.items()},
        }
        body = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title} • Valley</title>
    <style>
      body {{
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: linear-gradient(180deg, #07051F 0%, #151047 100%);
        color: #FFFFFF;
        font-family: Inter, Arial, sans-serif;
      }}
      main {{
        width: min(680px, calc(100vw - 32px));
        padding: 28px;
        border-radius: 24px;
        background: rgba(12, 14, 36, 0.88);
        border: 1px solid rgba(255, 255, 255, 0.08);
        box-shadow: 0 24px 80px rgba(0, 0, 0, 0.35);
      }}
      h1 {{ margin: 0 0 12px; font-size: 28px; }}
      p {{ color: rgba(255,255,255,0.78); line-height: 1.55; }}
      code {{
        display: block;
        margin-top: 18px;
        padding: 16px;
        border-radius: 16px;
        background: rgba(255,255,255,0.04);
        overflow: auto;
        white-space: pre-wrap;
      }}
      a {{
        display: inline-flex;
        margin-top: 18px;
        padding: 12px 16px;
        border-radius: 999px;
        background: #6F2CFF;
        color: #FFFFFF;
        text-decoration: none;
        font-weight: 700;
      }}
    </style>
  </head>
  <body>
    <main>
      <h1>{title}</h1>
      <p>{detail}</p>
      <a href="{self._public_admin_base_url()}/product/">Voltar ao catálogo Valley</a>
      <code>{json.dumps(payload, ensure_ascii=False, indent=2)}</code>
    </main>
  </body>
</html>""".encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _create_mercadopago_preference(self, item: dict[str, Any]) -> dict[str, Any]:
        access_token = self._mercadopago_access_token()
        if not access_token:
            return {
                "status": "missing_credentials",
                "detail": "Access token do Mercado Pago ausente no runtime.",
            }

        item_id = str(item.get("id") or "").strip()
        title = self._trim_checkout_text(item.get("title"), 120)
        description = self._trim_checkout_text(item.get("description"), 240)
        picture_url = str(item.get("image_url") or "").strip()
        price_brl = round(float(item.get("price_brl") or 0), 2)
        if not item_id or not title or price_brl <= 0:
            return {
                "status": "invalid_item",
                "detail": "Item sem identificador, título ou preço válido para checkout.",
            }

        payload = {
            "items": [
                {
                    "id": item_id,
                    "title": title,
                    "description": description or title,
                    "quantity": 1,
                    "currency_id": "BRL",
                    "unit_price": price_brl,
                }
            ],
            "external_reference": item_id,
            "statement_descriptor": "VALLEY",
            "auto_return": "approved",
            "back_urls": {
                "success": self._mercadopago_return_url("approved", item_id),
                "pending": self._mercadopago_return_url("pending", item_id),
                "failure": self._mercadopago_return_url("failure", item_id),
            },
            "notification_url": self._mercadopago_notification_url(),
            "metadata": {
                "item_id": item_id,
                "module_id": str(item.get("module_id") or "STOCK"),
                "surface": "valley_stock",
            },
        }
        if self._is_http_url(picture_url):
            payload["items"][0]["picture_url"] = picture_url

        request = Request(
            "https://api.mercadopago.com/checkout/preferences",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
                "X-Idempotency-Key": f"valley-{item_id}-{int(time.time())}",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=45) as response:
                response_payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            return {
                "status": "http_error",
                "detail": error.read().decode("utf-8", errors="replace"),
                "code": error.code,
            }
        except URLError as error:
            return {"status": "network_error", "detail": str(error)}
        except json.JSONDecodeError as error:
            return {"status": "invalid_response", "detail": str(error)}
        except Exception as error:  # noqa: BLE001
            return {"status": "failed", "detail": str(error)}

        init_point = str(
            response_payload.get("init_point")
            or response_payload.get("sandbox_init_point")
            or ""
        ).strip()
        if not init_point:
            return {
                "status": "api_error",
                "detail": "Mercado Pago não retornou init_point para a preferência.",
                "response": response_payload,
            }

        event = {
            "provider": "mercado_pago",
            "created_at_utc": utc_now_iso(),
            "item_id": item_id,
            "preference_id": response_payload.get("id"),
            "external_reference": response_payload.get("external_reference"),
            "init_point": init_point,
            "sandbox_init_point": response_payload.get("sandbox_init_point"),
        }
        self._append_jsonl(MERCADOPAGO_PREFERENCES_PATH, event)

        return {
            "status": "ok",
            "url": init_point,
            "preference_id": response_payload.get("id"),
            "sandbox": "sandbox" in init_point,
        }

    def _write_mercadolivre_callback(self, query: str, redirect_uri_override: str | None = None) -> None:
        params = parse_qs(query)
        payload = {
            "provider": "mercado_livre",
            "received_at_utc": utc_now_iso(),
            "code": (params.get("code") or [None])[0],
            "state": (params.get("state") or [None])[0],
            "error": (params.get("error") or [None])[0],
            "error_description": (params.get("error_description") or [None])[0],
            "redirect_uri_override": redirect_uri_override,
            "raw_query": query,
        }
        token_exchange = None
        if payload["code"]:
            token_exchange = self._exchange_mercadolivre_code(
                payload["code"],
                state=payload["state"],
                redirect_uri_override=redirect_uri_override,
            )
            payload["token_exchange"] = token_exchange
        write_json_file(MARKETPLACE_OAUTH_RUNTIME_PATH, payload)

        if token_exchange and token_exchange.get("status") == "ok":
            status = "autorizacao concluida"
            detail = "Codigo OAuth trocado por access token e refresh token com sucesso."
        elif payload["code"]:
            status = "autorizacao recebida"
            detail = (
                token_exchange.get("detail")
                if isinstance(token_exchange, dict) and token_exchange.get("detail")
                else "Codigo OAuth capturado e persistido no runtime local."
            )
        else:
            status = "callback recebida"
            detail = payload["error_description"] or payload["error"] or "Nenhum code foi informado."
        html = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Valley | Mercado Livre OAuth</title>
    <style>
      body {{ font-family: Arial, sans-serif; background:#0b1020; color:#e8edf7; margin:0; }}
      main {{ max-width:760px; margin:48px auto; padding:24px; }}
      section {{ background:#121a31; border:1px solid #253150; border-radius:8px; padding:24px; }}
      h1 {{ margin:0 0 8px; font-size:28px; }}
      p, code {{ color:#b7c2dc; }}
      code {{ display:block; margin-top:16px; white-space:pre-wrap; word-break:break-word; }}
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>{status}</h1>
        <p>{detail}</p>
        <code>{json.dumps(payload, ensure_ascii=False, indent=2)}</code>
      </section>
    </main>
  </body>
</html>
"""
        body = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _redirect_mercadolivre_authorize(self) -> None:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "mercado_livre"),
            None,
        )
        client_id = str((provider or {}).get("clientId") or "").strip()
        redirect_uri = str((provider or {}).get("redirectUri") or "").strip()
        if not client_id or not redirect_uri:
            self._write_json(
                HTTPStatus.BAD_REQUEST,
                {
                    "status": "missing_credentials",
                    "service": "valley-admin",
                    "provider": "mercado_livre",
                    "detail": "Client ID ou redirect URI ausentes para montar o fluxo OAuth com PKCE.",
                },
            )
            return

        state = f"valley-mlb-{secrets.token_urlsafe(12)}"
        code_verifier = secrets.token_urlsafe(64)
        code_challenge = base64url_sha256(code_verifier)
        saved = load_json_file(MERCADOLIVRE_PKCE_PATH)
        payload = saved if isinstance(saved, dict) else {}
        payload[state] = {
            "created_at_utc": utc_now_iso(),
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "code_verifier": code_verifier,
            "code_challenge_method": "S256",
        }
        write_json_file(MERCADOLIVRE_PKCE_PATH, payload)

        auth_url = (
            "https://auth.mercadolivre.com.br/authorization?"
            + urlencode(
                {
                    "response_type": "code",
                    "client_id": client_id,
                    "redirect_uri": redirect_uri,
                    "state": state,
                    "code_challenge": code_challenge,
                    "code_challenge_method": "S256",
                }
            )
        )
        self.send_response(HTTPStatus.FOUND)
        self.send_header("Location", auth_url)
        self.end_headers()

    def _exchange_mercadolivre_code(
        self,
        code: str,
        state: str | None = None,
        redirect_uri_override: str | None = None,
    ) -> dict[str, Any]:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "mercado_livre"),
            None,
        )
        secrets = load_json_file(PROVIDER_SECRETS_PATH) or {}
        provider_secrets = secrets.get("mercado_livre") if isinstance(secrets, dict) else None

        client_id = str((provider or {}).get("clientId") or "").strip()
        configured_secret_ref = str((provider or {}).get("secretRef") or "").strip()
        client_secret = str((provider_secrets or {}).get("clientSecret") or "").strip()
        redirect_uri = str(redirect_uri_override or (provider or {}).get("redirectUri") or "").strip()

        # O cockpit do admin hoje aceita tanto um runtime ref quanto o valor bruto
        # do segredo. Se o operador preencheu a secret diretamente no painel,
        # ela deve prevalecer sobre um runtime antigo para evitar invalid_client.
        if configured_secret_ref and not configured_secret_ref.startswith("runtime://"):
            client_secret = configured_secret_ref
            secrets.setdefault("mercado_livre", {})
            secrets["mercado_livre"]["clientSecret"] = client_secret
            secrets["mercado_livre"]["updated_at_utc"] = utc_now_iso()
            write_json_file(PROVIDER_SECRETS_PATH, secrets)

        if not client_id or not client_secret or not redirect_uri:
            return {
                "status": "missing_credentials",
                "detail": "Client ID, client secret ou redirect URI ausentes para a troca do token.",
            }

        pkce_saved = load_json_file(MERCADOLIVRE_PKCE_PATH)
        pkce_entries = pkce_saved if isinstance(pkce_saved, dict) else {}
        pkce_entry = pkce_entries.get(state or "") if state else None
        code_verifier = str((pkce_entry or {}).get("code_verifier") or "").strip()

        payload_data = {
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "redirect_uri": redirect_uri,
        }
        if code_verifier:
            payload_data["code_verifier"] = code_verifier

        body = urlencode(payload_data).encode("utf-8")
        request = Request(
            "https://api.mercadolibre.com/oauth/token",
            data=body,
            headers={
                "accept": "application/json",
                "content-type": "application/x-www-form-urlencoded",
            },
            method="POST",
        )

        try:
            with urlopen(request, timeout=45) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            return {
                "status": "http_error",
                "code": error.code,
                "detail": detail,
            }
        except URLError as error:
            return {
                "status": "network_error",
                "detail": str(error),
            }
        except Exception as error:  # noqa: BLE001
            return {
                "status": "failed",
                "detail": str(error),
            }

        access_token = payload.get("access_token")
        refresh_token = payload.get("refresh_token")
        if access_token:
            secrets.setdefault("mercado_livre", {})
            secrets["mercado_livre"]["accessToken"] = access_token
            secrets["mercado_livre"]["updated_at_utc"] = utc_now_iso()
        if refresh_token:
            secrets.setdefault("mercado_livre", {})
            secrets["mercado_livre"]["refreshToken"] = refresh_token
            secrets["mercado_livre"]["updated_at_utc"] = utc_now_iso()
        if access_token or refresh_token:
            write_json_file(PROVIDER_SECRETS_PATH, secrets)
        if state and state in pkce_entries and access_token:
            pkce_entries.pop(state, None)
            write_json_file(MERCADOLIVRE_PKCE_PATH, pkce_entries)

        update_marketplace_integration(
            "mercado_livre",
            {
                "secretRef": "runtime://marketplaces/mercado_livre/client-secret",
                "accessTokenRef": "runtime://marketplaces/mercado_livre/access-token" if access_token else "",
                "refreshTokenRef": "runtime://marketplaces/mercado_livre/refresh-token" if refresh_token else "",
                "notes": "OAuth concluido e tokens persistidos em runtime local."
                if access_token or refresh_token
                else "OAuth iniciou mas nao retornou tokens persistiveis.",
            },
        )

        return {
            "status": "ok",
            "token_type": payload.get("token_type"),
            "expires_in": payload.get("expires_in"),
            "scope": payload.get("scope"),
            "user_id": payload.get("user_id"),
            "stored_access_token": bool(access_token),
            "stored_refresh_token": bool(refresh_token),
        }

    def _write_shopee_callback(self, query: str) -> None:
        params = parse_qs(query)
        payload = {
            "provider": "shopee",
            "received_at_utc": utc_now_iso(),
            "code": (params.get("code") or [None])[0],
            "shop_id": (params.get("shop_id") or [None])[0],
            "main_account_id": (params.get("main_account_id") or [None])[0],
            "error": (params.get("error") or [None])[0],
            "message": (params.get("message") or [None])[0],
            "raw_query": query,
        }
        write_json_file(SHOPEE_OAUTH_RUNTIME_PATH, payload)
        if payload["shop_id"]:
            update_marketplace_integration(
                "shopee",
                {
                    "sellerId": str(payload["shop_id"]),
                    "notes": "Callback Shopee recebida; partner credentials pendentes para troca do token.",
                },
            )

        status = "callback recebida"
        detail = (
            "Codigo de autorizacao e shop_id capturados para a Shopee."
            if payload["code"] or payload["shop_id"]
            else payload["message"] or payload["error"] or "Nenhum parametro de autorizacao foi informado."
        )
        html = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Valley | Shopee OAuth</title>
    <style>
      body {{ font-family: Arial, sans-serif; background:#0b1020; color:#e8edf7; margin:0; }}
      main {{ max-width:760px; margin:48px auto; padding:24px; }}
      section {{ background:#121a31; border:1px solid #253150; border-radius:8px; padding:24px; }}
      h1 {{ margin:0 0 8px; font-size:28px; }}
      p, code {{ color:#b7c2dc; }}
      code {{ display:block; margin-top:16px; white-space:pre-wrap; word-break:break-word; }}
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>{status}</h1>
        <p>{detail}</p>
        <code>{json.dumps(payload, ensure_ascii=False, indent=2)}</code>
      </section>
    </main>
  </body>
</html>
"""
        body = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _write_aliexpress_callback(self, query: str) -> None:
        params = parse_qs(query)
        payload = {
            "provider": "aliexpress",
            "received_at_utc": utc_now_iso(),
            "code": (params.get("code") or [None])[0],
            "state": (params.get("state") or [None])[0],
            "error": (params.get("error") or [None])[0],
            "error_description": (params.get("error_description") or [None])[0],
            "raw_query": query,
        }
        token_exchange = None
        if payload["code"]:
            token_exchange = self._exchange_aliexpress_code(payload["code"])
            payload["token_exchange"] = token_exchange
        write_json_file(ALIEXPRESS_OAUTH_RUNTIME_PATH, payload)

        if token_exchange and token_exchange.get("status") == "ok":
            status = "autorizacao concluida"
            detail = "Codigo OAuth trocado por access token e refresh token com sucesso."
        elif payload["code"]:
            status = "autorizacao recebida"
            detail = (
                token_exchange.get("detail")
                if isinstance(token_exchange, dict) and token_exchange.get("detail")
                else "Codigo de autorizacao do AliExpress capturado para troca posterior do token."
            )
        else:
            status = "callback recebida"
            detail = payload["error_description"] or payload["error"] or "Nenhum parametro de autorizacao foi informado."
        html = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Valley | AliExpress OAuth</title>
    <style>
      body {{ font-family: Arial, sans-serif; background:#0b1020; color:#e8edf7; margin:0; }}
      main {{ max-width:760px; margin:48px auto; padding:24px; }}
      section {{ background:#121a31; border:1px solid #253150; border-radius:8px; padding:24px; }}
      h1 {{ margin:0 0 8px; font-size:28px; }}
      p, code {{ color:#b7c2dc; }}
      code {{ display:block; margin-top:16px; white-space:pre-wrap; word-break:break-word; }}
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>{status}</h1>
        <p>{detail}</p>
        <code>{json.dumps(payload, ensure_ascii=False, indent=2)}</code>
      </section>
    </main>
  </body>
</html>
"""
        body = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _redirect_alibaba_authorize(self) -> None:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "alibaba"),
            None,
        )
        client_id = str((provider or {}).get("clientId") or "").strip()
        redirect_uri = str((provider or {}).get("redirectUri") or "").strip()
        if not client_id or not redirect_uri:
            self._write_json(
                HTTPStatus.BAD_REQUEST,
                {
                    "status": "missing_credentials",
                    "service": "valley-admin",
                    "provider": "alibaba",
                    "detail": "App Key ou redirect URI ausentes para montar o fluxo OAuth do Alibaba.",
                },
            )
            return

        state = f"valley-alibaba-{secrets.token_urlsafe(12)}"
        auth_url = (
            "https://oauth.alibaba.com/authorize?"
            + urlencode(
                {
                    "response_type": "code",
                    "client_id": client_id,
                    "redirect_uri": redirect_uri,
                    "state": state,
                    "view": "web",
                    "sp": "ICBU",
                    "force_login": "true",
                }
            )
        )
        write_json_file(
            ALIBABA_OAUTH_RUNTIME_PATH,
            {
                "provider": "alibaba",
                "generated_at_utc": utc_now_iso(),
                "state": state,
                "authorize_url": auth_url,
                "redirect_uri": redirect_uri,
            },
        )
        self.send_response(HTTPStatus.FOUND)
        self.send_header("Location", auth_url)
        self.end_headers()

    def _write_alibaba_callback(self, query: str) -> None:
        params = parse_qs(query)
        payload = {
            "provider": "alibaba",
            "received_at_utc": utc_now_iso(),
            "code": (params.get("code") or [None])[0],
            "state": (params.get("state") or [None])[0],
            "error": (params.get("error") or [None])[0],
            "error_description": (params.get("error_description") or [None])[0],
            "raw_query": query,
        }
        token_exchange = None
        if payload["code"]:
            token_exchange = self._exchange_alibaba_code(payload["code"])
            payload["token_exchange"] = token_exchange
        write_json_file(ALIBABA_OAUTH_RUNTIME_PATH, payload)

        if token_exchange and token_exchange.get("status") == "ok":
            update_marketplace_integration(
                "alibaba",
                {
                    "enabled": True,
                    "environment": "production",
                    "authMode": "oauth2",
                    "redirectUri": "https://admin.brasildesconto.com.br/integrations/alibaba/callback",
                    "secretRef": "runtime://marketplaces/alibaba/client-secret",
                    "accessTokenRef": "runtime://marketplaces/alibaba/access-token",
                    "refreshTokenRef": "runtime://marketplaces/alibaba/refresh-token",
                    "sellerId": str(token_exchange.get("user_id") or token_exchange.get("user_nick") or "").strip(),
                    "notes": "OAuth Alibaba concluido; access token e refresh token persistidos em runtime local.",
                },
            )
        elif payload["code"]:
            update_marketplace_integration(
                "alibaba",
                {
                    "redirectUri": "https://admin.brasildesconto.com.br/integrations/alibaba/callback",
                    "notes": "Callback OAuth Alibaba recebida; troca de token pendente ou com falha.",
                },
            )

        if token_exchange and token_exchange.get("status") == "ok":
            status = "autorizacao concluida"
            detail = "Codigo OAuth trocado por access token e refresh token com sucesso."
        elif payload["code"]:
            status = "autorizacao recebida"
            detail = (
                token_exchange.get("detail")
                if isinstance(token_exchange, dict) and token_exchange.get("detail")
                else "Codigo OAuth do Alibaba capturado para troca posterior do token."
            )
        else:
            status = "callback recebida"
            detail = payload["error_description"] or payload["error"] or "Nenhum parametro de autorizacao foi informado."
        html = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Valley | Alibaba OAuth</title>
    <style>
      body {{ font-family: Arial, sans-serif; background:#0b1020; color:#e8edf7; margin:0; }}
      main {{ max-width:760px; margin:48px auto; padding:24px; }}
      section {{ background:#121a31; border:1px solid #253150; border-radius:8px; padding:24px; }}
      h1 {{ margin:0 0 8px; font-size:28px; }}
      p, code {{ color:#b7c2dc; }}
      code {{ display:block; margin-top:16px; white-space:pre-wrap; word-break:break-word; }}
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>{status}</h1>
        <p>{detail}</p>
        <code>{json.dumps(payload, ensure_ascii=False, indent=2)}</code>
      </section>
    </main>
  </body>
</html>
"""
        body = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _redirect_magalu_authorize(self) -> None:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "magalu"),
            None,
        )
        client_id = str((provider or {}).get("clientId") or "").strip()
        redirect_uri = str((provider or {}).get("redirectUri") or "").strip()
        scopes = str((provider or {}).get("scopes") or "").strip()
        if not client_id or not redirect_uri or not scopes:
            self._write_json(
                HTTPStatus.BAD_REQUEST,
                {
                    "status": "missing_credentials",
                    "service": "valley-admin",
                    "provider": "magalu",
                    "detail": "Client ID, redirect URI ou scopes ausentes para montar o fluxo OAuth da Magalu.",
                },
            )
            return

        state = f"valley-magalu-{secrets.token_urlsafe(12)}"
        auth_url = (
            "https://id.magalu.com/login?"
            + urlencode(
                {
                    "client_id": client_id,
                    "redirect_uri": redirect_uri,
                    "scope": scopes,
                    "response_type": "code",
                    "choose_tenants": "true",
                    "state": state,
                }
            )
        )
        write_json_file(
            MAGALU_OAUTH_RUNTIME_PATH,
            {
                "provider": "magalu",
                "generated_at_utc": utc_now_iso(),
                "state": state,
                "authorize_url": auth_url,
                "redirect_uri": redirect_uri,
            },
        )
        self.send_response(HTTPStatus.FOUND)
        self.send_header("Location", auth_url)
        self.end_headers()

    def _write_magalu_callback(self, query: str) -> None:
        params = parse_qs(query)
        payload = {
            "provider": "magalu",
            "received_at_utc": utc_now_iso(),
            "code": (params.get("code") or [None])[0],
            "state": (params.get("state") or [None])[0],
            "error": (params.get("error") or [None])[0],
            "error_description": (params.get("error_description") or [None])[0],
            "raw_query": query,
        }
        token_exchange = None
        if payload["code"]:
            token_exchange = self._exchange_magalu_code(payload["code"])
            payload["token_exchange"] = token_exchange
        write_json_file(MAGALU_OAUTH_RUNTIME_PATH, payload)
        if token_exchange and token_exchange.get("status") == "ok":
            update_marketplace_integration(
                "magalu",
                {
                    "enabled": True,
                    "environment": "production",
                    "redirectUri": "https://admin.brasildesconto.com.br/integrations/magalu/callback",
                    "secretRef": "runtime://marketplaces/magalu/client-secret",
                    "accessTokenRef": "runtime://marketplaces/magalu/access-token",
                    "refreshTokenRef": "runtime://marketplaces/magalu/refresh-token",
                    "notes": "OAuth Magalu concluido; access token e refresh token persistidos em runtime local.",
                },
            )
        elif payload["code"]:
            update_marketplace_integration(
                "magalu",
                {
                    "redirectUri": "https://admin.brasildesconto.com.br/integrations/magalu/callback",
                    "notes": "Callback OAuth Magalu recebida; troca de token pendente ou com falha.",
                },
            )

        if token_exchange and token_exchange.get("status") == "ok":
            status = "autorizacao concluida"
            detail = "Codigo OAuth trocado por access token e refresh token com sucesso."
        elif payload["code"]:
            status = "autorizacao recebida"
            detail = (
                token_exchange.get("detail")
                if isinstance(token_exchange, dict) and token_exchange.get("detail")
                else "Codigo OAuth da Magalu capturado para troca posterior do token."
            )
        else:
            status = "callback recebida"
            detail = payload["error_description"] or payload["error"] or "Nenhum parametro de autorizacao foi informado."
        html = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Valley | Magalu OAuth</title>
    <style>
      body {{ font-family: Arial, sans-serif; background:#0b1020; color:#e8edf7; margin:0; }}
      main {{ max-width:760px; margin:48px auto; padding:24px; }}
      section {{ background:#121a31; border:1px solid #253150; border-radius:8px; padding:24px; }}
      h1 {{ margin:0 0 8px; font-size:28px; }}
      p, code {{ color:#b7c2dc; }}
      code {{ display:block; margin-top:16px; white-space:pre-wrap; word-break:break-word; }}
    </style>
  </head>
  <body>
    <main>
      <section>
        <h1>{status}</h1>
        <p>{detail}</p>
        <code>{json.dumps(payload, ensure_ascii=False, indent=2)}</code>
      </section>
    </main>
  </body>
</html>
"""
        body = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _exchange_magalu_code(self, code: str) -> dict[str, Any]:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "magalu"),
            None,
        )
        secrets_payload = load_json_file(PROVIDER_SECRETS_PATH) or {}
        provider_secrets = secrets_payload.get("magalu") if isinstance(secrets_payload, dict) else None

        client_id = str((provider or {}).get("clientId") or "").strip()
        configured_secret_ref = str((provider or {}).get("secretRef") or "").strip()
        client_secret = str((provider_secrets or {}).get("clientSecret") or "").strip()
        redirect_uri = str((provider or {}).get("redirectUri") or "").strip()

        if configured_secret_ref and not configured_secret_ref.startswith("runtime://"):
            client_secret = configured_secret_ref
            secrets_payload.setdefault("magalu", {})
            secrets_payload["magalu"]["clientSecret"] = client_secret
            secrets_payload["magalu"]["updated_at_utc"] = utc_now_iso()
            write_json_file(PROVIDER_SECRETS_PATH, secrets_payload)

        if not client_id or not client_secret or not redirect_uri:
            return {
                "status": "missing_credentials",
                "detail": "Client ID, client secret ou redirect URI ausentes para a troca do token da Magalu.",
            }

        body = json.dumps(
            {
                "client_id": client_id,
                "client_secret": client_secret,
                "redirect_uri": redirect_uri,
                "code": code,
                "grant_type": "authorization_code",
            }
        ).encode("utf-8")
        request = Request(
            "https://id.magalu.com/oauth/token",
            data=body,
            headers={
                "accept": "application/json",
                "content-type": "application/json",
            },
            method="POST",
        )

        try:
            with urlopen(request, timeout=45) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            return {
                "status": "http_error",
                "code": error.code,
                "detail": detail,
            }
        except URLError as error:
            return {
                "status": "network_error",
                "detail": str(error),
            }
        except Exception as error:  # noqa: BLE001
            return {
                "status": "failed",
                "detail": str(error),
            }

        access_token = str(payload.get("access_token") or "").strip()
        refresh_token = str(payload.get("refresh_token") or "").strip()
        if not access_token:
            return {
                "status": "api_error",
                "detail": payload.get("error_description")
                or payload.get("error")
                or "Magalu nao retornou access token na troca do code.",
                "response": payload,
            }

        secrets_payload.setdefault("magalu", {})
        secrets_payload["magalu"]["clientSecret"] = client_secret
        secrets_payload["magalu"]["accessToken"] = access_token
        secrets_payload["magalu"]["updated_at_utc"] = utc_now_iso()
        if refresh_token:
            secrets_payload["magalu"]["refreshToken"] = refresh_token
        if payload.get("scope") is not None:
            secrets_payload["magalu"]["scope"] = payload.get("scope")
        if payload.get("expires_in") is not None:
            secrets_payload["magalu"]["expiresIn"] = payload.get("expires_in")
        if payload.get("created_at") is not None:
            secrets_payload["magalu"]["createdAt"] = payload.get("created_at")
        write_json_file(PROVIDER_SECRETS_PATH, secrets_payload)

        return {
            "status": "ok",
            "token_type": payload.get("token_type"),
            "expires_in": payload.get("expires_in"),
            "scope": payload.get("scope"),
            "stored_access_token": bool(access_token),
            "stored_refresh_token": bool(refresh_token),
        }

    def _exchange_alibaba_code(self, code: str) -> dict[str, Any]:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "alibaba"),
            None,
        )
        secrets_payload = load_json_file(PROVIDER_SECRETS_PATH) or {}
        provider_secrets = secrets_payload.get("alibaba") if isinstance(secrets_payload, dict) else None

        app_key = str((provider or {}).get("clientId") or "").strip()
        configured_secret_ref = str((provider or {}).get("secretRef") or "").strip()
        app_secret = str((provider_secrets or {}).get("clientSecret") or "").strip()

        if configured_secret_ref and not configured_secret_ref.startswith("runtime://"):
            app_secret = configured_secret_ref
            secrets_payload.setdefault("alibaba", {})
            secrets_payload["alibaba"]["clientSecret"] = app_secret
            secrets_payload["alibaba"]["updated_at_utc"] = utc_now_iso()
            write_json_file(PROVIDER_SECRETS_PATH, secrets_payload)

        if not app_key or not app_secret:
            return {
                "status": "missing_credentials",
                "detail": "AppKey ou App Secret ausentes para a troca do token do Alibaba.",
            }

        now_gmt8 = datetime.now(timezone.utc).astimezone(timezone.utc).timestamp() + 8 * 3600
        timestamp = datetime.fromtimestamp(now_gmt8, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        params = {
            "app_key": app_key,
            "code": code,
            "format": "json",
            "method": "taobao.top.auth.token.create",
            "partner_id": "valley",
            "sign_method": "md5",
            "timestamp": timestamp,
            "v": "2.0",
        }
        sign = top_md5_upper(app_secret, params)
        body = urlencode({**params, "sign": sign}).encode("utf-8")
        request = Request(
            "https://eco.taobao.com/router/rest",
            data=body,
            headers={
                "accept": "application/json",
                "content-type": "application/x-www-form-urlencoded;charset=utf-8",
            },
            method="POST",
        )

        try:
            with urlopen(request, timeout=45) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            return {
                "status": "http_error",
                "code": error.code,
                "detail": detail,
            }
        except URLError as error:
            return {
                "status": "network_error",
                "detail": str(error),
            }
        except Exception as error:  # noqa: BLE001
            return {
                "status": "failed",
                "detail": str(error),
            }

        error_payload = payload.get("error_response")
        if isinstance(error_payload, dict):
            return {
                "status": "api_error",
                "code": error_payload.get("code"),
                "detail": error_payload.get("sub_msg") or error_payload.get("msg") or "Alibaba recusou a troca do token.",
                "response": payload,
            }

        response_payload = payload.get("top_auth_token_create_response")
        if not isinstance(response_payload, dict):
            return {
                "status": "api_error",
                "detail": "Alibaba nao retornou top_auth_token_create_response.",
                "response": payload,
            }

        token_result_raw = response_payload.get("token_result")
        if isinstance(token_result_raw, str):
            try:
                token_result = json.loads(token_result_raw)
            except json.JSONDecodeError:
                return {
                    "status": "api_error",
                    "detail": "Alibaba retornou token_result em formato invalido.",
                    "response": payload,
                }
        elif isinstance(token_result_raw, dict):
            token_result = token_result_raw
        else:
            return {
                "status": "api_error",
                "detail": "Alibaba nao retornou token_result.",
                "response": payload,
            }

        access_token = str(token_result.get("access_token") or "").strip()
        refresh_token = str(token_result.get("refresh_token") or "").strip()
        user_id = str(token_result.get("user_id") or "").strip()
        user_nick = str(token_result.get("user_nick") or "").strip()
        if not access_token:
            return {
                "status": "api_error",
                "detail": "Alibaba nao retornou access token na troca do code.",
                "response": payload,
            }

        secrets_payload.setdefault("alibaba", {})
        secrets_payload["alibaba"]["clientSecret"] = app_secret
        secrets_payload["alibaba"]["accessToken"] = access_token
        secrets_payload["alibaba"]["updated_at_utc"] = utc_now_iso()
        if refresh_token:
            secrets_payload["alibaba"]["refreshToken"] = refresh_token
        if user_id:
            secrets_payload["alibaba"]["userId"] = user_id
        if user_nick:
            secrets_payload["alibaba"]["userNick"] = user_nick
        for key in ["expire_time", "refresh_token_valid_time", "locale", "sp", "w1_valid", "w2_valid", "r1_valid", "r2_valid"]:
            if token_result.get(key) is not None:
                secrets_payload["alibaba"][key] = token_result.get(key)
        write_json_file(PROVIDER_SECRETS_PATH, secrets_payload)

        return {
            "status": "ok",
            "user_id": user_id,
            "user_nick": user_nick,
            "sp": token_result.get("sp"),
            "expire_time": token_result.get("expire_time"),
            "stored_access_token": bool(access_token),
            "stored_refresh_token": bool(refresh_token),
        }

    def _exchange_aliexpress_code(self, code: str) -> dict[str, Any]:
        integrations_saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        integrations = integrations_saved if isinstance(integrations_saved, list) else []
        provider = next(
            (item for item in integrations if isinstance(item, dict) and item.get("key") == "aliexpress"),
            None,
        )
        secrets_payload = load_json_file(PROVIDER_SECRETS_PATH) or {}
        provider_secrets = secrets_payload.get("aliexpress") if isinstance(secrets_payload, dict) else None

        app_key = str((provider or {}).get("clientId") or "").strip()
        configured_secret_ref = str((provider or {}).get("secretRef") or "").strip()
        app_secret = str((provider_secrets or {}).get("clientSecret") or "").strip()
        base_url = str((provider or {}).get("baseUrl") or "https://api-sg.aliexpress.com").strip().rstrip("/")

        if configured_secret_ref and not configured_secret_ref.startswith("runtime://"):
            app_secret = configured_secret_ref
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["clientSecret"] = app_secret
            secrets_payload["aliexpress"]["updated_at_utc"] = utc_now_iso()
            write_json_file(PROVIDER_SECRETS_PATH, secrets_payload)

        if not app_key or not app_secret:
            return {
                "status": "missing_credentials",
                "detail": "AppKey ou App Secret ausentes para a troca do token do AliExpress.",
            }

        api_name = "/auth/token/create"
        timestamp = str(int(datetime.now(timezone.utc).timestamp() * 1000))
        params = {
            "app_key": app_key,
            "code": code,
            "sign_method": "sha256",
            "timestamp": timestamp,
        }
        sign_payload = api_name + "".join(f"{key}{params[key]}" for key in sorted(params))
        sign = hmac_sha256_upper(app_secret, sign_payload)
        request_url = f"{base_url}/rest{api_name}?{urlencode({**params, 'sign': sign})}"
        request = Request(
            request_url,
            headers={
                "accept": "application/json",
            },
            method="GET",
        )

        try:
            with urlopen(request, timeout=45) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            return {
                "status": "http_error",
                "code": error.code,
                "detail": detail,
            }
        except URLError as error:
            return {
                "status": "network_error",
                "detail": str(error),
            }
        except Exception as error:  # noqa: BLE001
            return {
                "status": "failed",
                "detail": str(error),
            }

        if str(payload.get("code")) != "0":
            return {
                "status": "api_error",
                "code": payload.get("code"),
                "detail": payload.get("message") or payload.get("msg") or "AliExpress recusou a troca do token.",
                "response": payload,
            }

        access_token = str(payload.get("access_token") or "").strip()
        refresh_token = str(payload.get("refresh_token") or "").strip()
        seller_id = str(payload.get("seller_id") or payload.get("user_id") or "").strip()
        account = str(payload.get("account") or "").strip()
        if access_token:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["accessToken"] = access_token
            secrets_payload["aliexpress"]["updated_at_utc"] = utc_now_iso()
        if refresh_token:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["refreshToken"] = refresh_token
            secrets_payload["aliexpress"]["updated_at_utc"] = utc_now_iso()
        if payload.get("user_id") is not None:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["userId"] = payload.get("user_id")
        if payload.get("seller_id") is not None:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["sellerId"] = payload.get("seller_id")
        if account:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["account"] = account
        if payload.get("account_platform") is not None:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["accountPlatform"] = payload.get("account_platform")
        if payload.get("expires_in") is not None:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["expiresIn"] = payload.get("expires_in")
        if payload.get("refresh_expires_in") is not None:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["refreshExpiresIn"] = payload.get("refresh_expires_in")
        if payload.get("sp") is not None:
            secrets_payload.setdefault("aliexpress", {})
            secrets_payload["aliexpress"]["sp"] = payload.get("sp")
        if access_token or refresh_token:
            write_json_file(PROVIDER_SECRETS_PATH, secrets_payload)

        update_marketplace_integration(
            "aliexpress",
            {
                "enabled": bool(access_token),
                "environment": "sandbox",
                "secretRef": "runtime://marketplaces/aliexpress/client-secret",
                "accessTokenRef": "runtime://marketplaces/aliexpress/access-token" if access_token else "",
                "refreshTokenRef": "runtime://marketplaces/aliexpress/refresh-token" if refresh_token else "",
                "sellerId": seller_id,
                "notes": "OAuth AliExpress concluido em app Test; tokens persistidos em runtime local."
                if access_token
                else "OAuth AliExpress recebeu code, mas nao persistiu tokens.",
            },
        )

        return {
            "status": "ok",
            "access_token_expires_in": payload.get("expires_in"),
            "refresh_token_expires_in": payload.get("refresh_expires_in"),
            "user_id": payload.get("user_id"),
            "seller_id": payload.get("seller_id"),
            "account": payload.get("account"),
            "account_platform": payload.get("account_platform"),
            "stored_access_token": bool(access_token),
            "stored_refresh_token": bool(refresh_token),
        }

    def _write_aliexpress_notification_probe(self) -> None:
        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "aliexpress",
                "route": "/integrations/aliexpress/notifications",
                "method": "POST",
                "received_at_utc": utc_now_iso(),
                "detail": "Endpoint de mensagens do AliExpress ativo.",
            },
        )

    def _write_aliexpress_notification_event(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(content_length) if content_length > 0 else b""
        text_body = raw_body.decode("utf-8", errors="replace")
        try:
            parsed_body = json.loads(text_body) if text_body else None
        except json.JSONDecodeError:
            parsed_body = None

        event = {
            "provider": "aliexpress",
            "received_at_utc": utc_now_iso(),
            "headers": {
                "content_type": self.headers.get("Content-Type"),
                "user_agent": self.headers.get("User-Agent"),
                "x_request_id": self.headers.get("X-Request-Id"),
                "x_real_ip": self.headers.get("X-Real-Ip"),
                "x_forwarded_for": self.headers.get("X-Forwarded-For"),
            },
            "body": parsed_body if parsed_body is not None else text_body,
        }
        ALIEXPRESS_NOTIFICATIONS_PATH.parent.mkdir(parents=True, exist_ok=True)
        with ALIEXPRESS_NOTIFICATIONS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
        write_json_file(ALIEXPRESS_NOTIFICATIONS_LATEST_PATH, event)

        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "aliexpress",
                "received_at_utc": event["received_at_utc"],
                "detail": "Mensagem recebida e persistida.",
            },
        )

    def _write_cjdropshipping_notification_probe(self) -> None:
        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "cjdropshipping",
                "route": "/integrations/cjdropshipping/notifications",
                "method": "POST",
                "received_at_utc": utc_now_iso(),
                "detail": "Endpoint de notificacoes do CJDropshipping ativo.",
            },
        )

    def _write_cjdropshipping_notification_event(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(content_length) if content_length > 0 else b""
        text_body = raw_body.decode("utf-8", errors="replace")
        try:
            parsed_body = json.loads(text_body) if text_body else None
        except json.JSONDecodeError:
            parsed_body = None

        body_payload = parsed_body if parsed_body is not None else text_body
        topic = ""
        message_type = ""
        incremental_pids: list[str] = []
        incremental_vids: list[str] = []
        if isinstance(parsed_body, dict):
            topic = str(parsed_body.get("type") or "").upper().strip()
            message_type = str(parsed_body.get("messageType") or "").upper().strip()
            params = parsed_body.get("params")
            if topic == "PRODUCT" and isinstance(params, dict):
                pid = str(params.get("pid") or "").strip()
                if pid:
                    incremental_pids.append(pid)
            elif topic == "VARIANT" and isinstance(params, dict):
                vid = str(params.get("vid") or "").strip()
                if vid:
                    incremental_vids.append(vid)
            elif topic == "STOCK" and isinstance(params, dict):
                incremental_vids.extend(
                    str(key).strip()
                    for key in params.keys()
                    if str(key).strip()
                )

        event = {
            "provider": "cjdropshipping",
            "received_at_utc": utc_now_iso(),
            "headers": {
                "content_type": self.headers.get("Content-Type"),
                "user_agent": self.headers.get("User-Agent"),
                "x_request_id": self.headers.get("X-Request-Id"),
                "x_real_ip": self.headers.get("X-Real-Ip"),
                "x_forwarded_for": self.headers.get("X-Forwarded-For"),
            },
            "topic": topic,
            "message_type": message_type,
            "body": body_payload,
        }
        CJDROPSHIPPING_NOTIFICATIONS_PATH.parent.mkdir(parents=True, exist_ok=True)
        with CJDROPSHIPPING_NOTIFICATIONS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
        write_json_file(CJDROPSHIPPING_NOTIFICATIONS_LATEST_PATH, event)

        sync_result: dict[str, Any] | None = None
        if topic in {"PRODUCT", "VARIANT", "STOCK"}:
            manager = CATALOG_SYNC_MANAGER
            if manager is not None:
                force_full_sync = message_type == "DELETE" and topic in {"PRODUCT", "VARIANT"}
                sync_result = manager.schedule(
                    f"cj-webhook:{topic}:{message_type or 'UPDATE'}",
                    delay_seconds=25,
                    pids=incremental_pids,
                    vids=incremental_vids,
                    force_full_sync=force_full_sync,
                )
        elif topic in {"ORDER", "LOGISTICS"}:
            manager = CATALOG_SYNC_MANAGER
            if manager is not None:
                sync_result = manager.snapshot()

        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "cjdropshipping",
                "received_at_utc": event["received_at_utc"],
                "topic": topic or None,
                "message_type": message_type or None,
                "sync": sync_result,
                "detail": "Notificacao recebida, persistida e encaminhada para automacao do catalogo."
                if topic in {"PRODUCT", "VARIANT", "STOCK"}
                else "Notificacao recebida e persistida.",
            },
        )

    def _write_mercadolivre_notification_probe(self) -> None:
        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "mercado_livre",
                "route": "/integrations/mercadolivre/notifications",
                "method": "POST",
                "received_at_utc": utc_now_iso(),
                "detail": "Endpoint de notificacoes do Mercado Livre ativo.",
            },
        )

    def _write_mercadolivre_notification_event(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(content_length) if content_length > 0 else b""
        text_body = raw_body.decode("utf-8", errors="replace")
        try:
            parsed_body = json.loads(text_body) if text_body else None
        except json.JSONDecodeError:
            parsed_body = None

        event = {
            "provider": "mercado_livre",
            "received_at_utc": utc_now_iso(),
            "headers": {
                "content_type": self.headers.get("Content-Type"),
                "user_agent": self.headers.get("User-Agent"),
                "x_request_id": self.headers.get("X-Request-Id"),
                "x_real_ip": self.headers.get("X-Real-Ip"),
                "x_forwarded_for": self.headers.get("X-Forwarded-For"),
            },
            "body": parsed_body if parsed_body is not None else text_body,
        }
        MERCADOLIVRE_NOTIFICATIONS_PATH.parent.mkdir(parents=True, exist_ok=True)
        with MERCADOLIVRE_NOTIFICATIONS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
        write_json_file(MERCADOLIVRE_NOTIFICATIONS_LATEST_PATH, event)

        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": "mercado_livre",
                "received_at_utc": event["received_at_utc"],
                "detail": "Notificacao recebida e persistida.",
            },
        )

    def _product_interest_payload(self, query: dict[str, list[str]]) -> dict[str, Any]:
        item_id = (query.get("item_id") or [""])[0]
        item = self._find_catalog_item(item_id)
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
        item = self._find_catalog_item(item_id)
        media_url = self._derive_media_url(item) if item is not None else ""
        if item is None or not media_url:
            return {
                "status": "failed",
                "action": "open-media",
                "payload": {
                    "message": "Midia indisponivel para abertura direta nesta oferta.",
                },
            }

        return {
            "status": "ok",
            "action": "open-media",
            "payload": {
                "message": "Abrindo demonstracao.",
                "url": media_url,
            },
        }

    def _checkout_payload(self, query: dict[str, list[str]]) -> dict[str, Any]:
        item_id = (query.get("item_id") or [""])[0]
        item = self._find_catalog_item(item_id)
        if item is None:
            return {
                "status": "failed",
                "action": "checkout",
                "payload": {
                    "message": "Checkout indisponivel nesta oferta no momento.",
                },
            }

        if self._mercadopago_checkout_ready(item):
            mercadopago_result = self._create_mercadopago_preference(item)
            if mercadopago_result.get("status") == "ok":
                return {
                    "status": "ok",
                    "action": "checkout",
                    "payload": {
                        "message": "Abrindo checkout seguro do Valley com Mercado Pago.",
                        "url": mercadopago_result.get("url"),
                        "provider": "mercado_pago",
                        "preference_id": mercadopago_result.get("preference_id"),
                    },
                }

        checkout_url = self._derive_checkout_url(item)
        if not checkout_url:
            mercadopago_detail = ""
            if self._mercadopago_access_token():
                mercadopago_result = self._create_mercadopago_preference(item)
                mercadopago_detail = str(mercadopago_result.get("detail") or "").strip()
            return {
                "status": "failed",
                "action": "checkout",
                "payload": {
                    "message": mercadopago_detail or "Checkout indisponivel nesta oferta no momento.",
                },
            }

        return {
            "status": "ok",
            "action": "checkout",
            "payload": {
                "message": "Abrindo pagamento protegido da oferta.",
                "url": checkout_url,
                "provider": "mercado_livre",
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

    def _read_json_body(self) -> Any:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        if content_length <= 0:
            return None

        raw_body = self.rfile.read(content_length)
        try:
            return json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None


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
    global CATALOG_SYNC_MANAGER
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

    CATALOG_SYNC_MANAGER = CatalogSyncManager()
    CATALOG_SYNC_MANAGER.schedule("server-startup", delay_seconds=15)

    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        print("\nEncerrando Valley Admin.")
    finally:
        if CATALOG_SYNC_MANAGER is not None:
            CATALOG_SYNC_MANAGER.stop()
        server.server_close()


if __name__ == "__main__":
    main()
