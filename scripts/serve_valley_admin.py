#!/usr/bin/env python3
"""Servidor HTTP endurecido para o painel admin do Valley."""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "admin"
DEFAULT_DATA_PATH = DEFAULT_ROOT / "valley_admin_data.json"


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
        super().end_headers()

    def do_GET(self) -> None:  # noqa: N802
        route = urlsplit(self.path).path

        if route in ("/health", "/healthz", "/meta/runtime", "/api/runtime"):
            self._write_json(HTTPStatus.OK, self._runtime_payload())
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
