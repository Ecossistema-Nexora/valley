#!/usr/bin/env python3
"""Servidor HTTP endurecido para o painel admin do Valley."""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import sqlite3
import socket
import subprocess
import sys
from datetime import datetime, timezone
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
from urllib.error import URLError, HTTPError


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "admin"
DEFAULT_DATA_PATH = DEFAULT_ROOT / "valley_admin_data.json"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
BRIDGE_STATUS_PATH = RUNTIME_DIR / "codex-live-status.json"
WORK_STATUS_PATH = RUNTIME_DIR / "bridge-work-status.json"
PUBLIC_RUNTIME_PATH = RUNTIME_DIR / "valley-admin-public-runtime.json"
PRODUCT_CATALOG_PATH = ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_product_catalog.json"
PRODUCT_INTERACTIONS_PATH = RUNTIME_DIR / "valley-product-interactions.jsonl"
STOCK_DB_PATH = RUNTIME_DIR / "valley-admin-stock.sqlite3"
MAX_REMOTE_FEED_BYTES = 2 * 1024 * 1024


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


def ensure_stock_db() -> None:
    STOCK_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(STOCK_DB_PATH) as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS stock_configs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                feed_url TEXT NOT NULL,
                notes TEXT NOT NULL,
                providers_json TEXT NOT NULL,
                transporters_json TEXT NOT NULL,
                created_at_utc TEXT NOT NULL
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS stock_import_jobs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                feed_url TEXT NOT NULL,
                source_type TEXT NOT NULL,
                imported_items INTEGER NOT NULL,
                status TEXT NOT NULL,
                details_json TEXT NOT NULL,
                created_at_utc TEXT NOT NULL
            )
            """
        )
        connection.commit()


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

        if route == "/api/stock/config":
            self._write_json(HTTPStatus.OK, self._stock_config_payload())
            return

        if route == "/api/stock/imports":
            self._write_json(HTTPStatus.OK, self._stock_imports_payload())
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

        if route == "/api/stock/config":
            payload = self._read_json_body()
            if payload is None:
                self._write_json(
                    HTTPStatus.BAD_REQUEST,
                    {"status": "failed", "message": "Payload JSON invalido."},
                )
                return
            self._write_json(HTTPStatus.OK, self._save_stock_config(payload))
            return

        if route == "/api/stock/import":
            payload = self._read_json_body()
            if payload is None:
                self._write_json(
                    HTTPStatus.BAD_REQUEST,
                    {"status": "failed", "message": "Payload JSON invalido."},
                )
                return
            self._write_json(HTTPStatus.OK, self._create_stock_import_job(payload))
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
            "public_runtime": self._public_runtime_payload(),
        }
        if isinstance(catalog, dict):
            payload.update(catalog)
            payload["public_runtime"] = self._public_runtime_payload()
            payload["status"] = "ok"
            payload["service"] = "valley-product"
        return payload

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

    def _read_json_body(self) -> dict[str, Any] | None:
        raw_length = self.headers.get("Content-Length", "").strip()
        if not raw_length:
            return {}

        try:
            body_size = int(raw_length)
        except ValueError:
            return None
        if body_size <= 0:
            return {}

        body = self.rfile.read(body_size)
        try:
            payload = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

        return payload if isinstance(payload, dict) else None

    def _stock_config_payload(self) -> dict[str, Any]:
        ensure_stock_db()
        with sqlite3.connect(STOCK_DB_PATH) as connection:
            connection.row_factory = sqlite3.Row
            row = connection.execute(
                """
                SELECT id, feed_url, notes, providers_json, transporters_json, created_at_utc
                FROM stock_configs
                ORDER BY id DESC
                LIMIT 1
                """
            ).fetchone()

        if not row:
            return {
                "status": "empty",
                "config": {
                    "feed_url": "",
                    "notes": "",
                    "providers": [],
                    "transporters": [],
                },
            }

        return {
            "status": "ok",
            "config": {
                "feed_url": row["feed_url"],
                "notes": row["notes"],
                "providers": json.loads(row["providers_json"] or "[]"),
                "transporters": json.loads(row["transporters_json"] or "[]"),
                "updated_at_utc": row["created_at_utc"],
            },
        }

    def _save_stock_config(self, payload: dict[str, Any]) -> dict[str, Any]:
        ensure_stock_db()
        feed_url = str(payload.get("feed_url", "")).strip()
        notes = str(payload.get("notes", "")).strip()
        providers = self._normalize_string_list(payload.get("providers", []))
        transporters = self._normalize_string_list(payload.get("transporters", []))
        feed_ok, feed_error = self._validate_feed_reference(feed_url)
        if not feed_ok:
            return {"status": "failed", "message": feed_error}
        created_at = utc_now_iso()

        with sqlite3.connect(STOCK_DB_PATH) as connection:
            connection.execute(
                """
                INSERT INTO stock_configs (feed_url, notes, providers_json, transporters_json, created_at_utc)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    feed_url,
                    notes,
                    json.dumps(providers, ensure_ascii=False),
                    json.dumps(transporters, ensure_ascii=False),
                    created_at,
                ),
            )
            connection.commit()

        return {
            "status": "ok",
            "message": "Configuração STOCK persistida no banco local.",
            "saved_at_utc": created_at,
        }

    @staticmethod
    def _normalize_string_list(value: Any, *, max_items: int = 64, max_item_len: int = 120) -> list[str]:
        if not isinstance(value, list):
            return []
        normalized: list[str] = []
        for item in value[:max_items]:
            text = str(item).strip()
            if text:
                normalized.append(text[:max_item_len])
        return normalized

    def _stock_imports_payload(self) -> dict[str, Any]:
        ensure_stock_db()
        with sqlite3.connect(STOCK_DB_PATH) as connection:
            connection.row_factory = sqlite3.Row
            rows = connection.execute(
                """
                SELECT id, feed_url, source_type, imported_items, status, details_json, created_at_utc
                FROM stock_import_jobs
                ORDER BY id DESC
                LIMIT 20
                """
            ).fetchall()

        return {
            "status": "ok",
            "items_total": len(rows),
            "items": [
                {
                    "id": row["id"],
                    "feed_url": row["feed_url"],
                    "source_type": row["source_type"],
                    "imported_items": row["imported_items"],
                    "status": row["status"],
                    "details": json.loads(row["details_json"] or "{}"),
                    "created_at_utc": row["created_at_utc"],
                }
                for row in rows
            ],
        }

    def _create_stock_import_job(self, payload: dict[str, Any]) -> dict[str, Any]:
        ensure_stock_db()
        feed_url = str(payload.get("feed_url", "")).strip()
        if not feed_url:
            return {"status": "failed", "message": "feed_url é obrigatório."}
        feed_ok, feed_error = self._validate_feed_reference(feed_url)
        if not feed_ok:
            return {"status": "failed", "message": feed_error}

        source_type, imported_items, details = self._resolve_import_preview(feed_url)
        created_at = utc_now_iso()
        status = "completed" if source_type != "invalid" else "failed"

        with sqlite3.connect(STOCK_DB_PATH) as connection:
            connection.execute(
                """
                INSERT INTO stock_import_jobs (feed_url, source_type, imported_items, status, details_json, created_at_utc)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    feed_url,
                    source_type,
                    imported_items,
                    status,
                    json.dumps(details, ensure_ascii=False),
                    created_at,
                ),
            )
            connection.commit()

        return {
            "status": status,
            "message": "Importação simulada registrada com persistência em banco local.",
            "job": {
                "feed_url": feed_url,
                "source_type": source_type,
                "imported_items": imported_items,
                "details": details,
                "created_at_utc": created_at,
            },
        }

    def _resolve_import_preview(self, feed_url: str) -> tuple[str, int, dict[str, Any]]:
        if feed_url.startswith(("http://", "https://")):
            parsed_url = urlsplit(feed_url)
            host = parsed_url.hostname or ""
            if not host:
                return ("invalid", 0, {"message": "URL remota invalida."})
            if self._is_private_host(host):
                return ("invalid", 0, {"message": "Host remoto bloqueado por seguranca."})
            try:
                handler = self

                class SafeRedirectHandler(HTTPRedirectHandler):
                    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[override]
                        redirected = urlsplit(newurl)
                        redirected_host = redirected.hostname or ""
                        if not redirected_host or handler._is_private_host(redirected_host):
                            raise URLError("Host remoto bloqueado por redirecionamento.")
                        return super().redirect_request(req, fp, code, msg, headers, newurl)

                opener = build_opener(SafeRedirectHandler)
                request = Request(feed_url, headers={"User-Agent": "ValleyAdmin/1.0"})
                with opener.open(request, timeout=12) as response:
                    body_bytes = response.read(MAX_REMOTE_FEED_BYTES + 1)
                    if len(body_bytes) > MAX_REMOTE_FEED_BYTES:
                        return ("invalid", 0, {"message": "Feed remoto excede o limite permitido."})
                    body = body_bytes.decode("utf-8")
                payload = json.loads(body)
            except (URLError, HTTPError, TimeoutError, json.JSONDecodeError, UnicodeDecodeError) as exc:
                return ("invalid", 0, {"error": str(exc)})

            if isinstance(payload, list):
                return ("http-json-array", len(payload), {"keys_sample": self._extract_keys_sample(payload)})

            if isinstance(payload, dict):
                items = payload.get("items")
                if isinstance(items, list):
                    return ("http-json-items", len(items), {"keys_sample": self._extract_keys_sample(items)})
                return ("http-json-dict", len(payload.keys()), {"keys": list(payload.keys())[:10]})

            return ("http-unknown", 0, {"message": "Formato remoto não suportado."})

        local_path = (ROOT / feed_url).resolve() if not Path(feed_url).is_absolute() else Path(feed_url).resolve()
        if local_path.is_absolute() and not self._is_allowed_local_feed(local_path):
            return ("invalid", 0, {"message": "Caminho local fora do workspace nao e permitido."})
        if local_path.exists():
            try:
                content = json.loads(local_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError, UnicodeDecodeError) as exc:
                return ("invalid", 0, {"error": str(exc)})

            if isinstance(content, list):
                return ("file-json-array", len(content), {"path": str(local_path)})
            if isinstance(content, dict):
                items = content.get("items")
                if isinstance(items, list):
                    return ("file-json-items", len(items), {"path": str(local_path)})
                return ("file-json-dict", len(content.keys()), {"path": str(local_path)})

        return ("invalid", 0, {"message": "Feed não encontrado ou formato inválido."})

    @staticmethod
    def _extract_keys_sample(values: list[Any]) -> list[str]:
        for entry in values:
            if isinstance(entry, dict):
                return [str(key) for key in list(entry.keys())[:8]]
        return []

    @staticmethod
    def _validate_feed_reference(feed_url: str) -> tuple[bool, str]:
        if not feed_url:
            return (True, "")
        if "\x00" in feed_url:
            return (False, "feed_url invalido: caractere nulo detectado.")
        if len(feed_url) > 2048:
            return (False, "feed_url invalido: tamanho excede 2048 caracteres.")

        if feed_url.startswith(("http://", "https://")):
            parsed = urlsplit(feed_url)
            if not parsed.hostname:
                return (False, "feed_url invalido: host remoto ausente.")
            return (True, "")

        candidate = (ROOT / feed_url).resolve() if not Path(feed_url).is_absolute() else Path(feed_url).resolve()
        if not ValleyAdminHandler._is_allowed_local_feed(candidate):
            return (False, "feed_url invalido: caminho local fora do workspace.")
        return (True, "")

    @staticmethod
    def _is_allowed_local_feed(candidate: Path) -> bool:
        try:
            candidate.resolve().relative_to(ROOT)
            return True
        except ValueError:
            return False

    @staticmethod
    def _is_private_host(host: str) -> bool:
        if host in {"localhost", "0.0.0.0"}:
            return True
        try:
            addresses = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
        except socket.gaierror:
            return True

        for _, _, _, _, sockaddr in addresses:
            ip_text = sockaddr[0]
            try:
                ip_obj = ipaddress.ip_address(ip_text)
            except ValueError:
                return True
            if (
                ip_obj.is_private
                or ip_obj.is_loopback
                or ip_obj.is_link_local
                or ip_obj.is_multicast
                or ip_obj.is_reserved
                or ip_obj.is_unspecified
            ):
                return True
        return False


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
    ensure_stock_db()

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
