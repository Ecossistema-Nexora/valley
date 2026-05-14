"""Generate or apply Cloudflare DNS records for Valley module workspaces."""

from __future__ import annotations

import argparse
import json
import os
import re
import socket
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
DEFAULT_PUBLIC_HOST = "brasildesconto.com.br"
DEFAULT_ADMIN_HOST = "admin.brasildesconto.com.br"
DEFAULT_ZONE_HOST = "admin.brasildesconto.com.br"
DEFAULT_TARGET_HOST = "admin.brasildesconto.com.br"
DEFAULT_TUNNEL_ID = "80a75594-5129-469f-8cce-4a938ac48e06"
DEFAULT_ACCOUNT_ID = "474fc26bf9c6bcf5e1a84b7f63a516d8"
DEFAULT_ORIGIN_URL = "http://192.168.1.2:8085"
DEFAULT_COST_ZERO_ALIASES = True
DEFAULT_INCLUDE_NESTED_ADMIN_RECORDS = False

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

MERCHANT_ERP_WORKSPACES = [
    {"key": "merchant-login", "title": "Login Lojista", "host": "lojista"},
    {"key": "merchant-erp", "title": "ERP Lojista", "host": "erp-lojista"},
    {"key": "merchant-pdv", "title": "PDV", "host": "pdv-lojista"},
    {"key": "merchant-warehouse", "title": "Armazem", "host": "armazem-lojista"},
    {"key": "merchant-metrics", "title": "Metricas", "host": "metricas-lojista"},
    {"key": "merchant-campaigns", "title": "Campanhas", "host": "campanhas-lojista"},
    {"key": "merchant-reports", "title": "Relatorios", "host": "relatorios-lojista"},
    {"key": "merchant-finance", "title": "Financeiro", "host": "financeiro-lojista"},
    {"key": "merchant-banking", "title": "APIs Bancarias", "host": "bancos-lojista"},
    {"key": "merchant-registration", "title": "Cadastro", "host": "cadastro-lojista"},
    {"key": "merchant-profile", "title": "Perfil", "host": "perfil-lojista"},
    {"key": "merchant-accounting", "title": "Contabil", "host": "contabil-lojista"},
    {"key": "merchant-integrations", "title": "Integracao", "host": "integracao-lojista"},
    {"key": "merchant-orders", "title": "Pedidos", "host": "pedidos-lojista"},
    {"key": "merchant-products", "title": "Produtos", "host": "produtos-lojista"},
    {"key": "merchant-customers", "title": "Clientes", "host": "clientes-lojista"},
    {"key": "merchant-tax", "title": "Fiscal", "host": "fiscal-lojista"},
    {"key": "merchant-inventory", "title": "Estoque", "host": "estoque-lojista"},
    {"key": "merchant-stock-count", "title": "Inventario de Estoque", "host": "inventario-lojista"},
    {"key": "merchant-logistics", "title": "Logistica", "host": "logistica-lojista"},
    {"key": "merchant-carrier-cross-docking", "title": "Transportadora e Cross Docking", "host": "transportadora-lojista"},
    {"key": "merchant-support", "title": "Atendimento", "host": "atendimento-lojista"},
    {"key": "merchant-team", "title": "Equipe", "host": "equipe-lojista"},
    {"key": "merchant-security", "title": "Seguranca", "host": "seguranca-lojista"},
    {"key": "merchant-settings", "title": "Configuracoes", "host": "configuracoes-lojista"},
]


def default_tunnel_target_host(tunnel_id: str = DEFAULT_TUNNEL_ID) -> str:
    return f"{tunnel_id}.cfargotunnel.com"


def force_ipv4_resolution() -> None:
    """Force urllib to use IPv4 for Cloudflare API calls when token IP filters require it."""

    original_getaddrinfo = socket.getaddrinfo

    def ipv4_getaddrinfo(*args: Any, **kwargs: Any) -> list[Any]:
        results = original_getaddrinfo(*args, **kwargs)
        ipv4_results = [item for item in results if item[0] == socket.AF_INET]
        return ipv4_results or results

    socket.getaddrinfo = ipv4_getaddrinfo  # type: ignore[assignment]


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"{path} did not contain a JSON object")
    return payload


def slug_to_subdomain(value: str) -> str:
    slug = re.sub(r"[^a-z0-9-]+", "-", str(value or "").lower()).strip("-")
    return slug or "modulo"


