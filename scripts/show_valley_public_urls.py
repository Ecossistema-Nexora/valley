#!/usr/bin/env python3
# PROPOSITO: Automatizar show valley public urls no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/show_valley_public_urls.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Mostra o runtime publico atual do Valley Admin publicado por Cloudflare."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "tmp" / "runtime" / "valley-admin-public-runtime.json"


def load_json_file(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.exists():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Lista URLs publicas do Valley Admin.")
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_MANIFEST),
        help="Manifesto JSON gerado por start_valley_admin_public.ps1.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Imprime o consolidado em JSON.",
    )
    return parser.parse_args()


def build_payload(manifest_path: Path, manifest: dict[str, Any] | None) -> dict[str, Any]:
    manifest = manifest or {}
    public_url = str(manifest.get("public_url") or "").rstrip("/") or None
    smoke = manifest.get("smoke_endpoints") or {}

    return {
        "status": manifest.get("status", "missing"),
        "manifest_path": str(manifest_path),
        "provider": manifest.get("provider"),
        "provider_status": manifest.get("provider_status"),
        "temporary": manifest.get("temporary"),
        "permanence": manifest.get("permanence"),
        "public_url": public_url,
        "local_url": manifest.get("local_url"),
        "smoke_endpoints": {
            "healthz": smoke.get("healthz") or (f"{public_url}/healthz" if public_url else None),
            "admin_data": smoke.get("admin_data") or (f"{public_url}/api/admin-data" if public_url else None),
        },
        "logs": manifest.get("logs") or {},
        "manifest": manifest,
    }


def print_human(payload: dict[str, Any]) -> None:
    print(f"Manifesto: {payload['manifest_path']}")
    print(f"Provider: {payload.get('provider') or 'indisponivel'}")
    print(f"Status: {payload.get('status')}")
    print(f"Provider status: {payload.get('provider_status') or 'indisponivel'}")
    print(f"Local admin: {payload.get('local_url') or 'indisponivel'}")

    public_url = payload.get("public_url")
    if public_url:
        print(f"Publico: {public_url}")
        print(f"Smoke /healthz: {payload['smoke_endpoints'].get('healthz')}")
        print(f"Smoke /api/admin-data: {payload['smoke_endpoints'].get('admin_data')}")
        print(f"Permanencia: {payload.get('permanence') or 'indisponivel'}")
        print(f"Temporario: {payload.get('temporary')}")
    else:
        print("Sem URL publica publicada no manifesto.")

    logs = payload.get("logs") or {}
    if logs:
        print(f"Log Cloudflare stdout: {logs.get('cloudflare_stdout', 'indisponivel')}")
        print(f"Log Cloudflare stderr: {logs.get('cloudflare_stderr', 'indisponivel')}")


def main() -> None:
    args = parse_args()
    manifest_path = Path(args.manifest).resolve()
    manifest = load_json_file(manifest_path)
    payload = build_payload(manifest_path, manifest)

    if args.json:
        json.dump(payload, fp=sys.stdout, ensure_ascii=False, indent=2)
        print()
        return

    print_human(payload)


if __name__ == "__main__":
    main()
