"""Generate or apply Cloudflare DNS records for Valley module workspaces."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ADMIN_DATA_PATH = ROOT / "admin" / "valley_admin_data.json"
OUTPUT_PATH = ROOT / "output" / "deployment" / "valley-module-subdomains.json"
DEFAULT_ZONE_HOST = "admin.brasildesconto.com.br"
DEFAULT_TARGET_HOST = "admin.brasildesconto.com.br"

STATIC_WORKSPACES = [
    {"key": "stock", "title": "Painel STOCK", "subdomain": "stock"},
    {"key": "dropshipping", "title": "Dropshipping", "subdomain": "dropshipping"},
    {"key": "marketplace", "title": "Marketplace", "subdomain": "marketplace"},
    {"key": "review", "title": "Revisao", "subdomain": "review"},
    {"key": "finance", "title": "Financeiro", "subdomain": "finance"},
    {"key": "merchants", "title": "Lojistas", "subdomain": "merchants"},
    {"key": "users", "title": "Usuarios", "subdomain": "users"},
    {"key": "checkout", "title": "Checkout", "subdomain": "checkout"},
    {"key": "sandbox", "title": "Sandbox e Flags", "subdomain": "sandbox"},
]


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"{path} did not contain a JSON object")
    return payload


def slug_to_subdomain(value: str) -> str:
    slug = re.sub(r"[^a-z0-9-]+", "-", str(value or "").lower()).strip("-")
    return slug or "modulo"


def module_records(zone_host: str, target_host: str) -> list[dict[str, Any]]:
    payload = load_json(ADMIN_DATA_PATH)
    modules = payload.get("modules") if isinstance(payload.get("modules"), list) else []
    reserved = {workspace["subdomain"] for workspace in STATIC_WORKSPACES}
    used: set[str] = set()
    records: list[dict[str, Any]] = []

    for workspace in STATIC_WORKSPACES:
        records.append(
            {
                "kind": "static_workspace",
                "key": workspace["key"],
                "title": workspace["title"],
                "module_code": "",
                "name": f"{workspace['subdomain']}.{zone_host}",
                "type": "CNAME",
                "content": target_host,
                "proxied": True,
            }
        )

    for module in sorted(modules, key=lambda item: int(item.get("number") or 9999)):
        code = str(module.get("code") or "").strip().upper()
        subdomain = slug_to_subdomain(str(module.get("slug") or code))
        if subdomain in reserved or subdomain in used:
            subdomain = f"{subdomain}-module"
        used.add(subdomain)
        records.append(
            {
                "kind": "module_workspace",
                "key": f"module-{code.lower()}",
                "title": f"{code} - {module.get('name')}",
                "module_code": code,
                "name": f"{subdomain}.{zone_host}",
                "type": "CNAME",
                "content": target_host,
                "proxied": True,
            }
        )
    return records


def cloudflare_request(method: str, path: str, token: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Cloudflare HTTP {exc.code}: {detail}") from exc
    if not payload.get("success"):
        raise RuntimeError(json.dumps(payload.get("errors") or payload, ensure_ascii=False))
    return payload


def apply_records(records: list[dict[str, Any]], token: str, zone_id: str) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for record in records:
        query = urllib.parse.urlencode({"type": record["type"], "name": record["name"]})
        existing = cloudflare_request("GET", f"/zones/{zone_id}/dns_records?{query}", token)
        matches = existing.get("result") if isinstance(existing.get("result"), list) else []
        body = {
            "type": record["type"],
            "name": record["name"],
            "content": record["content"],
            "ttl": 1,
            "proxied": bool(record["proxied"]),
            "comment": "Valley module workspace managed by scripts/plan_valley_module_subdomains.py",
        }
        if matches:
            record_id = str(matches[0].get("id") or "")
            cloudflare_request("PATCH", f"/zones/{zone_id}/dns_records/{record_id}", token, body)
            action = "updated"
        else:
            cloudflare_request("POST", f"/zones/{zone_id}/dns_records", token, body)
            action = "created"
        results.append({"name": record["name"], "action": action})
        time.sleep(0.15)
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zone-host", default=os.environ.get("VALLEY_MODULE_DNS_ZONE_HOST", DEFAULT_ZONE_HOST))
    parser.add_argument("--target-host", default=os.environ.get("VALLEY_MODULE_DNS_TARGET_HOST", DEFAULT_TARGET_HOST))
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    parser.add_argument("--apply", action="store_true", help="Apply records through Cloudflare API.")
    args = parser.parse_args()

    records = module_records(args.zone_host.strip().strip("."), args.target_host.strip().strip("."))
    manifest: dict[str, Any] = {
        "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "zone_host": args.zone_host,
        "target_host": args.target_host,
        "records_total": len(records),
        "records": records,
        "apply_status": "not_requested",
    }

    if args.apply:
        token = os.environ.get("CLOUDFLARE_API_TOKEN") or os.environ.get("CF_API_TOKEN") or ""
        zone_id = os.environ.get("CLOUDFLARE_ZONE_ID") or ""
        if not token or not zone_id:
            manifest["apply_status"] = "blocked_missing_cloudflare_token_or_zone_id"
            print("Cloudflare apply blocked: CLOUDFLARE_API_TOKEN/CF_API_TOKEN and CLOUDFLARE_ZONE_ID are required.", file=sys.stderr)
        else:
            manifest["apply_results"] = apply_records(records, token, zone_id)
            manifest["apply_status"] = "applied"

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(records)} DNS records to {args.output}")
    print(f"apply_status={manifest['apply_status']}")
    return 0 if manifest["apply_status"] != "blocked_missing_cloudflare_token_or_zone_id" else 2


if __name__ == "__main__":
    raise SystemExit(main())