def gateway_records(
    *,
    public_host: str,
    admin_host: str,
    tunnel_target_host: str,
    include_admin_wildcard: bool = False,
) -> list[dict[str, Any]]:
    records = [
        {
            "kind": "public_site",
            "key": "public",
            "title": "Site publico Valley",
            "module_code": "",
            "name": public_host,
            "type": "CNAME",
            "content": tunnel_target_host,
            "proxied": True,
        },
        {
            "kind": "admin_gateway",
            "key": "admin",
            "title": "Painel admin Valley",
            "module_code": "",
            "name": admin_host,
            "type": "CNAME",
            "content": tunnel_target_host,
            "proxied": True,
        },
    ]
    if include_admin_wildcard:
        records.append(
            {
            "kind": "admin_module_wildcard",
            "key": "admin-wildcard",
            "title": "Wildcard dos workspaces admin",
            "module_code": "",
            "name": f"*.{admin_host}",
            "type": "CNAME",
            "content": tunnel_target_host,
            "proxied": True,
            }
        )
    return records


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


def cost_zero_alias_name(record: dict[str, Any], public_host: str, admin_host: str) -> str:
    prefix = str(record.get("name") or "").strip().lower()
    suffix = f".{admin_host.lower()}"
    if prefix.endswith(suffix):
        prefix = prefix[: -len(suffix)]
    prefix = slug_to_subdomain(prefix)
    return f"{prefix}-admin.{public_host}"


def cost_zero_alias_records(
    module_workspace_records: list[dict[str, Any]],
    *,
    public_host: str,
    tunnel_target_host: str,
    admin_host: str,
) -> list[dict[str, Any]]:
    aliases: list[dict[str, Any]] = []
    for record in module_workspace_records:
        if record.get("kind") not in {"static_workspace", "module_workspace"}:
            continue
        alias = dict(record)
        alias["kind"] = f"{record.get('kind')}_cost_zero_alias"
        alias["key"] = f"{record.get('key')}-https-alias"
        alias["title"] = f"{record.get('title')} HTTPS alias"
        alias["name"] = cost_zero_alias_name(record, public_host, admin_host)
        alias["content"] = tunnel_target_host
        alias["cost_zero_ssl_compatible"] = True
        aliases.append(alias)
    return aliases


