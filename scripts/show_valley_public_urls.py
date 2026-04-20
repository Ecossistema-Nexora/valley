#!/usr/bin/env python3
"""Mostra os endpoints publicos ativos do ngrok local com diagnostico de release."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "tmp" / "runtime" / "valley-admin-public-runtime.json"
DEFAULT_NGROK_API_URL = "http://127.0.0.1:4040/api/tunnels"


def load_json_file(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.exists():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def fetch_json(url: str, timeout: float) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Lista URLs publicas do Valley Admin no ngrok.")
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_MANIFEST),
        help="Manifesto JSON gerado por start_valley_admin_public.ps1.",
    )
    parser.add_argument(
        "--ngrok-api-url",
        default="",
        help="Endpoint do ngrok local API. Sobrescreve o manifesto.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Timeout em segundos para consultar a API local do ngrok.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Imprime o consolidado em JSON.",
    )
    return parser.parse_args()


def resolve_api_url(args: argparse.Namespace, manifest: dict[str, Any] | None) -> str:
    if args.ngrok_api_url:
        return args.ngrok_api_url

    manifest_api_url = None
    if manifest:
        manifest_api_url = manifest.get("ngrok", {}).get("api_url")

    return manifest_api_url or DEFAULT_NGROK_API_URL


def build_payload(
    *,
    manifest: dict[str, Any] | None,
    manifest_path: Path | None,
    api_url: str,
    tunnels_payload: dict[str, Any] | None,
    api_error: str | None,
) -> dict[str, Any]:
    tunnels = []
    reserved_domain = None
    local_urls: dict[str, Any] = {}

    if manifest:
        reserved_domain = manifest.get("ngrok", {}).get("reserved_domain")
        local_urls = manifest.get("local", {})

    if tunnels_payload:
        for tunnel in tunnels_payload.get("tunnels", []):
            config = tunnel.get("config", {})
            public_url = tunnel.get("public_url")
            tunnels.append(
                {
                    "name": tunnel.get("name", "sem_nome"),
                    "public_url": public_url,
                    "addr": config.get("addr"),
                    "inspect_url": tunnel.get("inspect_url"),
                    "proto": tunnel.get("proto"),
                    "permanence": (
                        "reserved-domain"
                        if reserved_domain and public_url and reserved_domain in public_url
                        else "ephemeral"
                    ),
                }
            )

    return {
        "status": "ok" if tunnels else "degraded",
        "manifest_path": str(manifest_path) if manifest_path else None,
        "api_url": api_url,
        "api_error": api_error,
        "local": local_urls,
        "reserved_domain": reserved_domain,
        "tunnels": tunnels,
        "manifest": manifest,
    }


def print_human(payload: dict[str, Any]) -> None:
    manifest = payload.get("manifest") or {}
    local = payload.get("local") or {}
    tunnels = payload.get("tunnels") or []

    print(f"Manifesto: {manifest.get('files', {}).get('runtime_manifest', DEFAULT_MANIFEST)}")
    if local:
        print(f"Local admin: {local.get('base_url', 'indisponivel')}")
        print(f"Health local: {local.get('health_url', 'indisponivel')}")
        print(f"Payload local: {local.get('data_url', 'indisponivel')}")

    print(f"ngrok API: {payload.get('api_url')}")

    if payload.get("api_error"):
        print(f"Falha ao consultar o ngrok local: {payload['api_error']}")
        files = manifest.get("files", {})
        if files:
            print(f"Log HTTP stdout: {files.get('serve_stdout_log', files.get('serve_log', 'indisponivel'))}")
            print(f"Log HTTP stderr: {files.get('serve_stderr_log', 'indisponivel')}")
            print(f"Log ngrok stdout: {files.get('ngrok_stdout_log', files.get('ngrok_log', 'indisponivel'))}")
            print(f"Log ngrok stderr: {files.get('ngrok_stderr_log', 'indisponivel')}")
        return

    if not tunnels:
        print("Nenhum tunnel ativo encontrado para o Valley Admin.")
        files = manifest.get("files", {})
        if files:
            print(f"Log ngrok stdout: {files.get('ngrok_stdout_log', files.get('ngrok_log', 'indisponivel'))}")
            print(f"Log ngrok stderr: {files.get('ngrok_stderr_log', 'indisponivel')}")
        return

    for tunnel in tunnels:
        public_url = tunnel.get("public_url", "sem_url")
        print(f"{tunnel.get('name', 'sem_nome')}: {public_url} -> {tunnel.get('addr', 'sem_addr')}")
        print(f"Inspect: {tunnel.get('inspect_url', 'indisponivel')}")
        print(f"Permanencia: {tunnel.get('permanence', 'desconhecida')}")
        print(f"Smoke /healthz: {public_url}/healthz")
        print(f"Smoke /api/admin-data: {public_url}/api/admin-data")

    reserved_domain = payload.get("reserved_domain")
    if reserved_domain:
        print(f"Dominio reservado configurado: https://{reserved_domain}")
    else:
        print("Sem dominio reservado. As URLs acima sao efemeras ate definir VALLEY_NGROK_ADMIN_DOMAIN.")


def main() -> None:
    args = parse_args()
    manifest_path = Path(args.manifest).resolve() if args.manifest else None
    manifest = load_json_file(manifest_path)
    api_url = resolve_api_url(args, manifest)

    tunnels_payload = None
    api_error = None

    try:
        tunnels_payload = fetch_json(api_url, timeout=args.timeout)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        api_error = str(exc)

    payload = build_payload(
        manifest=manifest,
        manifest_path=manifest_path,
        api_url=api_url,
        tunnels_payload=tunnels_payload,
        api_error=api_error,
    )

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print_human(payload)

    if payload["api_error"]:
        sys.exit(1)

    if not payload["tunnels"]:
        sys.exit(2)


if __name__ == "__main__":
    main()
