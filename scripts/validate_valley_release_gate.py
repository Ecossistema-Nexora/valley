#!/usr/bin/env python3
"""PROPOSITO: Validar o gate funcional e visual do release Valley.

CONTEXTO: O script verifica arquivos locais, identidade visual Stitch, runtime
publico, ERP Lojista, PDV offline-first, RBAC e conectores bancarios antes de
considerar um release pronto.

REGRAS: Nao gravar segredos, nao mascarar falhas reais, tolerar apenas
oscilacoes transitorias de tunnel em chamadas seguras e nunca repetir acoes
mutaveis do ERP automaticamente.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE_URL = "https://admin.brasildesconto.com.br"
STATUS_PATH = ROOT / "tmp" / "runtime" / "valley-release-gate-validation.json"
STITCH_VERSION = "20260513_valley_erp_v2"
TRANSIENT_REMOTE_STATUS_CODES = {0, 408, 425, 429, 500, 502, 503, 504}
REQUIRED_MODULE_KEYS = {
    "sales",
    "products",
    "stock",
    "orders",
    "customers",
    "finance",
    "checkout",
    "delivery",
    "marketplace",
    "reports",
    "settings",
    "support",
    "banking",
}
REQUIRED_ICON_PATHS = [
    ROOT / "admin" / "favicon.ico",
    ROOT / "frontend" / "flutter" / "windows" / "runner" / "resources" / "app_icon.ico",
    ROOT / "tools" / "valley_erp_single_windows" / "app_icon.ico",
    ROOT / "frontend" / "flutter" / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png",
    ROOT / "frontend" / "flutter" / "web" / "icons" / "Icon-512.png",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _request_json_once(
    url: str,
    *,
    method: str = "GET",
    payload: dict | None = None,
    token: str = "",
    timeout: int = 15,
) -> tuple[int, dict]:
    data = None
    headers = {"Accept": "application/json", "User-Agent": "ValleyReleaseGate/1.0"}
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
        headers["X-Valley-Session"] = token
    request = Request(url, data=data, method=method, headers=headers)
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw or "{}")
    except HTTPError as error:
        raw = error.read().decode("utf-8", errors="replace")
        try:
            body = json.loads(raw or "{}")
        except json.JSONDecodeError:
            body = {"status": "http_error", "detail": raw[:500]}
        return error.code, body
    except (OSError, URLError, json.JSONDecodeError) as error:
        return 0, {"status": "request_failed", "detail": str(error)}


def request_json(
    url: str,
    *,
    method: str = "GET",
    payload: dict | None = None,
    token: str = "",
    timeout: int = 15,
    retries: int = 3,
    retry_delay_seconds: float = 1.5,
) -> tuple[int, dict]:
    method_upper = method.upper()
    retry_allowed = method_upper == "GET" or url.rstrip("/").endswith("/api/auth/login")
    attempts = max(1, retries if retry_allowed else 1)
    status = 0
    body: dict = {}
    for attempt in range(attempts):
        status, body = _request_json_once(
            url,
            method=method,
            payload=payload,
            token=token,
            timeout=timeout,
        )
        if status not in TRANSIENT_REMOTE_STATUS_CODES:
            return status, body
        if attempt < attempts - 1:
            time.sleep(retry_delay_seconds * (attempt + 1))
    return status, body


def local_file_checks() -> list[dict]:
    checks: list[dict] = []
    stitch_config = ROOT / "config" / "design" / "valley_stitch_source_of_truth.json"
    stitch_manifest = ROOT / "admin" / "stitch" / STITCH_VERSION / "manifest.json"
    banking_config = ROOT / "config" / "integrations" / "valley_banking_api_connectors.json"
    for path in [stitch_config, stitch_manifest, banking_config, *REQUIRED_ICON_PATHS]:
        checks.append(
            {
                "name": str(path.relative_to(ROOT)),
                "ok": path.exists() and path.stat().st_size > 0,
                "sha256": sha256(path) if path.exists() and path.is_file() else "",
            }
        )
    if stitch_config.exists():
        config = json.loads(stitch_config.read_text(encoding="utf-8"))
        version = config.get("version") or config.get("source_version")
        checks.append(
            {
                "name": "stitch-source-version",
                "ok": version == STITCH_VERSION,
                "value": version,
            }
        )
    if stitch_manifest.exists():
        manifest = json.loads(stitch_manifest.read_text(encoding="utf-8"))
        screens = manifest.get("screens") if isinstance(manifest.get("screens"), list) else []
        checks.append({"name": "stitch-manifest-screens", "ok": len(screens) >= 100, "value": len(screens)})
    if banking_config.exists():
        banking = json.loads(banking_config.read_text(encoding="utf-8"))
        connectors = banking.get("connectors") if isinstance(banking.get("connectors"), list) else []
        checks.append({"name": "banking-connectors", "ok": len(connectors) >= 3, "value": len(connectors)})
    return checks


def remote_checks(base_url: str, username: str, password: str) -> list[dict]:
    checks: list[dict] = []
    status, health = request_json(f"{base_url.rstrip('/')}/healthz")
    checks.append({"name": "public-health", "ok": status == 200 and health.get("status") in {"ok", "healthy"}, "status_code": status})

    status, login = request_json(
        f"{base_url.rstrip('/')}/api/auth/login",
        method="POST",
        payload={"identifier": username, "password": password, "scope": "merchant"},
    )
    token = str(((login.get("session") or {}) if isinstance(login.get("session"), dict) else {}).get("token") or "")
    checks.append({"name": "merchant-login", "ok": status == 200 and login.get("status") == "ok" and bool(token), "status_code": status})
    if not token:
        return checks

    status, blueprint = request_json(f"{base_url.rstrip('/')}/api/merchant-erp/blueprint", token=token)
    modules = blueprint.get("modules") if isinstance(blueprint.get("modules"), list) else []
    module_keys = {str(module.get("key") or "") for module in modules if isinstance(module, dict)}
    checks.append(
        {
            "name": "merchant-blueprint-modules",
            "ok": status == 200 and REQUIRED_MODULE_KEYS.issubset(module_keys),
            "status_code": status,
            "missing": sorted(REQUIRED_MODULE_KEYS.difference(module_keys)),
            "modules_total": len(module_keys),
        }
    )
    persistence = blueprint.get("persistence") if isinstance(blueprint.get("persistence"), dict) else {}
    checks.append(
        {
            "name": "merchant-persistence-logs",
            "ok": all(
                persistence.get(key)
                for key in [
                    "event_log",
                    "pdv_event_log",
                    "banking_event_log",
                    "privilege_store",
                    "offline_queue_store",
                    "action_endpoint",
                    "privileges_endpoint",
                    "offline_sync_endpoint",
                ]
            ),
            "value": persistence,
        }
    )

    status, privileges = request_json(f"{base_url.rstrip('/')}/api/merchant-erp/privileges", token=token)
    effective_privileges = privileges.get("effective_privileges") if isinstance(privileges.get("effective_privileges"), list) else []
    staff_members = privileges.get("staff_members") if isinstance(privileges.get("staff_members"), list) else []
    checks.append(
        {
            "name": "merchant-rbac-effective-privileges",
            "ok": status == 200 and privileges.get("status") == "ok" and bool(effective_privileges) and bool(staff_members),
            "status_code": status,
            "effective_total": len(effective_privileges),
            "staff_total": len(staff_members),
        }
    )
    status, privilege_mutation = request_json(
        f"{base_url.rstrip('/')}/api/merchant-erp/privileges",
        method="POST",
        payload={"action": "grant", "privilege_key": "pdv.sale.offline"},
        token=token,
    )
    checks.append(
        {
            "name": "merchant-rbac-mutation",
            "ok": status == 200 and privilege_mutation.get("status") == "ok" and bool(privilege_mutation.get("mutation_event_id")),
            "status_code": status,
            "mutation_event_id": privilege_mutation.get("mutation_event_id"),
        }
    )

    status, offline_queue = request_json(f"{base_url.rstrip('/')}/api/merchant-erp/offline-queue", token=token)
    checks.append(
        {
            "name": "merchant-offline-queue-contract",
            "ok": status == 200 and offline_queue.get("status") == "ok" and bool((offline_queue.get("policy") or {}).get("idempotency_required")),
            "status_code": status,
            "synced_total": len(offline_queue.get("synced_events") if isinstance(offline_queue.get("synced_events"), list) else []),
        }
    )
    idempotency_key = f"gate-offline-{hashlib.sha256(base_url.encode('utf-8')).hexdigest()[:10]}"
    status, offline_sync = request_json(
        f"{base_url.rstrip('/')}/api/merchant-erp/offline-sync",
        method="POST",
        payload={
            "events": [
                {
                    "local_sale_id": "gate-sale-001",
                    "device_id": "PDV-GATE",
                    "event_type": "pdv_sale",
                    "amount_brl": 19.9,
                    "payment_method": "pending_authorization",
                    "idempotency_key": idempotency_key,
                },
                {
                    "local_sale_id": "gate-sale-001",
                    "device_id": "PDV-GATE",
                    "event_type": "pdv_sale",
                    "amount_brl": 19.9,
                    "payment_method": "pending_authorization",
                    "idempotency_key": idempotency_key,
                },
            ]
        },
        token=token,
    )
    checks.append(
        {
            "name": "merchant-offline-idempotent-sync",
            "ok": status == 200 and offline_sync.get("status") == "ok" and int(offline_sync.get("duplicate_total") or 0) >= 1,
            "status_code": status,
            "accepted_total": offline_sync.get("accepted_total"),
            "duplicate_total": offline_sync.get("duplicate_total"),
        }
    )

    action_payloads = [
        ("sales-checkout-confirm", {"module_key": "sales", "action": "checkout-confirm", "amount_brl": 19.9}),
        ("sales-terminal-confirm", {"module_key": "sales", "action": "payment-terminal-confirm", "amount_brl": 19.9}),
        ("banking-sync", {"module_key": "banking", "action": "bank-api-sync", "connector_key": "pix_gateway"}),
        ("reports-generate", {"module_key": "reports", "action": "report"}),
        ("products-publish", {"module_key": "products", "action": "publish"}),
        ("stock-movement", {"module_key": "stock", "action": "movement"}),
    ]
    for name, payload in action_payloads:
        status, action = request_json(
            f"{base_url.rstrip('/')}/api/merchant-erp/action",
            method="POST",
            payload=payload,
            token=token,
        )
        checks.append(
            {
                "name": name,
                "ok": status == 200 and action.get("status") == "ok" and bool(action.get("event_id")),
                "status_code": status,
                "event_id": action.get("event_id"),
                "pdv_event_id": action.get("pdv_event_id"),
                "banking_event_id": action.get("banking_event_id"),
            }
        )
    return checks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default=os.getenv("VALLEY_RELEASE_GATE_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--username", default=os.getenv("VALLEY_MERCHANT_TEST_USERNAME", "lojista.demo@valley.local"))
    parser.add_argument("--password", default=os.getenv("VALLEY_MERCHANT_TEST_PASSWORD", ""))
    args = parser.parse_args()

    checks = local_file_checks()
    if args.password:
        checks.extend(remote_checks(args.base_url, args.username, args.password))
    else:
        checks.append(
            {
                "name": "merchant-login",
                "ok": False,
                "detail": "Defina VALLEY_MERCHANT_TEST_PASSWORD para validar a sessao de lojista.",
            }
        )

    failed = [check for check in checks if not check.get("ok")]
    result = {
        "status": "ok" if not failed else "failed",
        "service": "valley-release-gate-validation",
        "base_url": args.base_url,
        "checks_total": len(checks),
        "failed_total": len(failed),
        "checks": checks,
    }
    STATUS_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATUS_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "checks_total": len(checks), "failed_total": len(failed)}, ensure_ascii=False))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