def merchant_erp_records(*, public_host: str, tunnel_target_host: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for workspace in MERCHANT_ERP_WORKSPACES:
        host = slug_to_subdomain(str(workspace["host"]))
        records.append(
            {
                "kind": "merchant_erp_workspace",
                "key": workspace["key"],
                "title": workspace["title"],
                "module_code": "MERCHANT_ERP",
                "name": f"{host}.{public_host}",
                "type": "CNAME",
                "content": tunnel_target_host,
                "proxied": True,
                "cost_zero_ssl_compatible": True,
            }
        )
    return records


def desired_tunnel_ingress(
    public_host: str,
    admin_host: str,
    origin_url: str,
    alias_hosts: list[str] | None = None,
    include_admin_wildcard: bool = False,
) -> list[dict[str, Any]]:
    ingress = [
        {"hostname": public_host, "service": origin_url, "originRequest": {}},
        {"hostname": admin_host, "service": origin_url, "originRequest": {}},
    ]
    if include_admin_wildcard:
        ingress.append({"hostname": f"*.{admin_host}", "service": origin_url, "originRequest": {}})
    for hostname in alias_hosts or []:
        ingress.append({"hostname": hostname, "service": origin_url, "originRequest": {}})
    return ingress


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


def list_dns_records_by_name(record: dict[str, Any], token: str, zone_id: str) -> list[dict[str, Any]]:
    query = urllib.parse.urlencode({"name": record["name"]})
    existing = cloudflare_request("GET", f"/zones/{zone_id}/dns_records?{query}", token)
    matches = existing.get("result") if isinstance(existing.get("result"), list) else []
    return [item for item in matches if isinstance(item, dict)]


def apply_records(
    records: list[dict[str, Any]],
    token: str,
    zone_id: str,
    *,
    replace_conflicting_records: bool = False,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for record in records:
        all_matches = list_dns_records_by_name(record, token, zone_id)
        matches = [item for item in all_matches if str(item.get("type") or "").upper() == record["type"]]
        conflicts = [item for item in all_matches if str(item.get("type") or "").upper() != record["type"]]
        body = {
            "type": record["type"],
            "name": record["name"],
            "content": record["content"],
            "ttl": 1,
            "proxied": bool(record["proxied"]),
            "comment": "Valley module workspace managed by scripts/plan_valley_module_subdomains.py",
        }
        if conflicts and not matches and replace_conflicting_records:
            for conflict in conflicts:
                conflict_id = str(conflict.get("id") or "")
                if conflict_id:
                    cloudflare_request("DELETE", f"/zones/{zone_id}/dns_records/{conflict_id}", token)
                    time.sleep(0.1)
            conflicts = []
        if matches:
            record_id = str(matches[0].get("id") or "")
            cloudflare_request("PATCH", f"/zones/{zone_id}/dns_records/{record_id}", token, body)
            action = "updated"
        else:
            cloudflare_request("POST", f"/zones/{zone_id}/dns_records", token, body)
            action = "created_after_conflict_replace" if conflicts else "created"
        results.append({"name": record["name"], "type": record["type"], "action": action})
        time.sleep(0.15)
    return results


def apply_tunnel_config(
    *,
    token: str,
    account_id: str,
    tunnel_id: str,
    public_host: str,
    admin_host: str,
    origin_url: str,
    alias_hosts: list[str] | None = None,
    include_admin_wildcard: bool = False,
) -> dict[str, Any]:
    response = cloudflare_request("GET", f"/accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations", token)
    result = response.get("result") if isinstance(response.get("result"), dict) else {}
    config = result.get("config") if isinstance(result.get("config"), dict) else {}
    existing_ingress = config.get("ingress") if isinstance(config.get("ingress"), list) else []
    desired = desired_tunnel_ingress(
        public_host,
        admin_host,
        origin_url,
        alias_hosts,
        include_admin_wildcard=include_admin_wildcard,
    )
    desired_hosts = {str(item["hostname"]).lower() for item in desired}
    preserved: list[dict[str, Any]] = []
    catch_all: dict[str, Any] | None = None

    for raw_rule in existing_ingress:
        if not isinstance(raw_rule, dict):
            continue
        hostname = str(raw_rule.get("hostname") or "").strip().lower()
        if not hostname:
            catch_all = raw_rule
            continue
        if hostname in desired_hosts:
            continue
        preserved.append(raw_rule)

    next_config = dict(config)
    next_config["ingress"] = desired + preserved + [catch_all or {"service": "http_status:404"}]
    cloudflare_request(
        "PUT",
        f"/accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations",
        token,
        {"config": next_config},
    )
    return {
        "tunnel_id": tunnel_id,
        "origin_url": origin_url,
        "desired_hosts": sorted(desired_hosts),
        "preserved_hosts": [
            str(item.get("hostname") or "")
            for item in preserved
            if str(item.get("hostname") or "").strip()
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--public-host", default=os.environ.get("VALLEY_PUBLIC_SITE_HOST", DEFAULT_PUBLIC_HOST))
    parser.add_argument("--admin-host", default=os.environ.get("VALLEY_ADMIN_SITE_HOST", DEFAULT_ADMIN_HOST))
    parser.add_argument("--zone-host", default=os.environ.get("VALLEY_MODULE_DNS_ZONE_HOST", DEFAULT_ZONE_HOST))
    parser.add_argument("--target-host", default=os.environ.get("VALLEY_MODULE_DNS_TARGET_HOST", DEFAULT_TARGET_HOST))
    parser.add_argument("--tunnel-id", default=os.environ.get("CLOUDFLARE_TUNNEL_ID", DEFAULT_TUNNEL_ID))
    parser.add_argument("--tunnel-target-host", default=os.environ.get("VALLEY_CLOUDFLARE_TUNNEL_TARGET_HOST", ""))
    parser.add_argument("--account-id", default=os.environ.get("CLOUDFLARE_ACCOUNT_ID", DEFAULT_ACCOUNT_ID))
    parser.add_argument("--origin-url", default=os.environ.get("VALLEY_ADMIN_TUNNEL_ORIGIN", DEFAULT_ORIGIN_URL))
    parser.add_argument(
        "--include-cost-zero-aliases",
        action=argparse.BooleanOptionalAction,
        default=(
            os.environ.get("VALLEY_INCLUDE_COST_ZERO_ALIASES", "1" if DEFAULT_COST_ZERO_ALIASES else "0")
            .strip()
            .lower()
            not in {"0", "false", "no", "off"}
        ),
        help="Create first-level HTTPS aliases covered by Universal SSL, for example stock-admin.brasildesconto.com.br.",
    )
    parser.add_argument(
        "--include-nested-admin-records",
        action=argparse.BooleanOptionalAction,
        default=(
            os.environ.get("VALLEY_INCLUDE_NESTED_ADMIN_RECORDS", "1" if DEFAULT_INCLUDE_NESTED_ADMIN_RECORDS else "0")
            .strip()
            .lower()
            not in {"0", "false", "no", "off"}
        ),
        help="Also include deep hosts such as 01-reply.admin.brasildesconto.com.br. Keep disabled on the free Universal SSL plan.",
    )
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    parser.add_argument("--apply", action="store_true", help="Apply records through Cloudflare API.")
    parser.add_argument("--apply-tunnel-config", action="store_true", help="Apply Cloudflare Tunnel public hostname ingress.")
    parser.add_argument("--force-ipv4", action="store_true", help="Use IPv4 for Cloudflare API calls.")
    parser.add_argument(
        "--replace-conflicting-records",
        action="store_true",
        help="Delete same-name DNS records with conflicting types before creating the desired CNAME.",
    )
    args = parser.parse_args()

    if args.force_ipv4:
        force_ipv4_resolution()

    public_host = args.public_host.strip().strip(".")
    admin_host = args.admin_host.strip().strip(".")
    zone_host = args.zone_host.strip().strip(".")
    target_host = args.target_host.strip().strip(".")
    tunnel_id = args.tunnel_id.strip()
    tunnel_target_host = (args.tunnel_target_host.strip().strip(".") or default_tunnel_target_host(tunnel_id))
    gateway = gateway_records(
        public_host=public_host,
        admin_host=admin_host,
        tunnel_target_host=tunnel_target_host,
        include_admin_wildcard=args.include_nested_admin_records,
    )
    nested_modules = module_records(zone_host, target_host)
    cost_zero_aliases = (
        cost_zero_alias_records(
            nested_modules,
            public_host=public_host,
            tunnel_target_host=tunnel_target_host,
            admin_host=admin_host,
        )
        if args.include_cost_zero_aliases
        else []
    )
    merchant_aliases = (
        merchant_erp_records(public_host=public_host, tunnel_target_host=tunnel_target_host)
        if args.include_cost_zero_aliases
        else []
    )
    alias_hosts = [str(record["name"]) for record in cost_zero_aliases + merchant_aliases]
    module_records_for_dns = nested_modules if args.include_nested_admin_records else []
    records = gateway + module_records_for_dns + cost_zero_aliases + merchant_aliases
    desired_ingress = desired_tunnel_ingress(
        public_host,
        admin_host,
        args.origin_url.strip(),
        alias_hosts,
        include_admin_wildcard=args.include_nested_admin_records,
    )
    manifest: dict[str, Any] = {
        "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "public_host": public_host,
        "admin_host": admin_host,
        "zone_host": zone_host,
        "target_host": target_host,
        "tunnel_id": tunnel_id,
        "tunnel_target_host": tunnel_target_host,
        "origin_url": args.origin_url,
        "desired_tunnel_ingress": desired_ingress,
        "gateway_records_total": len(gateway),
        "module_records_total": len(module_records_for_dns),
        "nested_admin_records_included": bool(args.include_nested_admin_records),
        "nested_admin_records_available_total": len(nested_modules),
        "cost_zero_alias_records_total": len(cost_zero_aliases),
        "merchant_erp_records_total": len(merchant_aliases),
        "records_total": len(records),
        "records": records,
        "apply_status": "not_requested",
        "tunnel_apply_status": "not_requested",
    }
    exit_code = 0

    if args.apply:
        token = os.environ.get("CLOUDFLARE_API_TOKEN") or os.environ.get("CF_API_TOKEN") or ""
        zone_id = os.environ.get("CLOUDFLARE_ZONE_ID") or ""
        if not token or not zone_id:
            manifest["apply_status"] = "blocked_missing_cloudflare_token_or_zone_id"
            print("Cloudflare apply blocked: CLOUDFLARE_API_TOKEN/CF_API_TOKEN and CLOUDFLARE_ZONE_ID are required.", file=sys.stderr)
            exit_code = 2
        else:
            try:
                manifest["apply_results"] = apply_records(
                    records,
                    token,
                    zone_id,
                    replace_conflicting_records=args.replace_conflicting_records,
                )
                manifest["apply_status"] = "applied"
            except RuntimeError as exc:
                manifest["apply_status"] = "blocked_cloudflare_api"
                manifest["apply_error"] = str(exc)
                print(f"Cloudflare DNS apply blocked: {exc}", file=sys.stderr)
                exit_code = 3

    if args.apply_tunnel_config:
        token = os.environ.get("CLOUDFLARE_API_TOKEN") or os.environ.get("CF_API_TOKEN") or ""
        if not token:
            manifest["tunnel_apply_status"] = "blocked_missing_cloudflare_token"
            print("Cloudflare tunnel apply blocked: CLOUDFLARE_API_TOKEN/CF_API_TOKEN is required.", file=sys.stderr)
            exit_code = max(exit_code, 2)
        else:
            try:
                manifest["tunnel_apply_result"] = apply_tunnel_config(
                    token=token,
                    account_id=args.account_id.strip(),
                    tunnel_id=tunnel_id,
                    public_host=public_host,
                    admin_host=admin_host,
                    origin_url=args.origin_url.strip(),
                    alias_hosts=alias_hosts,
                    include_admin_wildcard=args.include_nested_admin_records,
                )
                manifest["tunnel_apply_status"] = "applied"
            except RuntimeError as exc:
                manifest["tunnel_apply_status"] = "blocked_cloudflare_api"
                manifest["tunnel_apply_error"] = str(exc)
                print(f"Cloudflare tunnel apply blocked: {exc}", file=sys.stderr)
                exit_code = max(exit_code, 3)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(records)} DNS records to {args.output}")
    print(f"apply_status={manifest['apply_status']}")
    print(f"tunnel_apply_status={manifest['tunnel_apply_status']}")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
