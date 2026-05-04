#!/usr/bin/env python3
"""Servidor HTTP endurecido para o painel admin do Valley."""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import math
import os
import re
import secrets
import subprocess
import sys
import threading
import time
import unicodedata
import uuid
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
ADMIN_IMPORTED_PRODUCTS_PRICING_PATH = (
    RUNTIME_DIR / "valley-admin-imported-products-pricing.json"
)
DROPSHIPPING_STATUS_PATH = RUNTIME_DIR / "valley-dropshipping-integration-status.json"
CODEX_CLOUD_ENV_PATH = RUNTIME_DIR / "codex-cloud-secrets.env"
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
MERCADOPAGO_CHECKOUT_ATTEMPTS_PATH = RUNTIME_DIR / "valley-mercadopago-checkout-attempts.jsonl"
MERCADOPAGO_STATUS_PATH = RUNTIME_DIR / "valley-mercadopago-status.json"
MERCADOLIVRE_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-mercadolivre-notifications.jsonl"
MERCADOLIVRE_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-mercadolivre-notification-latest.json"
MERCADOLIVRE_PKCE_PATH = RUNTIME_DIR / "valley-mercadolivre-pkce.json"
AMAZON_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-amazon-notifications.jsonl"
AMAZON_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-amazon-notification-latest.json"
ALIEXPRESS_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-aliexpress-notifications.jsonl"
ALIEXPRESS_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-aliexpress-notification-latest.json"
ALIBABA_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-alibaba-notifications.jsonl"
ALIBABA_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-alibaba-notification-latest.json"
MAGALU_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-magalu-notifications.jsonl"
MAGALU_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-magalu-notification-latest.json"
CJDROPSHIPPING_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-cjdropshipping-notifications.jsonl"
CJDROPSHIPPING_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-cjdropshipping-notification-latest.json"
SHOPEE_NOTIFICATIONS_PATH = RUNTIME_DIR / "valley-shopee-notifications.jsonl"
SHOPEE_NOTIFICATIONS_LATEST_PATH = RUNTIME_DIR / "valley-shopee-notification-latest.json"
STOCK_SYNC_STATE_PATH = RUNTIME_DIR / "valley-stock-sync-state.json"
STOCK_SYNC_EVENTS_PATH = RUNTIME_DIR / "valley-stock-sync-events.jsonl"
PRODUCT_CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
PRODUCT_INTERACTIONS_PATH = RUNTIME_DIR / "valley-product-interactions.jsonl"
MOVE_TELEMETRY_PATH = RUNTIME_DIR / "move-telemetry.jsonl"
USER_AUTH_RUNTIME_PATH = RUNTIME_DIR / "valley-user-auth-runtime.json"
USER_AUTH_EVENTS_PATH = RUNTIME_DIR / "valley-user-auth-events.jsonl"
PRODUCT_MVP_MODULES = {"STOCK", "MARKETPLACE", "CHAT"}
PRODUCT_LIST_LIMIT = 80
MARKETPLACE_RUNTIME_PROVIDERS = {"mercado_livre", "amazon", "magalu", "shopee"}
SUPPLIER_RUNTIME_PROVIDERS = {"cjdropshipping", "aliexpress", "alibaba"}
AUTH_SESSION_TTL_SECONDS = 60 * 60 * 24 * 30
AUTH_LOGIN_LOCK_THRESHOLD = 5
AUTH_LOGIN_LOCK_SECONDS = 15 * 60
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


def utc_now_datetime() -> datetime:
    return datetime.now(timezone.utc)


def load_json_file(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.exists():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def load_jsonl_tail(path: Path | None, *, limit: int = 20) -> list[dict[str, Any]]:
    if path is None or not path.exists() or limit <= 0:
        return []

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []

    payload: list[dict[str, Any]] = []
    for raw_line in reversed(lines):
        line = raw_line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            payload.append(item)
        if len(payload) >= limit:
            break
    return payload


def write_json_file(path: Path | None, payload: Any) -> None:
    if path is None:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def load_env_file(path: Path | None) -> dict[str, str]:
    if path is None or not path.exists():
        return {}

    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}

    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and value:
            values[key] = value
    return values


def parse_iso_datetime(value: Any) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def pbkdf2_hash_password(password: str, *, salt: bytes | None = None, iterations: int = 310_000) -> str:
    effective_salt = salt or os.urandom(16)
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        effective_salt,
        iterations,
    )
    return "pbkdf2_sha256${}${}${}".format(
        iterations,
        base64.urlsafe_b64encode(effective_salt).decode("ascii").rstrip("="),
        base64.urlsafe_b64encode(derived).decode("ascii").rstrip("="),
    )


