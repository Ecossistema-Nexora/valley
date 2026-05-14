"""PROPOSITO: Criar ou atualizar o usuario de teste administrador lojista.
CONTEXTO: O runtime local de autenticacao do Valley usa JSON e hash PBKDF2 para login de testes.
REGRAS: Nao gravar senha em claro; manter acesso limitado ao ERP Lojista, sem permissao global de super admin.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import secrets
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_PATH = ROOT / "tmp" / "runtime" / "valley-user-auth-runtime.json"
EVENTS_PATH = ROOT / "tmp" / "runtime" / "valley-user-auth-events.jsonl"
DEFAULT_IDENTIFIER = "lojista.demo@valley.local"
MERCHANT_ADMIN_PRIVILEGES = [
    "erp.menu.open",
    "pdv.session.open",
    "pdv.sale.create",
    "pdv.sale.cancel",
    "pdv.cash.move",
    "pdv.session.close",
    "products.read",
    "products.write",
    "inventory.read",
    "inventory.adjust",
    "orders.read",
    "orders.fulfill",
    "finance.read",
    "finance.approve",
    "integrations.manage",
    "reports.export",
    "team.manage",
    "security.manage",
    "settings.manage",
]


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def deterministic_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.UUID("4f2b8258-3f4d-4f0d-a4cf-9d8d39f3a0f4"), name))


def pbkdf2_hash_password(password: str, *, iterations: int = 310_000) -> str:
    salt = secrets.token_bytes(16)
    derived = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return "pbkdf2_sha256${}${}${}".format(
        iterations,
        base64.urlsafe_b64encode(salt).decode("ascii").rstrip("="),
        base64.urlsafe_b64encode(derived).decode("ascii").rstrip("="),
    )


def load_runtime() -> dict[str, Any]:
    if not RUNTIME_PATH.exists():
        return {"version": "v1", "users": [], "sessions": []}
    payload = json.loads(RUNTIME_PATH.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Runtime invalido: {RUNTIME_PATH}")
    payload.setdefault("version", "v1")
    payload.setdefault("users", [])
    payload.setdefault("sessions", [])
    return payload


def write_runtime(payload: dict[str, Any]) -> None:
    RUNTIME_PATH.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def append_event(event: dict[str, Any]) -> None:
    EVENTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with EVENTS_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")


def normalized_identifier(value: str) -> str:
    return value.strip().lower()


def build_user(identifier: str, password_hash: str, now: str) -> dict[str, Any]:
    user_id = deterministic_uuid(f"user:{identifier}")
    identity_id = deterministic_uuid(f"identity:{identifier}")
    profile_id = deterministic_uuid(f"profile:{identifier}")
    merchant_profile_id = deterministic_uuid(f"merchant-profile:{identifier}")
    return {
        "user_id": user_id,
        "user_kind": "PJ",
        "account_status": "ACTIVE",
        "full_name": "Lojista Valley Demo",
        "display_name": "Lojista Demo",
        "email": identifier,
        "document_country": "BR",
        "document_type": "EMAIL_LOGIN",
        "document_number": identifier,
        "primary_role": "MERCHANT",
        "module_tier": "MERCHANT_ERP",
        "permissions": MERCHANT_ADMIN_PRIVILEGES,
        "created_at": now,
        "updated_at": now,
        "identity": {
            "identity_id": identity_id,
            "identity_type": "EMAIL_PASSWORD",
            "identity_status": "ACTIVE",
            "login_identifier": identifier,
            "login_identifier_normalized": identifier,
            "email": identifier,
            "password_hash": password_hash,
            "password_algo": "pbkdf2_sha256_310000",
            "failed_login_count": 0,
            "locked_until": None,
            "verified_at": now,
            "last_authenticated_at": None,
        },
        "profile": {
            "user_profile_id": profile_id,
            "profile_status": "ACTIVE",
            "username": "lojista-demo",
            "display_handle": "Lojista Demo",
            "preferences_json": {},
            "onboarding_completed_at": now,
        },
        "merchant_profile": {
            "merchant_profile_id": merchant_profile_id,
            "merchant_user_id": user_id,
            "profile_status": "ACTIVE",
            "merchant_code": "MER-LOJISTA-DEMO",
            "slug": "lojista-demo",
            "display_name": "Lojista Demo",
            "role_profile": "ADMIN",
            "admin_scope": "merchant_erp",
        },
    }


def update_user(user: dict[str, Any], identifier: str, password_hash: str, now: str) -> dict[str, Any]:
    user["user_kind"] = "PJ"
    user["account_status"] = "ACTIVE"
    user["full_name"] = user.get("full_name") or "Lojista Valley Demo"
    user["display_name"] = user.get("display_name") or "Lojista Demo"
    user["email"] = identifier
    user["document_country"] = "BR"
    user["document_type"] = "EMAIL_LOGIN"
    user["document_number"] = identifier
    user["primary_role"] = "MERCHANT"
    user["module_tier"] = "MERCHANT_ERP"
    user["permissions"] = MERCHANT_ADMIN_PRIVILEGES
    user["updated_at"] = now

    identity = user.setdefault("identity", {})
    identity["identity_type"] = "EMAIL_PASSWORD"
    identity["identity_status"] = "ACTIVE"
    identity["login_identifier"] = identifier
    identity["login_identifier_normalized"] = identifier
    identity["email"] = identifier
    identity["password_hash"] = password_hash
    identity["password_algo"] = "pbkdf2_sha256_310000"
    identity["failed_login_count"] = 0
    identity["locked_until"] = None
    identity.setdefault("verified_at", now)
    identity["last_authenticated_at"] = None

    profile = user.setdefault("profile", {})
    profile["profile_status"] = "ACTIVE"
    profile.setdefault("username", "lojista-demo")
    profile.setdefault("display_handle", user["display_name"])
    profile.setdefault("preferences_json", {})
    profile.setdefault("onboarding_completed_at", now)

    merchant_profile = user.setdefault("merchant_profile", {})
    merchant_profile["merchant_user_id"] = user["user_id"]
    merchant_profile["profile_status"] = "ACTIVE"
    merchant_profile.setdefault("merchant_code", "MER-LOJISTA-DEMO")
    merchant_profile.setdefault("slug", "lojista-demo")
    merchant_profile["display_name"] = user["display_name"]
    merchant_profile["role_profile"] = "ADMIN"
    merchant_profile["admin_scope"] = "merchant_erp"
    return user


def read_password(args: argparse.Namespace) -> str:
    if args.password_stdin:
        password = sys.stdin.read().strip()
    else:
        password = os.environ.get("VALLEY_TEST_MERCHANT_ADMIN_PASSWORD", "").strip()
    if not password:
        raise ValueError(
            "Senha ausente. Use VALLEY_TEST_MERCHANT_ADMIN_PASSWORD ou --password-stdin."
        )
    return password


def main() -> int:
    parser = argparse.ArgumentParser(description="Garante usuario admin lojista de teste.")
    parser.add_argument("--identifier", default=DEFAULT_IDENTIFIER)
    parser.add_argument("--password-stdin", action="store_true")
    args = parser.parse_args()

    identifier = normalized_identifier(args.identifier)
    password = read_password(args)
    now = utc_now_iso()
    password_hash = pbkdf2_hash_password(password)
    runtime = load_runtime()
    users = runtime.setdefault("users", [])
    sessions = runtime.setdefault("sessions", [])

    user = None
    for candidate in users:
        identity = candidate.get("identity") if isinstance(candidate, dict) else None
        aliases = {
            normalized_identifier(str(candidate.get("email") or "")),
            normalized_identifier(str(candidate.get("document_number") or "")),
        }
        if isinstance(identity, dict):
            aliases.add(normalized_identifier(str(identity.get("login_identifier") or "")))
            aliases.add(normalized_identifier(str(identity.get("email") or "")))
        if identifier in aliases:
            user = candidate
            break

    action = "updated"
    if user is None:
        user = build_user(identifier, password_hash, now)
        users.append(user)
        action = "created"
    else:
        update_user(user, identifier, password_hash, now)

    before_sessions = len(sessions)
    runtime["sessions"] = [
        session for session in sessions if session.get("user_id") != user.get("user_id")
    ]
    invalidated_sessions = before_sessions - len(runtime["sessions"])
    write_runtime(runtime)
    append_event(
        {
            "event_id": str(uuid.uuid4()),
            "kind": "merchant_admin_test_user_ensured",
            "action": action,
            "identifier": identifier,
            "user_id": user.get("user_id"),
            "primary_role": user.get("primary_role"),
            "module_tier": user.get("module_tier"),
            "permissions_count": len(user.get("permissions") or []),
            "invalidated_sessions": invalidated_sessions,
            "created_at": now,
        }
    )

    print(
        json.dumps(
            {
                "status": "ok",
                "action": action,
                "identifier": identifier,
                "user_id": user.get("user_id"),
                "primary_role": user.get("primary_role"),
                "module_tier": user.get("module_tier"),
                "permissions_count": len(user.get("permissions") or []),
                "invalidated_sessions": invalidated_sessions,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