def pbkdf2_verify_password(password: str, encoded: str) -> bool:
    try:
        algo, iterations_text, salt_text, hash_text = str(encoded or "").split("$", 3)
        if algo != "pbkdf2_sha256":
            return False
        padding = "=" * (-len(salt_text) % 4)
        salt = base64.urlsafe_b64decode(salt_text + padding)
        expected_padding = "=" * (-len(hash_text) % 4)
        expected = base64.urlsafe_b64decode(hash_text + expected_padding)
        actual = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt,
            int(iterations_text),
        )
        return hmac.compare_digest(actual, expected)
    except (TypeError, ValueError, base64.binascii.Error):
        return False


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
    _runtime_catalog_index_path: Path | None = None
    _runtime_catalog_index_mtime_ns: int | None = None
    _runtime_catalog_index: dict[str, dict[str, Any]] = {}

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
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Valley-Session")
        super().end_headers()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        route = self._normalize_public_route(parsed.path)

        if route.startswith("/workspace/"):
            self.path = "/index.html"
            super().do_GET()
            return

        if route in ("/", "/index.html") and parsed.query:
            params = parse_qs(parsed.query)
            if params.get("code") or params.get("error") or params.get("error_description"):
                root_redirect = self._public_admin_base_url().rstrip("/")
                self._write_mercadolivre_callback(parsed.query, redirect_uri_override=root_redirect)
                return

        if route in ("/health", "/healthz", "/readyz", "/meta/runtime", "/api/runtime"):
            self._write_json(HTTPStatus.OK, self._runtime_payload())
            return

        if route == "/api/auth/session":
            self._write_json(
                HTTPStatus.OK,
                self._auth_session_payload(parse_qs(parsed.query)),
            )
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

        if route == "/api/module-runtime-snapshots":
            self._write_json(HTTPStatus.OK, self._module_runtime_snapshots_payload())
            return

        if route == "/api/admin-imported-products-pricing":
            self._write_json(HTTPStatus.OK, self._admin_imported_products_pricing_payload())
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

        if route == "/api/move-telemetry":
            self._write_json(HTTPStatus.OK, self._move_telemetry_payload())
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

        if route == "/api/checkout-health":
            refresh = str((parse_qs(parsed.query).get("refresh") or [""])[0]).strip().lower()
            self._write_json(
                HTTPStatus.OK,
                self._mercadopago_checkout_status_payload(
                    force_refresh=refresh in {"1", "true", "yes", "force"},
                ),
            )
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

        if route == "/integrations/amazon/notifications":
            self._write_marketplace_notification_probe(
                provider_key="amazon",
                route="/integrations/amazon/notifications",
                detail="Endpoint de notificacoes da Amazon SP-API ativo.",
            )
            return

        if route == "/integrations/aliexpress/notifications":
            self._write_aliexpress_notification_probe()
            return

        if route == "/integrations/alibaba/notifications":
            self._write_marketplace_notification_probe(
                provider_key="alibaba",
                route="/integrations/alibaba/notifications",
                detail="Endpoint de notificacoes do Alibaba ativo.",
            )
            return

        if route == "/integrations/magalu/notifications":
            self._write_marketplace_notification_probe(
                provider_key="magalu",
                route="/integrations/magalu/notifications",
                detail="Endpoint de notificacoes do Magalu ativo.",
            )
            return

        if route == "/integrations/cjdropshipping/notifications":
            self._write_cjdropshipping_notification_probe()
            return

        if route == "/integrations/shopee/notifications":
            self._write_marketplace_notification_probe(
                provider_key="shopee",
                route="/integrations/shopee/notifications",
                detail="Endpoint de notificacoes da Shopee ativo.",
            )
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

        if route == "/api/auth/register":
            self._write_json(*self._auth_register_response())
            return

        if route == "/api/auth/login":
            self._write_json(*self._auth_login_response())
            return

        if route == "/api/auth/logout":
            self._write_json(*self._auth_logout_response())
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

        if route == "/api/actions/move-telemetry":
            self._write_json(
                HTTPStatus.OK,
                self._write_move_telemetry_action(query),
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

        if route == "/api/checkout-health/refresh":
            self._write_json(
                HTTPStatus.OK,
                self._mercadopago_checkout_status_payload(force_refresh=True),
            )
            return

        if route == "/api/admin-imported-products-pricing":
            payload = self._read_json_body()
            if not isinstance(payload, dict):
                self._write_json(
                    HTTPStatus.BAD_REQUEST,
                    {
                        "status": "invalid_payload",
                        "service": "valley-admin-imported-products-pricing",
                        "detail": "Expected JSON object.",
                    },
                )
                return

            normalized_payload = {
                "status": "ok",
                "service": "valley-admin-imported-products-pricing",
                "updated_at_utc": utc_now_iso(),
                "supplier_defaults": payload.get("supplier_defaults")
                if isinstance(payload.get("supplier_defaults"), dict)
                else {},
                "item_overrides": payload.get("item_overrides")
                if isinstance(payload.get("item_overrides"), dict)
                else {},
            }
            write_json_file(ADMIN_IMPORTED_PRODUCTS_PRICING_PATH, normalized_payload)
            self._write_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "valley-admin-imported-products-pricing",
                    "saved_at_utc": normalized_payload["updated_at_utc"],
                    "path": str(ADMIN_IMPORTED_PRODUCTS_PRICING_PATH),
                    "supplier_defaults_total": len(normalized_payload["supplier_defaults"]),
                    "item_overrides_total": len(normalized_payload["item_overrides"]),
                },
            )
            return

        if route == "/integrations/mercadolivre/notifications":
            self._write_mercadolivre_notification_event()
            return

        if route == "/integrations/amazon/notifications":
            self._write_marketplace_notification_event(
                provider_key="amazon",
                path=AMAZON_NOTIFICATIONS_PATH,
                latest_path=AMAZON_NOTIFICATIONS_LATEST_PATH,
            )
            return

        if route == "/integrations/aliexpress/notifications":
            self._write_aliexpress_notification_event()
            return

        if route == "/integrations/alibaba/notifications":
            self._write_marketplace_notification_event(
                provider_key="alibaba",
                path=ALIBABA_NOTIFICATIONS_PATH,
                latest_path=ALIBABA_NOTIFICATIONS_LATEST_PATH,
            )
            return

        if route == "/integrations/magalu/notifications":
            self._write_marketplace_notification_event(
                provider_key="magalu",
                path=MAGALU_NOTIFICATIONS_PATH,
                latest_path=MAGALU_NOTIFICATIONS_LATEST_PATH,
            )
            return

        if route == "/integrations/cjdropshipping/notifications":
            self._write_cjdropshipping_notification_event()
            return

        if route == "/integrations/shopee/notifications":
            self._write_marketplace_notification_event(
                provider_key="shopee",
                path=SHOPEE_NOTIFICATIONS_PATH,
                latest_path=SHOPEE_NOTIFICATIONS_LATEST_PATH,
            )
            return

        if route == "/integrations/mercadopago/notifications":
            self._write_mercadopago_notification_event(parsed.query)
            return

        if route == "/api/move-telemetry":
            self._write_move_telemetry_event()
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

    def _auth_runtime_payload(self) -> dict[str, Any]:
        payload = load_json_file(USER_AUTH_RUNTIME_PATH) or {}
        if not isinstance(payload, dict):
            payload = {}
        users = payload.get("users") if isinstance(payload.get("users"), list) else []
        sessions = payload.get("sessions") if isinstance(payload.get("sessions"), list) else []
        return {
            "version": payload.get("version") or "v1",
            "users": users,
            "sessions": sessions,
        }

    def _write_auth_runtime_payload(self, payload: dict[str, Any]) -> None:
        normalized = {
            "version": str(payload.get("version") or "v1"),
            "users": payload.get("users") if isinstance(payload.get("users"), list) else [],
            "sessions": payload.get("sessions") if isinstance(payload.get("sessions"), list) else [],
        }
        write_json_file(USER_AUTH_RUNTIME_PATH, normalized)

    def _append_auth_event(self, kind: str, payload: dict[str, Any]) -> None:
        self._append_jsonl(
            USER_AUTH_EVENTS_PATH,
            {
                "kind": kind,
                "occurred_at_utc": utc_now_iso(),
                **payload,
            },
        )

    def _normalize_auth_identifier(self, value: Any) -> str:
        return str(value or "").strip().lower()

    def _slugify(self, value: Any) -> str:
        normalized = unicodedata.normalize("NFKD", str(value or "").strip().lower())
        ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
        slug = re.sub(r"[^a-z0-9]+", "-", ascii_only).strip("-")
        return slug or "valley"

    def _auth_session_token_from_request(self) -> str:
        auth_header = str(self.headers.get("Authorization") or "").strip()
        if auth_header.lower().startswith("bearer "):
            return auth_header[7:].strip()
        return str(self.headers.get("X-Valley-Session") or "").strip()

    def _user_has_admin_access(self, user: dict[str, Any]) -> bool:
        role = str(user.get("primary_role") or "").strip().upper()
        permissions = user.get("permissions")
        if isinstance(permissions, list) and "*" in permissions:
            return True
        return role in {"ADMIN", "SUPER_ADMIN", "OPS", "OPERATOR"}

    def _auth_public_user(self, user: dict[str, Any]) -> dict[str, Any]:
        merchant_profile = user.get("merchant_profile") if isinstance(user.get("merchant_profile"), dict) else None
        return {
            "user_id": str(user.get("user_id") or ""),
            "full_name": str(user.get("full_name") or ""),
            "display_name": str(user.get("display_name") or user.get("full_name") or ""),
            "email": str(user.get("email") or ""),
            "primary_role": str(user.get("primary_role") or "CUSTOMER"),
            "user_kind": str(user.get("user_kind") or "PF"),
            "account_status": str(user.get("account_status") or "ACTIVE"),
            "module_tier": str(user.get("module_tier") or "PRODUCT"),
            "permissions": user.get("permissions") if isinstance(user.get("permissions"), list) else [],
            "is_admin": self._user_has_admin_access(user),
            "merchant_slug": str(merchant_profile.get("slug") or "") if merchant_profile else "",
            "merchant_code": str(merchant_profile.get("merchant_code") or "") if merchant_profile else "",
        }

    def _auth_public_session(self, session: dict[str, Any], user: dict[str, Any], token: str = "") -> dict[str, Any]:
        expires_at = str(session.get("expires_at") or "")
        expires_dt = parse_iso_datetime(expires_at)
        return {
            "token": token,
            "session_id": str(session.get("session_id") or ""),
            "expires_at": expires_at,
            "expires_in_seconds": max(int((expires_dt - utc_now_datetime()).total_seconds()), 0)
            if expires_dt is not None
            else 0,
            "scope": str(session.get("scope") or "product"),
            "user": self._auth_public_user(user),
            "contract_tables": [
                "users",
                "auth_identities",
                "auth_sessions",
                "user_profiles",
                "merchant_profiles",
            ],
        }

    def _find_auth_user_by_identifier(
        self,
        users: list[dict[str, Any]],
        identifier: str,
    ) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
        normalized = self._normalize_auth_identifier(identifier)
        for user in users:
            if not isinstance(user, dict):
                continue
            identity = user.get("identity")
            if not isinstance(identity, dict):
                continue
            if self._normalize_auth_identifier(identity.get("login_identifier_normalized")) == normalized:
                return user, identity
        return None, None

    def _resolve_active_auth_session(
        self,
        *,
        scope: str = "product",
    ) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
        token = self._auth_session_token_from_request()
        if not token:
            return None, None

        payload = self._auth_runtime_payload()
        sessions = payload["sessions"]
        users = payload["users"]
        token_hash = sha256_hex(token)
        now = utc_now_datetime()
        touched = False
        matched_session: dict[str, Any] | None = None
        matched_user: dict[str, Any] | None = None
        for session in sessions:
            if not isinstance(session, dict):
                continue
            if str(session.get("session_token_hash") or "") != token_hash:
                continue
            if str(session.get("session_status") or "ACTIVE") != "ACTIVE":
                continue
            expires_at = parse_iso_datetime(session.get("expires_at"))
            if expires_at is not None and expires_at <= now:
                session["session_status"] = "EXPIRED"
                touched = True
                continue
            user_id = str(session.get("user_id") or "")
            for user in users:
                if isinstance(user, dict) and str(user.get("user_id") or "") == user_id:
                    matched_user = user
                    break
            if matched_user is None:
                session["session_status"] = "REVOKED"
                session["revoked_at"] = utc_now_iso()
                session["revoke_reason"] = "user_missing"
                touched = True
                continue
            if scope == "admin" and not self._user_has_admin_access(matched_user):
                return None, None
            session["last_seen_at"] = utc_now_iso()
            touched = True
            matched_session = session
            break

        if touched:
            self._write_auth_runtime_payload(payload)
        return matched_user, matched_session

    def _auth_session_payload(self, query: dict[str, list[str]]) -> dict[str, Any]:
        scope = str((query.get("scope") or ["product"])[0] or "product").strip().lower() or "product"
        user, session = self._resolve_active_auth_session(scope=scope)
        if user is None or session is None:
            return {
                "status": "anonymous",
                "service": "valley-auth",
                "scope": scope,
            }
        return {
            "status": "ok",
            "service": "valley-auth",
            "scope": scope,
            "session": self._auth_public_session(session, user),
        }

    def _auth_register_response(self) -> tuple[HTTPStatus, dict[str, Any]]:
        payload = self._read_json_body()
        if not isinstance(payload, dict):
            return HTTPStatus.BAD_REQUEST, {
                "status": "invalid_payload",
                "service": "valley-auth",
                "detail": "Expected JSON object.",
            }

        full_name = str(payload.get("full_name") or "").strip()
        display_name = str(payload.get("display_name") or full_name).strip()
        email = self._normalize_auth_identifier(payload.get("email"))
        password = str(payload.get("password") or "")
        role = str(payload.get("role") or "CUSTOMER").strip().upper()
        if role not in {"CUSTOMER", "MERCHANT"}:
            role = "CUSTOMER"

        if len(full_name) < 3 or "@" not in email or len(password) < 8:
            return HTTPStatus.BAD_REQUEST, {
                "status": "validation_error",
                "service": "valley-auth",
                "detail": "Informe nome, email valido e senha com ao menos 8 caracteres.",
            }

        runtime = self._auth_runtime_payload()
        users = runtime["users"]
        existing_user, _ = self._find_auth_user_by_identifier(users, email)
        if existing_user is not None:
            return HTTPStatus.CONFLICT, {
                "status": "identifier_exists",
                "service": "valley-auth",
                "detail": "Esse login ja esta cadastrado no Valley.",
            }

        user_id = str(uuid.uuid4())
        identity_id = str(uuid.uuid4())
        profile_id = str(uuid.uuid4())
        created_at = utc_now_iso()
        merchant_profile: dict[str, Any] | None = None
        if role == "MERCHANT":
            merchant_slug = self._slugify(display_name or full_name)
            merchant_profile = {
                "merchant_profile_id": str(uuid.uuid4()),
                "merchant_user_id": user_id,
                "profile_status": "ONBOARDING",
                "merchant_code": f"MER-{merchant_slug[:18].upper()}",
                "slug": merchant_slug,
                "display_name": display_name or full_name,
            }

        user = {
            "user_id": user_id,
            "user_kind": "PJ" if role == "MERCHANT" else "PF",
            "account_status": "ACTIVE",
            "full_name": full_name,
            "display_name": display_name or full_name,
            "email": email,
            "document_country": "BR",
            "document_type": "EMAIL_LOGIN",
            "document_number": email,
            "primary_role": role,
            "module_tier": "PRODUCT",
            "permissions": [],
            "created_at": created_at,
            "updated_at": created_at,
            "identity": {
                "identity_id": identity_id,
                "identity_type": "EMAIL_PASSWORD",
                "identity_status": "ACTIVE",
                "login_identifier": email,
                "login_identifier_normalized": email,
                "email": email,
                "password_hash": pbkdf2_hash_password(password),
                "password_algo": "pbkdf2_sha256_310000",
                "failed_login_count": 0,
                "locked_until": None,
                "verified_at": created_at,
                "last_authenticated_at": created_at,
            },
            "profile": {
                "user_profile_id": profile_id,
                "profile_status": "ACTIVE",
                "username": self._slugify(display_name or full_name),
                "display_handle": display_name or full_name,
                "preferences_json": {},
                "onboarding_completed_at": None,
            },
            "merchant_profile": merchant_profile,
        }
        users.append(user)
        runtime["users"] = users
        self._write_auth_runtime_payload(runtime)
        self._append_auth_event(
            "register",
            {
                "user_id": user_id,
                "identifier": email,
                "primary_role": role,
            },
        )
        return HTTPStatus.CREATED, {
            "status": "ok",
            "service": "valley-auth",
            "message": "Conta criada com sucesso.",
            "user": self._auth_public_user(user),
        }

    def _auth_login_response(self) -> tuple[HTTPStatus, dict[str, Any]]:
        payload = self._read_json_body()
        if not isinstance(payload, dict):
            return HTTPStatus.BAD_REQUEST, {
                "status": "invalid_payload",
                "service": "valley-auth",
                "detail": "Expected JSON object.",
            }

        identifier = self._normalize_auth_identifier(payload.get("identifier") or payload.get("email"))
        password = str(payload.get("password") or "")
        scope = str(payload.get("scope") or "product").strip().lower() or "product"
        runtime = self._auth_runtime_payload()
        users = runtime["users"]
        sessions = runtime["sessions"]
        user, identity = self._find_auth_user_by_identifier(users, identifier)

        if user is None or identity is None or not password:
            self._append_auth_event("login_failed", {"identifier": identifier, "scope": scope, "reason": "not_found"})
            return HTTPStatus.UNAUTHORIZED, {
                "status": "invalid_credentials",
                "service": "valley-auth",
                "detail": "Login ou senha invalidos.",
            }

        now = utc_now_datetime()
        locked_until = parse_iso_datetime(identity.get("locked_until"))
        if locked_until is not None and locked_until > now:
            return HTTPStatus.LOCKED, {
                "status": "locked",
                "service": "valley-auth",
                "detail": "Login temporariamente bloqueado por tentativas invalidas.",
                "locked_until": identity.get("locked_until"),
            }

        if not pbkdf2_verify_password(password, str(identity.get("password_hash") or "")):
            attempts = int(identity.get("failed_login_count") or 0) + 1
            identity["failed_login_count"] = attempts
            if attempts >= AUTH_LOGIN_LOCK_THRESHOLD:
                identity["locked_until"] = datetime.fromtimestamp(
                    now.timestamp() + AUTH_LOGIN_LOCK_SECONDS,
                    tz=timezone.utc,
                ).isoformat().replace("+00:00", "Z")
            user["updated_at"] = utc_now_iso()
            self._write_auth_runtime_payload(runtime)
            self._append_auth_event("login_failed", {"identifier": identifier, "scope": scope, "reason": "password"})
            return HTTPStatus.UNAUTHORIZED, {
                "status": "invalid_credentials",
                "service": "valley-auth",
                "detail": "Login ou senha invalidos.",
            }

        if scope == "admin" and not self._user_has_admin_access(user):
            self._append_auth_event("login_failed", {"identifier": identifier, "scope": scope, "reason": "forbidden"})
            return HTTPStatus.FORBIDDEN, {
                "status": "forbidden",
                "service": "valley-auth",
                "detail": "Esse usuario nao possui acesso ao admin.",
            }

        token = secrets.token_urlsafe(48)
        issued_at = utc_now_iso()
        expires_at = datetime.fromtimestamp(
            now.timestamp() + AUTH_SESSION_TTL_SECONDS,
            tz=timezone.utc,
        ).isoformat().replace("+00:00", "Z")

        identity["failed_login_count"] = 0
        identity["locked_until"] = None
        identity["last_authenticated_at"] = issued_at
        user["updated_at"] = issued_at

        session = {
            "session_id": str(uuid.uuid4()),
            "user_id": str(user.get("user_id") or ""),
            "identity_id": str(identity.get("identity_id") or ""),
            "session_status": "ACTIVE",
            "session_token_hash": sha256_hex(token),
            "scope": scope,
            "created_at": issued_at,
            "updated_at": issued_at,
            "last_seen_at": issued_at,
            "expires_at": expires_at,
            "metadata_json": {
                "user_agent": str(self.headers.get("User-Agent") or ""),
                "ip_address": str(self.headers.get("X-Forwarded-For") or self.client_address[0] or ""),
            },
        }
        sessions.append(session)
        runtime["sessions"] = sessions
        self._write_auth_runtime_payload(runtime)
        self._append_auth_event(
            "login_succeeded",
            {
                "user_id": user.get("user_id"),
                "identifier": identifier,
                "scope": scope,
                "session_id": session["session_id"],
            },
        )
        return HTTPStatus.OK, {
            "status": "ok",
            "service": "valley-auth",
            "message": "Sessao autenticada com sucesso.",
            "session": self._auth_public_session(session, user, token),
        }

    def _auth_logout_response(self) -> tuple[HTTPStatus, dict[str, Any]]:
        runtime = self._auth_runtime_payload()
        token = self._auth_session_token_from_request()
        if not token:
            return HTTPStatus.OK, {
                "status": "ok",
                "service": "valley-auth",
                "message": "Sessao local encerrada.",
            }

        token_hash = sha256_hex(token)
        revoked = False
        for session in runtime["sessions"]:
            if not isinstance(session, dict):
                continue
            if str(session.get("session_token_hash") or "") != token_hash:
                continue
            session["session_status"] = "REVOKED"
            session["revoked_at"] = utc_now_iso()
            session["revoke_reason"] = "logout"
            session["updated_at"] = utc_now_iso()
            revoked = True
            self._append_auth_event(
                "logout",
                {
                    "user_id": session.get("user_id"),
                    "session_id": session.get("session_id"),
                },
            )
            break
        if revoked:
            self._write_auth_runtime_payload(runtime)
        return HTTPStatus.OK, {
            "status": "ok",
            "service": "valley-auth",
            "message": "Sessao encerrada.",
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

    def _move_telemetry_payload(self) -> dict[str, Any]:
        return {
            "status": "ok",
            "service": "valley-move-telemetry",
            "generated_at_utc": utc_now_iso(),
            "events": load_jsonl_tail(MOVE_TELEMETRY_PATH, limit=24),
            "path": str(MOVE_TELEMETRY_PATH),
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

    def _admin_data_payload(self) -> dict[str, Any]:
        payload = load_json_file(self.data_path) or {}
        return payload if isinstance(payload, dict) else {}

    def _sanitize_stock_item(self, item: dict[str, Any]) -> dict[str, Any]:
        item_id = str(item.get("id") or "").strip()
        runtime_item = self._find_catalog_item(item_id) if item_id else None
        context_item = dict(runtime_item) if isinstance(runtime_item, dict) else {}
        context_item.update(item)

        sanitized = dict(context_item)
        for key in STOCK_INTERNAL_FIELDS:
            sanitized.pop(key, None)

        media_url = self._derive_media_url(context_item)
        checkout_url = self._derive_checkout_url(context_item)
        mercadopago_ready = self._mercadopago_checkout_ready(context_item)
        checkout_ready = mercadopago_ready or bool(checkout_url)
        provider_key = str(context_item.get("provider_key") or "").strip().lower()
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
            sanitized["cta_label"] = (
                "Abrir pagamento"
                if mercadopago_ready
                else ("Abrir oferta" if checkout_url else "Registrar interesse")
            )
            sanitized["checkout_ready"] = checkout_ready
            sanitized["payment_provider"] = (
                "mercado_pago"
                if mercadopago_ready
                else (provider_key if checkout_url else "")
            )
        return sanitized

    def _stock_public_sort_key(
        self,
        item: dict[str, Any],
        original_index: int,
    ) -> tuple[int, int, int, int, int, float, int]:
        item_id = str(item.get("id") or "").strip()
        runtime_item = self._find_catalog_item(item_id) if item_id else None
        context_item = dict(runtime_item) if isinstance(runtime_item, dict) else {}
        context_item.update(item)
        checkout_url = bool(self._derive_checkout_url(context_item))
        mercadopago_ready = self._mercadopago_checkout_ready(context_item)
        checkout_ready = mercadopago_ready or checkout_url
        provider_priority = int(context_item.get("provider_priority") or 0)
        offer_count = int(context_item.get("offer_count") or 0)
        stock_units = int(context_item.get("stock") or 0)
        price_brl = float(context_item.get("price_brl") or 0.0)
        return (
            -int(checkout_ready),
            -int(mercadopago_ready),
            -provider_priority,
            -offer_count,
            -stock_units,
            price_brl,
            original_index,
        )

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

    def _runtime_catalog_items_by_id(self) -> dict[str, dict[str, Any]]:
        path = self._preferred_stock_catalog_path()
        try:
            mtime_ns = path.stat().st_mtime_ns
        except FileNotFoundError:
            return {}

        handler_cls = type(self)
        if (
            handler_cls._runtime_catalog_index_path != path
            or handler_cls._runtime_catalog_index_mtime_ns != mtime_ns
        ):
            payload = load_json_file(path) or {}
            items = payload.get("items", []) if isinstance(payload, dict) else []
            handler_cls._runtime_catalog_index = {
                str(item.get("id") or "").strip(): item
                for item in items
                if isinstance(item, dict) and str(item.get("id") or "").strip()
            }
            handler_cls._runtime_catalog_index_path = path
            handler_cls._runtime_catalog_index_mtime_ns = mtime_ns
        return handler_cls._runtime_catalog_index

    def _catalog_items_for_admin(
        self,
        *,
        include_stock_internal: bool = True,
    ) -> list[dict[str, Any]]:
        catalog = load_json_file(PRODUCT_CATALOG_PATH) or {}
        public_items = catalog.get("items", []) if isinstance(catalog, dict) else []
        combined: list[dict[str, Any]] = []
        runtime_catalog = self._load_stock_runtime_catalog()
        runtime_items = runtime_catalog.get("items", []) if isinstance(runtime_catalog, dict) else []

        if isinstance(runtime_items, list):
            for item in runtime_items:
                if not isinstance(item, dict) or item.get("module_id") != "STOCK":
                    continue
                combined.append(dict(item) if include_stock_internal else self._sanitize_stock_item(item))
        else:
            for item in public_items:
                if isinstance(item, dict) and item.get("module_id") == "STOCK":
                    combined.append(dict(item))

        for item in public_items:
            if isinstance(item, dict) and item.get("module_id") != "STOCK":
                combined.append(dict(item))

        return combined

    def _pricing_defaults_by_provider(self) -> dict[str, dict[str, float]]:
        saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        items = saved if isinstance(saved, list) else []
        defaults: dict[str, dict[str, float]] = {}
        for item in items:
            if not isinstance(item, dict):
                continue
            provider_key = str(item.get("key") or "").strip().lower()
            if not provider_key:
                continue
            defaults[provider_key] = {
                "target_net_revenue_pct": float(item.get("marginFloorPct") or 12.0),
                "platform_fee_pct": 8.0,
                "operational_fee_pct": 3.0,
                "marketing_fee_pct": 2.0,
                "tax_pct": 6.0,
            }
        return defaults

    def _admin_imported_products_pricing_state(self) -> dict[str, Any]:
        payload = load_json_file(ADMIN_IMPORTED_PRODUCTS_PRICING_PATH) or {}
        if not isinstance(payload, dict):
            return {"supplier_defaults": {}, "item_overrides": {}}
        return {
            "supplier_defaults": payload.get("supplier_defaults")
            if isinstance(payload.get("supplier_defaults"), dict)
            else {},
            "item_overrides": payload.get("item_overrides")
            if isinstance(payload.get("item_overrides"), dict)
            else {},
            "updated_at_utc": payload.get("updated_at_utc"),
        }

    def _pricing_controls_for_item(
        self,
        *,
        provider_key: str,
        supplier_key: str,
        item_id: str,
        pricing_state: dict[str, Any],
        provider_defaults: dict[str, dict[str, float]],
    ) -> dict[str, Any]:
        base_defaults = {
            "target_net_revenue_pct": 12.0,
            "platform_fee_pct": 8.0,
            "operational_fee_pct": 3.0,
            "marketing_fee_pct": 2.0,
            "tax_pct": 6.0,
            "notes": "",
        }
        merged = {
            **base_defaults,
            **provider_defaults.get(provider_key, {}),
            **(
                pricing_state.get("supplier_defaults", {}).get(supplier_key, {})
                if isinstance(pricing_state.get("supplier_defaults"), dict)
                else {}
            ),
            **(
                pricing_state.get("item_overrides", {}).get(item_id, {})
                if isinstance(pricing_state.get("item_overrides"), dict)
                else {}
            ),
        }
        return {
            "target_net_revenue_pct": float(merged.get("target_net_revenue_pct") or 0.0),
            "platform_fee_pct": float(merged.get("platform_fee_pct") or 0.0),
            "operational_fee_pct": float(merged.get("operational_fee_pct") or 0.0),
            "marketing_fee_pct": float(merged.get("marketing_fee_pct") or 0.0),
            "tax_pct": float(merged.get("tax_pct") or 0.0),
            "notes": str(merged.get("notes") or ""),
        }

    def _title_signature_tokens(self, value: Any) -> list[str]:
        normalized = unicodedata.normalize("NFKD", str(value or "").lower())
        ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
        tokens = re.findall(r"[a-z0-9]+", ascii_only)
        stopwords = {
            "a",
            "an",
            "and",
            "com",
            "da",
            "de",
            "do",
            "for",
            "in",
            "new",
            "of",
            "on",
            "or",
            "para",
            "pro",
            "the",
            "valley",
            "wireless",
            "bluetooth",
        }
        deduped: list[str] = []
        for token in tokens:
            if len(token) <= 2 or token in stopwords:
                continue
            if token not in deduped:
                deduped.append(token)
        return deduped[:10]

    def _publication_signature(self, category: str, title: Any) -> str:
        category_tokens = self._title_signature_tokens(category)
        title_tokens = self._title_signature_tokens(title)
        signature_tokens = title_tokens[:8] if title_tokens else category_tokens[:4]
        category_label = " ".join(category_tokens[:4]) or "sem-categoria"
        signature_label = " ".join(signature_tokens) or "sem-assinatura"
        return f"{category_label}|{signature_label}"

    def _title_overlap_score(self, left: Any, right: Any) -> float:
        left_tokens = set(self._title_signature_tokens(left))
        right_tokens = set(self._title_signature_tokens(right))
        if not left_tokens or not right_tokens:
            return 0.0
        return len(left_tokens & right_tokens) / max(len(left_tokens), len(right_tokens))

    def _marketplace_status_by_key(self) -> dict[str, dict[str, Any]]:
        payload = load_json_file(DROPSHIPPING_STATUS_PATH) or {}
        providers = payload.get("providers", []) if isinstance(payload, dict) else []
        return {
            str(provider.get("key") or "").strip(): provider
            for provider in providers
            if isinstance(provider, dict) and str(provider.get("key") or "").strip()
        }

    def _marketplace_policy_by_key(self) -> dict[str, dict[str, Any]]:
        saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        items = saved if isinstance(saved, list) else []
        policies: dict[str, dict[str, Any]] = {}
        for item in items:
            if not isinstance(item, dict):
                continue
            provider_key = str(item.get("key") or "").strip().lower()
            if not provider_key:
                continue
            policies[provider_key] = {
                "enabled": bool(item.get("enabled")),
                "environment": str(item.get("environment") or "sandbox").strip().lower() or "sandbox",
                "siteCode": str(item.get("siteCode") or "").strip(),
                "authMode": str(item.get("authMode") or "oauth2").strip(),
                "marginFloorPct": float(item.get("marginFloorPct") or 12.0),
                "importCatalog": bool(item.get("importCatalog", True)),
                "syncOrders": bool(item.get("syncOrders", True)),
                "syncInventory": bool(item.get("syncInventory", True)),
                "syncPricing": bool(item.get("syncPricing", True)),
                "stockModuleEnabled": bool(item.get("stockModuleEnabled", item.get("syncInventory", True))),
                "sandboxEnabled": bool(item.get("sandboxEnabled", True)),
                "productionEnabled": bool(
                    item.get(
                        "productionEnabled",
                        str(item.get("environment") or "").strip().lower() == "production",
                    )
                ),
                "importCategories": bool(item.get("importCategories", True)),
                "publishApprovedOnly": bool(item.get("publishApprovedOnly", True)),
                "requireRetailAdvantage": bool(item.get("requireRetailAdvantage", True)),
                "requireLiquidityCheck": bool(item.get("requireLiquidityCheck", True)),
                "allowScrapingFallback": bool(item.get("allowScrapingFallback")),
                "blockExternalAiLookup": bool(item.get("blockExternalAiLookup", True)),
            }
        return policies

    def _find_catalog_item(self, item_id: str) -> dict[str, Any] | None:
        normalized_item_id = str(item_id or "").strip()
        if not normalized_item_id:
            return None

        runtime_index = self._runtime_catalog_items_by_id()
        runtime_match = runtime_index.get(normalized_item_id)
        if isinstance(runtime_match, dict):
            return runtime_match

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
        for candidate in (
            item.get("video_url"),
            item.get("video_external_url"),
            item.get("external_video_url"),
            item.get("media_url"),
            item.get("demo_video_url"),
        ):
            video_url = self._first_string_value(candidate)
            if self._is_http_url(video_url):
                return video_url

        source_permalink = str(item.get("source_permalink") or "").strip()
        if (
            self._is_http_url(source_permalink)
            and (
                str(item.get("video_url") or "").strip()
                or int(item.get("video_count") or 0) > 0
            )
        ):
            return source_permalink
        return ""

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
            raw_items = [
                item
                for item in items
                if isinstance(item, dict) and item.get("module_id") in active_modules
            ]
            filtered_items = [
                self._sanitize_stock_item(item)
                if isinstance(item, dict) and item.get("module_id") == "STOCK"
                else item
                for item in raw_items
            ]
            filtered_items = [
                item
                for _, item in sorted(
                    enumerate(filtered_items),
                    key=lambda pair: (
                        self._stock_public_sort_key(raw_items[pair[0]], pair[0])
                        if isinstance(raw_items[pair[0]], dict)
                        and raw_items[pair[0]].get("module_id") == "STOCK"
                        else (0, 0, 0, 0, 0, 0.0, pair[0])
                    ),
                )
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
        items = self._catalog_items_for_admin(include_stock_internal=True)

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
            merchant_name = str(
                raw_item.get("supplier_name")
                or raw_item.get("merchant_name")
                or "Origem nao informada"
            )
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

    def _admin_imported_products_pricing_payload(self) -> dict[str, Any]:
        runtime_catalog = self._load_stock_runtime_catalog()
        items = runtime_catalog.get("items", []) if isinstance(runtime_catalog, dict) else []
        if not isinstance(items, list) or not items:
            return {
                "status": "missing",
                "service": "valley-admin-imported-products-pricing",
                "generated_at_utc": utc_now_iso(),
                "items_total": 0,
                "supplier_summary": [],
                "items": [],
                "supplier_defaults": {},
                "item_overrides": {},
                "publication_summary": {
                    "supplier_items_total": 0,
                    "approved_total": 0,
                    "review_total": 0,
                    "do_not_publish_total": 0,
                    "benchmark_reference_total": 0,
                    "top_reasons": [],
                },
            }

        pricing_state = self._admin_imported_products_pricing_state()
        provider_defaults = self._pricing_defaults_by_provider()
        provider_policies = self._marketplace_policy_by_key()

        def as_float(value: Any) -> float:
            try:
                return float(value or 0)
            except (TypeError, ValueError):
                return 0.0

        def category_key(value: Any) -> str:
            tokens = self._title_signature_tokens(value)
            return "|".join(tokens[:4]) or str(value or "").strip().lower() or "sem-categoria"

        def liquidity_score(raw_item: dict[str, Any]) -> float:
            offer_count = max(as_float(raw_item.get("offer_count")), 0.0)
            stock_units = max(as_float(raw_item.get("stock")), 0.0)
            relevance = max(
                as_float(raw_item.get("source_relevance_score") or raw_item.get("offer_count")),
                0.0,
            )
            score = (
                math.log10(offer_count + 1.0) * 18.0
                + math.log10(stock_units + 1.0) * 14.0
                + (min(relevance, offer_count or relevance or 1.0) / max(relevance, offer_count, 1.0))
                * 8.0
            )
            if raw_item.get("shipping_free"):
                score += 6.0
            if raw_item.get("tracking_capable"):
                score += 8.0
            return round(min(score, 100.0), 2)

        default_policy = {
            "enabled": True,
            "environment": "production",
            "siteCode": "",
            "authMode": "oauth2",
            "marginFloorPct": 12.0,
            "importCatalog": True,
            "syncOrders": True,
            "syncInventory": True,
            "syncPricing": True,
            "stockModuleEnabled": True,
            "sandboxEnabled": True,
            "productionEnabled": True,
            "importCategories": True,
            "publishApprovedOnly": True,
            "requireRetailAdvantage": True,
            "requireLiquidityCheck": True,
            "allowScrapingFallback": False,
            "blockExternalAiLookup": True,
        }
        reason_labels = {
            "benchmark_reference": "Item usado como benchmark de varejo para homologar preço de importação.",
            "catalog_import_disabled": "Importação de catálogo está desligada para este fornecedor.",
            "category_import_disabled": "Importação de categorias está desligada para este fornecedor.",
            "duplicate_loser": "Outro fornecedor venceu a disputa por menor custo e maior liquidez.",
            "low_liquidity": "Liquidez abaixo do piso operacional definido para publicação.",
            "no_margin": "A precificação atual não gera margem líquida positiva.",
            "no_market_benchmark": "Não existe benchmark confiável em marketplace para validar vantagem de varejo.",
            "no_stock": "Fornecedor sem estoque confirmado para esta oferta.",
            "production_mode_disabled": "Modo de produção desligado para este fornecedor.",
            "retail_price_not_advantageous": "O preço sugerido não fica abaixo do varejo de marketplace.",
            "sandbox_mode_disabled": "Modo sandbox desligado; manter homologação e produção ativas em paralelo.",
            "stock_module_disabled": "Módulo STOCK desativado para este fornecedor.",
        }

        supplier_rollup: dict[str, dict[str, Any]] = defaultdict(
            lambda: {
                "supplier_key": "",
                "supplier_name": "",
                "provider_key": "",
                "supplier_type": "",
                "items_total": 0,
                "inventory_units": 0.0,
                "base_cost_value_brl": 0.0,
                "suggested_revenue_value_brl": 0.0,
                "estimated_net_revenue_value_brl": 0.0,
                "approved_total": 0,
                "review_total": 0,
                "do_not_publish_total": 0,
            }
        )
        response_items: list[dict[str, Any]] = []
        grouped_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
        marketplace_rows_by_category: dict[str, list[dict[str, Any]]] = defaultdict(list)

        for raw_item in items:
            if not isinstance(raw_item, dict) or raw_item.get("module_id") != "STOCK":
                continue

            item_id = str(raw_item.get("id") or "").strip()
            provider_key = str(raw_item.get("provider_key") or "catalog").strip().lower()
            provider_policy = {
                **default_policy,
                **provider_policies.get(provider_key, {}),
            }
            supplier_name = str(
                raw_item.get("supplier_name")
                or raw_item.get("merchant_name")
                or provider_key
                or "Origem nao informada"
            ).strip()
            supplier_key = f"{provider_key or 'catalog'}::{supplier_name.lower().replace(' ', '_')}"
            controls = self._pricing_controls_for_item(
                provider_key=provider_key,
                supplier_key=supplier_key,
                item_id=item_id,
                pricing_state=pricing_state,
                provider_defaults=provider_defaults,
            )

            base_cost_brl = as_float(raw_item.get("price_brl"))
            stock_units = as_float(raw_item.get("stock"))
            fees_pct_total = (
                controls["platform_fee_pct"]
                + controls["operational_fee_pct"]
                + controls["marketing_fee_pct"]
                + controls["tax_pct"]
            )
            target_pct_total = fees_pct_total + controls["target_net_revenue_pct"]
            denominator = max(0.05, 1 - (target_pct_total / 100))
            suggested_sale_price_brl = base_cost_brl / denominator if denominator else base_cost_brl
            estimated_fees_brl = suggested_sale_price_brl * (fees_pct_total / 100)
            estimated_net_revenue_brl = max(
                suggested_sale_price_brl - base_cost_brl - estimated_fees_brl,
                0.0,
            )
            estimated_net_revenue_pct = (
                (estimated_net_revenue_brl / suggested_sale_price_brl) * 100
                if suggested_sale_price_brl > 0
                else 0.0
            )
            publication_signature = self._publication_signature(
                str(raw_item.get("category") or ""),
                raw_item.get("title"),
            )
            row_liquidity_score = liquidity_score(raw_item)
            normalized_category_key = category_key(raw_item.get("category"))
            is_marketplace_reference = provider_key in MARKETPLACE_RUNTIME_PROVIDERS

            supplier_entry = supplier_rollup[supplier_key]
            supplier_entry["supplier_key"] = supplier_key
            supplier_entry["supplier_name"] = supplier_name
            supplier_entry["provider_key"] = provider_key
            supplier_entry["supplier_type"] = str(raw_item.get("supplier_type") or "").strip()
            supplier_entry["items_total"] += 1
            supplier_entry["inventory_units"] += stock_units
            supplier_entry["base_cost_value_brl"] += base_cost_brl * stock_units
            supplier_entry["suggested_revenue_value_brl"] += suggested_sale_price_brl * stock_units
            supplier_entry["estimated_net_revenue_value_brl"] += estimated_net_revenue_brl * stock_units

            row = {
                "id": item_id,
                "title": str(raw_item.get("title") or "Produto sem titulo"),
                "brand": str(raw_item.get("brand") or ""),
                "category": str(raw_item.get("category") or ""),
                "collection_label": str(raw_item.get("collection_label") or ""),
                "price_band": str(raw_item.get("price_band") or ""),
                "availability_label": str(raw_item.get("availability_label") or ""),
                "provider_key": provider_key,
                "provider_status": str(raw_item.get("provider_status") or ""),
                "supplier_key": supplier_key,
                "supplier_name": supplier_name,
                "supplier_type": str(raw_item.get("supplier_type") or ""),
                "supplier_model": str(raw_item.get("supplier_model") or ""),
                "merchant_name": str(raw_item.get("merchant_name") or ""),
                "channel_label": str(raw_item.get("channel_label") or ""),
                "google_product_category_path": str(
                    raw_item.get("google_product_category_path")
                    or raw_item.get("google_product_category")
                    or ""
                ),
                "source_permalink": str(raw_item.get("source_permalink") or ""),
                "source_product_id": str(raw_item.get("source_product_id") or ""),
                "source_item_id": str(raw_item.get("source_item_id") or ""),
                "shipping_free": bool(raw_item.get("shipping_free")),
                "stock": round(stock_units, 2),
                "base_cost_brl": round(base_cost_brl, 2),
                "inventory_cost_brl": round(base_cost_brl * stock_units, 2),
                "offer_count": int(as_float(raw_item.get("offer_count"))),
                "source_relevance_score": round(
                    as_float(raw_item.get("source_relevance_score") or raw_item.get("offer_count")),
                    2,
                ),
                "provider_priority": int(raw_item.get("provider_priority") or 0),
                "liquidity_score": row_liquidity_score,
                "suggested_sale_price_brl": round(suggested_sale_price_brl, 2),
                "estimated_fees_brl": round(estimated_fees_brl, 2),
                "estimated_net_revenue_brl": round(estimated_net_revenue_brl, 2),
                "estimated_net_revenue_pct": round(estimated_net_revenue_pct, 2),
                "estimated_inventory_net_revenue_brl": round(
                    estimated_net_revenue_brl * stock_units,
                    2,
                ),
                "target_net_revenue_pct": round(controls["target_net_revenue_pct"], 2),
                "platform_fee_pct": round(controls["platform_fee_pct"], 2),
                "operational_fee_pct": round(controls["operational_fee_pct"], 2),
                "marketing_fee_pct": round(controls["marketing_fee_pct"], 2),
                "tax_pct": round(controls["tax_pct"], 2),
                "notes": controls["notes"],
                "enabled": bool(provider_policy["enabled"]),
                "environment": str(provider_policy["environment"]),
                "site_code": str(provider_policy["siteCode"]),
                "auth_mode": str(provider_policy["authMode"]),
                "stock_module_enabled": bool(provider_policy["stockModuleEnabled"]),
                "sandbox_enabled": bool(provider_policy["sandboxEnabled"]),
                "production_enabled": bool(provider_policy["productionEnabled"]),
                "import_catalog": bool(provider_policy["importCatalog"]),
                "import_categories": bool(provider_policy["importCategories"]),
                "publish_approved_only": bool(provider_policy["publishApprovedOnly"]),
                "require_retail_advantage": bool(provider_policy["requireRetailAdvantage"]),
                "require_liquidity_check": bool(provider_policy["requireLiquidityCheck"]),
                "allow_scraping_fallback": bool(provider_policy["allowScrapingFallback"]),
                "block_external_ai_lookup": bool(provider_policy["blockExternalAiLookup"]),
                "publication_signature": publication_signature,
                "duplicate_group_key": publication_signature,
                "duplicate_group_size": 1,
                "duplicate_winner_item_id": item_id,
                "duplicate_winner_supplier_name": supplier_name,
                "benchmark_provider_key": "",
                "benchmark_retail_price_brl": None,
                "benchmark_title": "",
                "benchmark_similarity_score": 0.0,
                "price_gap_to_benchmark_brl": None,
                "publication_status": "",
                "publication_status_label": "",
                "publication_reason_codes": [],
                "publication_reasons": [],
                "is_marketplace_reference": is_marketplace_reference,
                "_category_key": normalized_category_key,
                "tags": [
                    value
                    for value in raw_item.get("tags", [])
                    if isinstance(value, str)
                ],
            }
            response_items.append(row)
            grouped_rows[publication_signature].append(row)
            if is_marketplace_reference:
                marketplace_rows_by_category[normalized_category_key].append(row)

        def supplier_selection_key(row: dict[str, Any]) -> tuple[Any, ...]:
            return (
                float(row.get("base_cost_brl") or 0.0),
                -float(row.get("liquidity_score") or 0.0),
                -float(row.get("stock") or 0.0),
                -int(row.get("provider_priority") or 0),
                str(row.get("id") or ""),
            )

        review_reason_rollup: dict[str, int] = defaultdict(int)
        approved_total = 0
        review_total = 0
        do_not_publish_total = 0
        benchmark_reference_total = 0

        for signature, rows_in_group in grouped_rows.items():
            supplier_rows = [row for row in rows_in_group if not row.get("is_marketplace_reference")]
            marketplace_rows = [row for row in rows_in_group if row.get("is_marketplace_reference")]
            supplier_winner = min(supplier_rows, key=supplier_selection_key) if supplier_rows else None

            for row in rows_in_group:
                row["duplicate_group_key"] = signature
                row["duplicate_group_size"] = len(supplier_rows) if supplier_rows else len(rows_in_group)
                if supplier_winner is not None:
                    row["duplicate_winner_item_id"] = str(supplier_winner.get("id") or "")
                    row["duplicate_winner_supplier_name"] = str(supplier_winner.get("supplier_name") or "")

            for row in supplier_rows:
                benchmark: dict[str, Any] | None = None
                benchmark_similarity = 0.0

                if marketplace_rows:
                    benchmark = min(
                        marketplace_rows,
                        key=lambda candidate: (
                            float(candidate.get("base_cost_brl") or 0.0),
                            -float(candidate.get("liquidity_score") or 0.0),
                            -float(candidate.get("stock") or 0.0),
                            str(candidate.get("title") or ""),
                        ),
                    )
                    benchmark_similarity = max(
                        self._title_overlap_score(row.get("title"), benchmark.get("title")),
                        0.82,
                    )
                else:
                    fuzzy_candidates: list[tuple[dict[str, Any], float]] = []
                    for candidate in marketplace_rows_by_category.get(str(row.get("_category_key") or ""), []):
                        similarity = self._title_overlap_score(row.get("title"), candidate.get("title"))
                        if similarity >= 0.46:
                            fuzzy_candidates.append((candidate, similarity))
                    if fuzzy_candidates:
                        benchmark, benchmark_similarity = min(
                            fuzzy_candidates,
                            key=lambda pair: (
                                float(pair[0].get("base_cost_brl") or 0.0),
                                -pair[1],
                                -float(pair[0].get("liquidity_score") or 0.0),
                                -float(pair[0].get("stock") or 0.0),
                                str(pair[0].get("title") or ""),
                            ),
                        )

                price_gap = None
                if benchmark is not None:
                    price_gap = round(
                        float(benchmark.get("base_cost_brl") or 0.0)
                        - float(row.get("suggested_sale_price_brl") or 0.0),
                        2,
                    )
                    row["benchmark_provider_key"] = str(benchmark.get("provider_key") or "")
                    row["benchmark_retail_price_brl"] = round(float(benchmark.get("base_cost_brl") or 0.0), 2)
                    row["benchmark_title"] = str(benchmark.get("title") or "")
                    row["benchmark_similarity_score"] = round(benchmark_similarity, 2)
                    row["price_gap_to_benchmark_brl"] = price_gap

                blocking_codes: list[str] = []
                review_codes: list[str] = []

                if not row.get("stock_module_enabled"):
                    blocking_codes.append("stock_module_disabled")
                if not row.get("production_enabled"):
                    blocking_codes.append("production_mode_disabled")
                if not row.get("sandbox_enabled"):
                    review_codes.append("sandbox_mode_disabled")
                if not row.get("import_catalog"):
                    review_codes.append("catalog_import_disabled")
                if not row.get("import_categories"):
                    review_codes.append("category_import_disabled")
                if float(row.get("stock") or 0.0) <= 0:
                    blocking_codes.append("no_stock")
                if float(row.get("estimated_net_revenue_brl") or 0.0) <= 0:
                    blocking_codes.append("no_margin")
                if row.get("require_liquidity_check") and float(row.get("liquidity_score") or 0.0) < 35.0:
                    review_codes.append("low_liquidity")
                if supplier_winner is not None and len(supplier_rows) > 1 and row.get("id") != supplier_winner.get("id"):
                    blocking_codes.append("duplicate_loser")
                if row.get("require_retail_advantage"):
                    if benchmark is None:
                        review_codes.append("no_market_benchmark")
                    elif price_gap is not None and price_gap <= 0:
                        blocking_codes.append("retail_price_not_advantageous")

                reason_codes = list(dict.fromkeys(blocking_codes + review_codes))
                row["publication_reason_codes"] = reason_codes
                row["publication_reasons"] = [reason_labels[code] for code in reason_codes if code in reason_labels]

                if blocking_codes:
                    row["publication_status"] = "do_not_publish"
                    row["publication_status_label"] = "Nao publicar"
                    do_not_publish_total += 1
                elif review_codes:
                    row["publication_status"] = "review"
                    row["publication_status_label"] = "Revisao"
                    review_total += 1
                else:
                    row["publication_status"] = "approved"
                    row["publication_status_label"] = "Aprovado"
                    approved_total += 1

                supplier_rollup[str(row.get("supplier_key") or "")][row["publication_status"] + "_total"] += 1
                if row["publication_status"] in {"review", "do_not_publish"}:
                    for code in reason_codes:
                        review_reason_rollup[code] += 1

        for row in response_items:
            if row.get("is_marketplace_reference"):
                row["publication_status"] = "benchmark_reference"
                row["publication_status_label"] = "Benchmark"
                row["publication_reason_codes"] = ["benchmark_reference"]
                row["publication_reasons"] = [reason_labels["benchmark_reference"]]
                benchmark_reference_total += 1

        publication_status_order = {
            "do_not_publish": 0,
            "review": 1,
            "approved": 2,
            "benchmark_reference": 3,
        }
        supplier_summary = []
        for entry in supplier_rollup.values():
            items_total = int(entry["items_total"])
            avg_cost = (
                entry["base_cost_value_brl"] / entry["inventory_units"]
                if entry["inventory_units"]
                else 0.0
            )
            supplier_summary.append(
                {
                    "supplier_key": entry["supplier_key"],
                    "supplier_name": entry["supplier_name"],
                    "provider_key": entry["provider_key"],
                    "supplier_type": entry["supplier_type"],
                    "items_total": items_total,
                    "inventory_units": round(entry["inventory_units"], 2),
                    "average_base_cost_brl": round(avg_cost, 2),
                    "inventory_cost_value_brl": round(entry["base_cost_value_brl"], 2),
                    "suggested_revenue_value_brl": round(entry["suggested_revenue_value_brl"], 2),
                    "estimated_net_revenue_value_brl": round(entry["estimated_net_revenue_value_brl"], 2),
                    "approved_total": int(entry["approved_total"]),
                    "review_total": int(entry["review_total"]),
                    "do_not_publish_total": int(entry["do_not_publish_total"]),
                }
            )

        supplier_summary.sort(
            key=lambda item: (
                -float(item["suggested_revenue_value_brl"]),
                str(item["supplier_name"]),
            )
        )
        response_items.sort(
            key=lambda item: (
                publication_status_order.get(str(item.get("publication_status") or ""), 9),
                str(item["supplier_name"]),
                str(item["category"]),
                -float(item["estimated_inventory_net_revenue_brl"]),
                str(item["title"]),
            )
        )
        top_reasons = [
            {
                "code": code,
                "label": reason_labels.get(code, code),
                "items_total": int(total),
            }
            for code, total in sorted(
                review_reason_rollup.items(),
                key=lambda item: (-item[1], item[0]),
            )[:8]
        ]

        return {
            "status": "ok",
            "service": "valley-admin-imported-products-pricing",
            "generated_at_utc": utc_now_iso(),
            "locale": runtime_catalog.get("translation_locale") if isinstance(runtime_catalog, dict) else "pt-BR",
            "providers_active": runtime_catalog.get("providers_active") if isinstance(runtime_catalog, dict) else [],
            "provider_counts": runtime_catalog.get("provider_counts") if isinstance(runtime_catalog, dict) else {},
            "categories_total": runtime_catalog.get("categories_total") if isinstance(runtime_catalog, dict) else 0,
            "items_total": len(response_items),
            "supplier_summary": supplier_summary,
            "items": [
                {key: value for key, value in item.items() if not str(key).startswith("_")}
                for item in response_items
            ],
            "supplier_defaults": pricing_state.get("supplier_defaults", {}),
            "item_overrides": pricing_state.get("item_overrides", {}),
            "updated_at_utc": pricing_state.get("updated_at_utc"),
            "publication_summary": {
                "supplier_items_total": approved_total + review_total + do_not_publish_total,
                "approved_total": approved_total,
                "review_total": review_total,
                "do_not_publish_total": do_not_publish_total,
                "benchmark_reference_total": benchmark_reference_total,
                "top_reasons": top_reasons,
            },
        }

    def _admin_integrations_payload(self) -> dict[str, Any]:
        saved = load_json_file(ADMIN_INTEGRATIONS_PATH)
        items = saved if isinstance(saved, list) else []
        runtime_status = self._marketplace_status_by_key()
        secrets_payload = self._provider_secrets_payload()
        enriched_items: list[dict[str, Any]] = []

        for item in items:
            if not isinstance(item, dict):
                continue

            provider_key = str(item.get("key") or "").strip().lower()
            runtime_entry = runtime_status.get(provider_key, {})
            provider_secrets = (
                secrets_payload.get(provider_key)
                if isinstance(secrets_payload.get(provider_key), dict)
                else {}
            )
            merged = dict(item)
            merged["stockModuleEnabled"] = bool(
                merged.get("stockModuleEnabled", merged.get("syncInventory", True))
            )
            merged["sandboxEnabled"] = bool(merged.get("sandboxEnabled", True))
            merged["productionEnabled"] = bool(
                merged.get(
                    "productionEnabled",
                    str(merged.get("environment") or "").strip().lower() == "production",
                )
            )
            merged["importCategories"] = bool(merged.get("importCategories", True))
            merged["publishApprovedOnly"] = bool(merged.get("publishApprovedOnly", True))
            merged["requireRetailAdvantage"] = bool(merged.get("requireRetailAdvantage", True))
            merged["requireLiquidityCheck"] = bool(merged.get("requireLiquidityCheck", True))
            merged["runtimeStatus"] = str(runtime_entry.get("status") or "")
            merged["runtimePending"] = (
                runtime_entry.get("pending")
                if isinstance(runtime_entry.get("pending"), list)
                else []
            )
            merged["runtimeEvidence"] = (
                runtime_entry.get("runtimeEvidence")
                if isinstance(runtime_entry.get("runtimeEvidence"), list)
                else []
            )
            merged["runtimeActive"] = str(runtime_entry.get("status") or "").strip() == "active"
            merged["secretsPresence"] = {
                "client": bool(
                    provider_secrets.get("clientId") or provider_secrets.get("clientSecret")
                ),
                "accessToken": bool(
                    provider_secrets.get("accessToken") or provider_secrets.get("access_token")
                ),
                "refreshToken": bool(
                    provider_secrets.get("refreshToken") or provider_secrets.get("refresh_token")
                ),
                "sellerId": bool(provider_secrets.get("sellerId") or provider_secrets.get("seller_id")),
                "operatorLogin": bool(
                    provider_secrets.get("username") and provider_secrets.get("password")
                ),
            }
            enriched_items.append(merged)

        enriched_items.sort(key=lambda item: str(item.get("label") or item.get("key") or ""))
        active_total = sum(1 for item in enriched_items if item.get("enabled"))
        production_total = sum(
            1
            for item in enriched_items
            if item.get("enabled") and str(item.get("environment") or "").lower() == "production"
        )
        stock_active_total = sum(1 for item in enriched_items if item.get("stockModuleEnabled"))
        pending_runtime_total = sum(1 for item in enriched_items if item.get("runtimePending"))
        return {
            "status": "ok",
            "service": "valley-admin",
            "generated_at_utc": utc_now_iso(),
            "path": str(ADMIN_INTEGRATIONS_PATH),
            "public_admin_url": self._public_admin_base_url(),
            "public_product_url": str(
                self._product_public_runtime_payload().get("public_url")
                or f"{self._public_admin_base_url()}/product"
            ).rstrip("/"),
            "summary": {
                "providers_total": len(enriched_items),
                "active_total": active_total,
                "production_total": production_total,
                "stock_active_total": stock_active_total,
                "pending_runtime_total": pending_runtime_total,
            },
            "items": enriched_items,
        }

    def _module_runtime_snapshots_payload(self) -> dict[str, Any]:
        admin_data = self._admin_data_payload()
        modules = admin_data.get("modules") if isinstance(admin_data.get("modules"), list) else []
        module_by_code = {
            str(item.get("code") or "").upper(): item
            for item in modules
            if isinstance(item, dict)
        }

        catalog_summary = self._product_catalog_summary_payload()
        imported_pricing = self._admin_imported_products_pricing_payload()
        integrations = self._admin_integrations_payload()
        stock_sync = self._stock_sync_status_payload()
        checkout = self._mercadopago_checkout_status_payload(force_refresh=False)
        public_runtime = self._public_runtime_payload()
        work_status = self._work_status_payload()
        deployment_summary = admin_data.get("deployment_summary") if isinstance(admin_data.get("deployment_summary"), dict) else {}

        stock_module = catalog_summary.get("stock_module") if isinstance(catalog_summary.get("stock_module"), dict) else {}
        provider_summary = integrations.get("summary") if isinstance(integrations.get("summary"), dict) else {}
        publication_summary = imported_pricing.get("publication_summary") if isinstance(imported_pricing.get("publication_summary"), dict) else {}
        supplier_summary = imported_pricing.get("supplier_summary") if isinstance(imported_pricing.get("supplier_summary"), list) else []
        latest_stock_event = stock_sync.get("latest_event") if isinstance(stock_sync.get("latest_event"), dict) else {}
        top_reasons = publication_summary.get("top_reasons") if isinstance(publication_summary.get("top_reasons"), list) else []
        imported_items = imported_pricing.get("items") if isinstance(imported_pricing.get("items"), list) else []
        stock_supplier_rows = supplier_summary[:8]
        stock_review_rows = [
            {
                "id": str(item.get("id") or ""),
                "title": str(item.get("title") or "Produto sem titulo"),
                "supplier_name": str(item.get("supplier_name") or ""),
                "category": str(item.get("category") or ""),
                "publication_status": str(item.get("publication_status") or ""),
                "publication_status_label": str(item.get("publication_status_label") or ""),
                "reason": (
                    (item.get("publication_reasons") or [""])[0]
                    if isinstance(item.get("publication_reasons"), list)
                    else ""
                ),
                "suggested_sale_price_brl": float(item.get("suggested_sale_price_brl") or 0),
                "estimated_net_revenue_brl": float(item.get("estimated_net_revenue_brl") or 0),
                "stock": float(item.get("stock") or 0),
            }
            for item in imported_items
            if isinstance(item, dict)
            and str(item.get("publication_status") or "") in {"review", "do_not_publish"}
        ][:10]

        mercadopago_notifications = load_jsonl_tail(MERCADOPAGO_NOTIFICATIONS_PATH, limit=8)
        mercadopago_preferences = load_jsonl_tail(MERCADOPAGO_PREFERENCES_PATH, limit=8)
        mercadopago_checkout_attempts = load_jsonl_tail(MERCADOPAGO_CHECKOUT_ATTEMPTS_PATH, limit=8)

        move_module = module_by_code.get("MOVE", {})
        move_checklist = move_module.get("checklist") if isinstance(move_module.get("checklist"), dict) else {}
        move_items = move_checklist.get("items") if isinstance(move_checklist.get("items"), list) else []
        move_pending_items = [
            str(item.get("label") or "").strip()
            for item in move_items
            if isinstance(item, dict) and not item.get("done") and str(item.get("label") or "").strip()
        ]

        move_dependencies = move_module.get("depends_on") if isinstance(move_module.get("depends_on"), list) else []
        move_integrations = move_module.get("integrates_with") if isinstance(move_module.get("integrates_with"), list) else []
        top_failures = deployment_summary.get("top_failures") if isinstance(deployment_summary.get("top_failures"), list) else []
        move_feed: list[dict[str, Any]] = []
        move_telemetry = load_jsonl_tail(MOVE_TELEMETRY_PATH, limit=12)
        work_updated_at = str(work_status.get("updated_at_utc") or "").strip()
        if work_updated_at:
            move_feed.append(
                {
                    "kind": "work_status",
                    "timestamp": work_updated_at,
                    "title": str(work_status.get("activity_name") or "Runtime"),
                    "detail": str(work_status.get("activity_description") or work_status.get("next_steps") or ""),
                    "status": str(work_status.get("status") or "info"),
                }
            )
        runtime_generated_at = str(public_runtime.get("generated_at_utc") or public_runtime.get("generated_at") or "").strip()
        if runtime_generated_at:
            move_feed.append(
                {
                    "kind": "runtime",
                    "timestamp": runtime_generated_at,
                    "title": "Runtime publico",
                    "detail": str(public_runtime.get("public_url") or public_runtime.get("status") or "Runtime sem URL publica"),
                    "status": str(public_runtime.get("status") or "unknown"),
                }
            )
        if move_telemetry:
            move_feed = [
                {
                    "kind": str(item.get("kind") or "telemetry"),
                    "timestamp": str(item.get("timestamp") or item.get("received_at_utc") or utc_now_iso()),
                    "title": str(item.get("title") or "MOVE event"),
                    "detail": str(item.get("detail") or ""),
                    "status": str(item.get("status") or "info"),
                }
                for item in move_telemetry
                if isinstance(item, dict)
            ]
        else:
            for failure in top_failures[:3]:
                move_feed.append(
                    {
                        "kind": "deployment_failure",
                        "timestamp": str(deployment_summary.get("generated_at_utc") or utc_now_iso()),
                        "title": "Falha operacional",
                        "detail": str(failure),
                        "status": "danger",
                    }
                )

        return {
            "status": "ok",
            "service": "valley-module-runtime-snapshots",
            "generated_at_utc": utc_now_iso(),
            "modules": {
                "STOCK": {
                    "catalog_status": catalog_summary.get("status", "missing"),
                    "items_total": int(catalog_summary.get("items_total") or 0),
                    "inventory_units": float(catalog_summary.get("inventory_units") or 0),
                    "inventory_value_brl": float(catalog_summary.get("inventory_value_brl") or 0),
                    "margin_potential_brl": float(catalog_summary.get("margin_potential_brl") or 0),
                    "stock_module": stock_module,
                    "top_stock_item": catalog_summary.get("top_stock_item"),
                    "top_margin_item": catalog_summary.get("top_margin_item"),
                    "top_categories": (catalog_summary.get("top_categories") or [])[:4],
                    "providers_total": int(provider_summary.get("providers_total") or 0),
                    "providers_active": int(provider_summary.get("active_total") or 0),
                    "providers_production": int(provider_summary.get("production_total") or 0),
                    "pending_runtime_total": int(provider_summary.get("pending_runtime_total") or 0),
                    "review_total": int(publication_summary.get("review_total") or 0),
                    "approved_total": int(publication_summary.get("approved_total") or 0),
                    "do_not_publish_total": int(publication_summary.get("do_not_publish_total") or 0),
                    "supplier_summary": supplier_summary[:4],
                    "supplier_rows": stock_supplier_rows,
                    "review_rows": stock_review_rows,
                    "blocking_reasons": top_reasons[:4],
                    "sync_status": stock_sync.get("status", "idle"),
                    "sync_detail": stock_sync.get("detail") or stock_sync.get("message") or "",
                    "latest_sync_event": latest_stock_event,
                },
                "PAY": {
                    "checkout_status": checkout.get("status", "missing_credentials"),
                    "checkout_ready": bool(checkout.get("checkout_ready")),
                    "preferred_environment": checkout.get("preferred_environment", "unconfigured"),
                    "access_token_present": bool(checkout.get("access_token_present")),
                    "public_key_present": bool(checkout.get("public_key_present")),
                    "webhook_secret_present": bool(checkout.get("webhook_secret_present")),
                    "operator_login_present": bool(checkout.get("operator_login_present")),
                    "notification_url": checkout.get("notification_url"),
                    "sample_return_url": checkout.get("sample_return_url"),
                    "latest_notification_at_utc": checkout.get("latest_notification_at_utc"),
                    "notifications_total": len(mercadopago_notifications),
                    "preferences_total": len(mercadopago_preferences),
                    "checkout_attempts_total": len(mercadopago_checkout_attempts),
                    "notification_history": mercadopago_notifications,
                    "preference_history": mercadopago_preferences,
                    "checkout_attempt_history": mercadopago_checkout_attempts,
                    "validation": checkout.get("validation") if isinstance(checkout.get("validation"), dict) else {},
                },
                "MOVE": {
                    "runtime_available": bool(public_runtime.get("available")),
                    "runtime_status": public_runtime.get("status", "missing"),
                    "public_url": public_runtime.get("public_url"),
                    "healthz_url": ((public_runtime.get("smoke_endpoints") or {}).get("healthz") if isinstance(public_runtime.get("smoke_endpoints"), dict) else ""),
                    "work_status": work_status.get("status", "missing"),
                    "work_activity": work_status.get("activity_name", "Valley"),
                    "work_activity_description": work_status.get("activity_description", ""),
                    "work_progress_percent": float(work_status.get("progress_percent") or 0),
                    "checklist_total": int(move_checklist.get("total") or 0),
                    "checklist_done": int(move_checklist.get("done") or 0),
                    "checklist_pending": int(move_checklist.get("pending") or 0),
                    "pending_items": move_pending_items[:5],
                    "dependencies": move_dependencies[:5],
                    "integrations": move_integrations[:5],
                    "telemetry_mode": "dedicated_jsonl" if move_telemetry else "fallback_runtime",
                    "telemetry_source": str(MOVE_TELEMETRY_PATH if move_telemetry else WORK_STATUS_PATH),
                    "operational_feed": move_feed[:8],
                    "deployment_failures": top_failures[:5],
                },
            },
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

    def _runtime_env_payload(self) -> dict[str, str]:
        return load_env_file(CODEX_CLOUD_ENV_PATH)

    def _mercadopago_secret_value(self, *candidates: str) -> str:
        for env_key in candidates:
            env_value = str(os.environ.get(env_key) or "").strip()
            if env_value:
                return env_value

        runtime_env = self._runtime_env_payload()
        for env_key in candidates:
            env_value = str(runtime_env.get(env_key) or "").strip()
            if env_value:
                return env_value

        provider_secrets = self._provider_secrets_payload().get("mercado_pago")
        if not isinstance(provider_secrets, dict):
            return ""

        direct_keys: list[str] = []
        for candidate in candidates:
            direct_keys.extend(
                [
                    candidate,
                    candidate.replace("VALLEY_", ""),
                    candidate.replace("VALLEY_", "").replace("MERCADOPAGO_", ""),
                ]
            )
        for key in direct_keys:
            value = str(provider_secrets.get(key) or "").strip()
            if value:
                return value

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

    def _mercadopago_webhook_secret(self) -> str:
        return self._mercadopago_secret_value(
            "VALLEY_MERCADOPAGO_WEBHOOK_SECRET",
            "MERCADOPAGO_WEBHOOK_SECRET",
            "MP_WEBHOOK_SECRET",
            "webhookSecret",
            "webhook_secret",
        )

    def _mercadopago_operator_login_present(self) -> bool:
        runtime_env = self._runtime_env_payload()
        env_user = str(
            os.environ.get("VALLEY_MERCADOPAGO_USERNAME")
            or os.environ.get("VALLEY_MERCADOPAGO_USER")
            or runtime_env.get("VALLEY_MERCADOPAGO_USERNAME")
            or runtime_env.get("VALLEY_MERCADOPAGO_USER")
            or ""
        ).strip()
        env_password = str(
            os.environ.get("VALLEY_MERCADOPAGO_PASSWORD")
            or runtime_env.get("VALLEY_MERCADOPAGO_PASSWORD")
            or ""
        ).strip()
        if env_user and env_password:
            return True

        provider_secrets = self._provider_secrets_payload().get("mercado_pago")
        if not isinstance(provider_secrets, dict):
            return False
        username = str(provider_secrets.get("username") or "").strip()
        password = str(provider_secrets.get("password") or "").strip()
        return bool(username and password)

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

    def _mercadopago_validate_access_token(self, access_token: str) -> dict[str, Any]:
        request = Request(
            "https://api.mercadopago.com/v1/payment_methods",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/json",
                "User-Agent": "ValleyAdmin/1.0",
            },
            method="GET",
        )
        checked_at = utc_now_iso()
        try:
            with urlopen(request, timeout=25) as response:
                payload = json.loads(response.read().decode("utf-8", errors="replace"))
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            return {
                "status": "http_error",
                "checked_at_utc": checked_at,
                "http_code": error.code,
                "detail": self._trim_checkout_text(detail, 280),
            }
        except URLError as error:
            return {
                "status": "network_error",
                "checked_at_utc": checked_at,
                "detail": self._trim_checkout_text(str(error), 280),
            }
        except json.JSONDecodeError as error:
            return {
                "status": "invalid_response",
                "checked_at_utc": checked_at,
                "detail": self._trim_checkout_text(str(error), 280),
            }
        except Exception as error:  # noqa: BLE001
            return {
                "status": "failed",
                "checked_at_utc": checked_at,
                "detail": self._trim_checkout_text(str(error), 280),
            }

        methods = payload if isinstance(payload, list) else []
        method_ids = {
            str(method.get("id") or "").strip().lower()
            for method in methods
            if isinstance(method, dict)
        }
        payment_type_ids = {
            str(method.get("payment_type_id") or "").strip().lower()
            for method in methods
            if isinstance(method, dict)
        }
        return {
            "status": "ok",
            "checked_at_utc": checked_at,
            "payment_methods_total": len(methods),
            "pix_available": "pix" in method_ids,
            "account_money_available": "account_money" in payment_type_ids,
        }

    def _mercadopago_checkout_status_payload(self, *, force_refresh: bool = False) -> dict[str, Any]:
        saved = load_json_file(MERCADOPAGO_STATUS_PATH) or {}
        access_token = self._mercadopago_access_token()
        public_key = self._mercadopago_public_key()
        webhook_secret = self._mercadopago_webhook_secret()
        latest_notification = load_json_file(MERCADOPAGO_NOTIFICATIONS_LATEST_PATH) or {}
        operator_login_present = self._mercadopago_operator_login_present()
        inferred_mode = (
            "sandbox"
            if str(access_token or "").startswith("TEST-")
            else "production"
            if access_token
            else "unconfigured"
        )

        validation = saved.get("validation") if isinstance(saved.get("validation"), dict) else None
        if access_token and (
            force_refresh
            or not isinstance(validation, dict)
            or str(validation.get("status") or "").strip() not in {"ok", "http_error", "network_error", "invalid_response", "failed"}
        ):
            validation = self._mercadopago_validate_access_token(access_token)
        elif not access_token:
            validation = {
                "status": "missing_credentials",
                "checked_at_utc": utc_now_iso(),
                "detail": "Access token do Mercado Pago ausente no runtime.",
            }

        if access_token and isinstance(validation, dict) and validation.get("status") == "ok":
            status = "ready"
        elif access_token or public_key or webhook_secret:
            status = "partial"
        elif operator_login_present:
            status = "operator_login_ready"
        else:
            status = "missing_credentials"

        payload = {
            "status": status,
            "service": "valley-mercadopago-checkout",
            "provider": "mercado_pago",
            "generated_at_utc": utc_now_iso(),
            "checkout_ready": bool(access_token),
            "access_token_present": bool(access_token),
            "public_key_present": bool(public_key),
            "webhook_secret_present": bool(webhook_secret),
            "operator_login_present": operator_login_present,
            "sandbox_enabled": True,
            "production_enabled": True,
            "preferred_environment": inferred_mode,
            "notification_url": self._mercadopago_notification_url(),
            "sample_return_url": self._mercadopago_return_url("approved", "demo-item"),
            "latest_notification_at_utc": latest_notification.get("received_at_utc"),
            "validation": validation,
        }
        write_json_file(MERCADOPAGO_STATUS_PATH, payload)
        return payload

    def _append_jsonl(self, path: Path, payload: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, ensure_ascii=False) + "\n")

    def _write_move_telemetry_event(self) -> None:
        payload = self._read_json_body()
        if not isinstance(payload, dict):
            self._write_json(
                HTTPStatus.BAD_REQUEST,
                {
                    "status": "invalid_payload",
                    "service": "valley-move-telemetry",
                    "detail": "Expected JSON object.",
                },
            )
            return

        event = {
            "kind": str(payload.get("kind") or "telemetry").strip() or "telemetry",
            "timestamp": str(payload.get("timestamp") or utc_now_iso()).strip() or utc_now_iso(),
            "title": str(payload.get("title") or "MOVE event").strip() or "MOVE event",
            "detail": str(payload.get("detail") or "").strip(),
            "status": str(payload.get("status") or "info").strip() or "info",
            "actor": str(payload.get("actor") or "runtime").strip() or "runtime",
            "module": "MOVE",
        }
        self._append_jsonl(MOVE_TELEMETRY_PATH, event)
        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-move-telemetry",
                "saved_at_utc": utc_now_iso(),
                "event": event,
            },
        )

    def _write_move_telemetry_action(self, query: dict[str, list[str]]) -> dict[str, Any]:
        event = {
            "kind": str((query.get("kind") or ["manual_probe"])[0] or "manual_probe").strip() or "manual_probe",
            "timestamp": utc_now_iso(),
            "title": str((query.get("title") or ["MOVE manual probe"])[0] or "MOVE manual probe").strip() or "MOVE manual probe",
            "detail": str((query.get("detail") or ["Evento operacional registrado manualmente pelo cockpit."])[0] or "Evento operacional registrado manualmente pelo cockpit.").strip(),
            "status": str((query.get("status") or ["info"])[0] or "info").strip() or "info",
            "actor": "admin_action",
            "module": "MOVE",
        }
        self._append_jsonl(MOVE_TELEMETRY_PATH, event)
        return {
            "status": "ok",
            "service": "valley-move-telemetry",
            "action": "move-telemetry",
            "saved_at_utc": event["timestamp"],
            "event": event,
        }

    def _write_marketplace_notification_probe(
        self,
        *,
        provider_key: str,
        route: str,
        detail: str,
    ) -> None:
        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": provider_key,
                "route": route,
                "method": "POST",
                "received_at_utc": utc_now_iso(),
                "detail": detail,
            },
        )

    def _write_marketplace_notification_event(
        self,
        *,
        provider_key: str,
        path: Path,
        latest_path: Path,
    ) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(content_length) if content_length > 0 else b""
        text_body = raw_body.decode("utf-8", errors="replace")
        try:
            parsed_body = json.loads(text_body) if text_body else None
        except json.JSONDecodeError:
            parsed_body = None

        event = {
            "provider": provider_key,
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
        self._append_jsonl(path, event)
        write_json_file(latest_path, event)

        sync_result: dict[str, Any] | None = None
        manager = CATALOG_SYNC_MANAGER
        if manager is not None and provider_key in (MARKETPLACE_RUNTIME_PROVIDERS | SUPPLIER_RUNTIME_PROVIDERS):
            sync_result = manager.schedule(
                f"{provider_key}-webhook",
                delay_seconds=35,
                force_full_sync=True,
            )

        self._write_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "service": "valley-admin",
                "provider": provider_key,
                "received_at_utc": event["received_at_utc"],
                "sync": sync_result,
                "detail": "Notificacao recebida, persistida e encaminhada para reconciliacao do catalogo."
                if sync_result is not None
                else "Notificacao recebida e persistida.",
            },
        )

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
        auth_user, auth_session = self._resolve_active_auth_session(scope="product")
        attempt = {
            "provider": "mercado_pago",
            "attempted_at_utc": utc_now_iso(),
            "item_id": item_id,
            "module": "PAY",
            "user_context": {
                "user_id": str((auth_user or {}).get("user_id") or ""),
                "session_id": str((auth_session or {}).get("session_id") or ""),
                "role": str((auth_user or {}).get("primary_role") or ""),
            },
        }
        if item is None:
            result = {
                "status": "failed",
                "action": "checkout",
                "payload": {
                    "message": "Checkout indisponivel nesta oferta no momento.",
                },
            }
            attempt.update({
                "status": "failed",
                "detail": "Item indisponivel para checkout.",
                "result": result["payload"],
            })
            self._append_jsonl(MERCADOPAGO_CHECKOUT_ATTEMPTS_PATH, attempt)
            return result

        if self._mercadopago_checkout_ready(item):
            mercadopago_result = self._create_mercadopago_preference(item)
            if mercadopago_result.get("status") == "ok":
                result = {
                    "status": "ok",
                    "action": "checkout",
                    "payload": {
                        "message": "Abrindo checkout seguro do Valley com Mercado Pago.",
                        "url": mercadopago_result.get("url"),
                        "provider": "mercado_pago",
                        "preference_id": mercadopago_result.get("preference_id"),
                    },
                }
                attempt.update({
                    "status": "ok",
                    "detail": "Preferencia Mercado Pago criada com sucesso.",
                    "result": result["payload"],
                })
                self._append_jsonl(MERCADOPAGO_CHECKOUT_ATTEMPTS_PATH, attempt)
                return result

        checkout_url = self._derive_checkout_url(item)
        if not checkout_url:
            mercadopago_detail = ""
            if self._mercadopago_access_token():
                mercadopago_result = self._create_mercadopago_preference(item)
                mercadopago_detail = str(mercadopago_result.get("detail") or "").strip()
            result = {
                "status": "failed",
                "action": "checkout",
                "payload": {
                    "message": mercadopago_detail or "Checkout indisponivel nesta oferta no momento.",
                },
            }
            attempt.update({
                "status": "failed",
                "detail": result["payload"]["message"],
                "result": result["payload"],
            })
            self._append_jsonl(MERCADOPAGO_CHECKOUT_ATTEMPTS_PATH, attempt)
            return result

        result = {
            "status": "ok",
            "action": "checkout",
            "payload": {
                "message": "Abrindo pagamento protegido da oferta.",
                "url": checkout_url,
                "provider": "mercado_livre",
            },
        }
        attempt.update({
            "status": "ok",
            "detail": "Fallback de checkout externo utilizado.",
            "result": result["payload"],
        })
        self._append_jsonl(MERCADOPAGO_CHECKOUT_ATTEMPTS_PATH, attempt)
        return result

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
