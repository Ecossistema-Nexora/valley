#!/usr/bin/env python3
"""Ponte segura Telegram/WhatsApp para filas Codex do projeto Valley."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "config" / "bridge" / "VALLEY_COMMUNICATION_BRIDGE.json"
ENV_PATH = ROOT / ".env"
TELEGRAM_QUEUE = ROOT / "ordem_telegram.md"
UNIVERSAL_QUEUE = ROOT / "ordem_universal.md"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
STATUS_PATH = RUNTIME_DIR / "codex-live-status.json"
CODEX_INBOX_PATH = RUNTIME_DIR / "codex-inbox.jsonl"

SAFE_KINDS = {"status", "report", "read_only_check", "documentation_update", "queue_triage"}
MANUAL_KINDS = {
    "secrets",
    "payments",
    "database_write",
    "deployment",
    "shell_command",
    "external_access",
    "destructive_operation",
}
DANGEROUS_HINTS = {
    "rm ",
    "del ",
    "format ",
    "drop table",
    "truncate ",
    "delete from",
    "deploy",
    "pagamento",
    "payment",
    "secret",
    "token",
    "senha",
    "password",
    "shell",
    "powershell",
    "cmd ",
    "docker",
    "git reset",
    "auto aprovação",
    "auto aprovacao",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_config() -> dict[str, Any]:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def ensure_runtime() -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)


def load_local_env() -> None:
    """Carrega .env local sem sobrescrever variaveis ja definidas no processo."""

    if not ENV_PATH.exists():
        return

    for raw_line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def bridge_status() -> dict[str, Any]:
    load_local_env()
    config = load_config()
    telegram_ready = bool(os.environ.get("VALLEY_TELEGRAM_TOKEN") and os.environ.get("VALLEY_TELEGRAM_CHAT_ID"))
    whatsapp_mode = os.environ.get("VALLEY_WHATSAPP_MODE", "web").strip().lower()
    whatsapp_web_to = os.environ.get("VALLEY_WHATSAPP_WEB_TO") or os.environ.get("VALLEY_WHATSAPP_TO")
    whatsapp_api_ready = bool(
        os.environ.get("VALLEY_WHATSAPP_API_URL")
        and os.environ.get("VALLEY_WHATSAPP_TOKEN")
        and os.environ.get("VALLEY_WHATSAPP_TO")
    )
    whatsapp_ready = bool(whatsapp_web_to) if whatsapp_mode == "web" else whatsapp_api_ready
    return {
        "generated_at_utc": utc_now(),
        "bridge": config["name"],
        "mode": config["approval_policy"]["mode"],
        "telegram_ready": telegram_ready,
        "whatsapp_ready": whatsapp_ready,
        "whatsapp_mode": whatsapp_mode,
        "whatsapp_login_method": "whatsapp_web_manual_login" if whatsapp_mode == "web" else "api",
        "whatsapp_web_target_configured": bool(whatsapp_web_to),
        "telegram_queue": str(TELEGRAM_QUEUE.relative_to(ROOT)),
        "universal_queue": str(UNIVERSAL_QUEUE.relative_to(ROOT)),
        "safe_auto_approved_kinds": sorted(SAFE_KINDS),
        "manual_review_required_for": sorted(MANUAL_KINDS),
        "unrestricted_auto_approval": False,
    }


def write_status() -> dict[str, Any]:
    ensure_runtime()
    status = bridge_status()
    STATUS_PATH.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    return status


def infer_kind(text: str, default: str) -> str:
    lowered = text.lower()
    if any(hint in lowered for hint in DANGEROUS_HINTS):
        return "manual_review"
    return default


def append_codex_event(source: str, text: str, kind: str, status: str, auto_approval: str, execution_gate: str) -> None:
    ensure_runtime()
    event = {
        "received_at_utc": utc_now(),
        "source": source,
        "kind": kind,
        "status": status,
        "auto_approval": auto_approval,
        "codex_route": "auto_start",
        "execution_gate": execution_gate,
        "text": text.strip(),
    }
    with CODEX_INBOX_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False) + "\n")


def append_order(queue_path: Path, source: str, text: str, kind: str = "queue_triage") -> None:
    normalized_kind = infer_kind(text, kind.strip() or "queue_triage")
    auto_approval = "safe_only" if normalized_kind in SAFE_KINDS else "manual_review"
    execution_gate = "safe_only" if auto_approval == "safe_only" else "manual_review"
    status = "accepted"
    entry = [
        "",
        "---",
        f"source: {source}",
        f"kind: {normalized_kind}",
        f"status: {status}",
        "priority: normal",
        "codex_route: auto_start",
        f"execution_gate: {execution_gate}",
        f"received_at_utc: {utc_now()}",
        f"auto_approval: {auto_approval}",
        "---",
        text.strip(),
        "",
    ]
    with queue_path.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(entry))
    append_codex_event(source, text, normalized_kind, status, auto_approval, execution_gate)


def http_json(url: str, payload: dict[str, Any] | None = None, token: str | None = None) -> dict[str, Any]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=data, headers=headers, method="POST" if payload is not None else "GET")
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw) if raw else {}


def send_telegram(message: str) -> bool:
    token = os.environ.get("VALLEY_TELEGRAM_TOKEN")
    chat_id = os.environ.get("VALLEY_TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        return False
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    http_json(url, {"chat_id": chat_id, "text": message})
    return True


def poll_telegram_once() -> int:
    token = os.environ.get("VALLEY_TELEGRAM_TOKEN")
    if not token:
        return 0
    state_path = RUNTIME_DIR / "telegram-offset.json"
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    offset = state.get("offset")
    query = f"?timeout=0"
    if offset:
        query += f"&offset={offset}"
    response = http_json(f"https://api.telegram.org/bot{token}/getUpdates{query}")
    count = 0
    max_update_id = offset or 0
    for update in response.get("result", []):
        max_update_id = max(max_update_id, int(update.get("update_id", 0)) + 1)
        message = update.get("message") or update.get("edited_message") or {}
        text = message.get("text")
        if text:
            append_order(TELEGRAM_QUEUE, "telegram", text)
            count += 1
    ensure_runtime()
    state_path.write_text(json.dumps({"offset": max_update_id}, indent=2), encoding="utf-8")
    return count


def poll_whatsapp_web_once() -> int:
    mode = os.environ.get("VALLEY_WHATSAPP_MODE", "web").strip().lower()
    to = os.environ.get("VALLEY_WHATSAPP_WEB_TO") or os.environ.get("VALLEY_WHATSAPP_TO")
    if mode != "web" or not to:
        return 0

    command = [
        "npx.cmd" if os.name == "nt" else "npx",
        "--yes",
        "--package",
        "playwright",
        "node",
        str(ROOT / "scripts" / "whatsapp_web_driver.js"),
        "poll",
    ]
    env = os.environ.copy()
    env["VALLEY_WHATSAPP_WEB_TO"] = to
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=180, check=False)
    if result.returncode != 0:
        raise OSError((result.stderr or result.stdout or "WhatsApp Web poll failed.").strip())

    payload = json.loads(result.stdout or "{}")
    messages = payload.get("messages", [])
    for message in messages:
        append_order(UNIVERSAL_QUEUE, "whatsapp_web", str(message))
    return len(messages)


def send_whatsapp(message: str) -> bool:
    mode = os.environ.get("VALLEY_WHATSAPP_MODE", "web").strip().lower()
    if mode == "web":
        to = os.environ.get("VALLEY_WHATSAPP_WEB_TO") or os.environ.get("VALLEY_WHATSAPP_TO")
        if not to:
            return False

        command = [
            "npx.cmd" if os.name == "nt" else "npx",
            "--yes",
            "--package",
            "playwright",
            "node",
            str(ROOT / "scripts" / "whatsapp_web_driver.js"),
            "send",
        ]
        env = os.environ.copy()
        env["VALLEY_WHATSAPP_WEB_TO"] = to
        env["VALLEY_WHATSAPP_WEB_MESSAGE"] = message
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=180, check=False)
        if result.returncode != 0:
            raise OSError((result.stderr or result.stdout or "WhatsApp Web send failed.").strip())
        return True

    api_url = os.environ.get("VALLEY_WHATSAPP_API_URL")
    token = os.environ.get("VALLEY_WHATSAPP_TOKEN")
    to = os.environ.get("VALLEY_WHATSAPP_TO")
    if not api_url or not token or not to:
        return False
    http_json(api_url, {"to": to, "message": message}, token=token)
    return True


def pulse() -> dict[str, Any]:
    status = write_status()
    message = (
        "Valley Codex status\n"
        f"UTC: {status['generated_at_utc']}\n"
        f"Mode: {status['mode']}\n"
        f"Telegram ready: {status['telegram_ready']}\n"
        f"WhatsApp ready: {status['whatsapp_ready']}\n"
        "Auto approval: safe_only"
    )
    delivered = {
        "telegram": False,
        "whatsapp": False,
    }
    try:
        delivered["telegram"] = send_telegram(message)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        delivered["telegram_error"] = str(exc)
    try:
        delivered["whatsapp"] = send_whatsapp(message)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        delivered["whatsapp_error"] = str(exc)
    status["delivered"] = delivered
    STATUS_PATH.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    return status


def watch(interval_seconds: int) -> None:
    while True:
        try:
            poll_telegram_once()
            poll_whatsapp_web_once()
            pulse()
        except Exception as exc:  # noqa: BLE001 - bridge must keep running and report the fault.
            ensure_runtime()
            error_path = RUNTIME_DIR / "communication-bridge-error.json"
            error_path.write_text(json.dumps({"at": utc_now(), "error": str(exc)}, indent=2), encoding="utf-8")
        time.sleep(interval_seconds)


def main() -> None:
    load_local_env()
    parser = argparse.ArgumentParser(description="Valley Telegram/WhatsApp bridge seguro.")
    parser.add_argument("command", choices=["status", "pulse", "poll-once", "watch", "whatsapp-login", "whatsapp-status"])
    parser.add_argument("--interval", type=int, default=300)
    args = parser.parse_args()

    if args.command == "status":
        print(json.dumps(write_status(), ensure_ascii=False, indent=2))
    elif args.command == "pulse":
        print(json.dumps(pulse(), ensure_ascii=False, indent=2))
    elif args.command == "poll-once":
        print(json.dumps({"telegram_orders": poll_telegram_once(), "at": utc_now()}, indent=2))
    elif args.command == "watch":
        watch(max(30, args.interval))
    elif args.command == "whatsapp-login":
        command = [
            "npx.cmd" if os.name == "nt" else "npx",
            "--yes",
            "--package",
            "playwright",
            "node",
            str(ROOT / "scripts" / "whatsapp_web_driver.js"),
            "login",
        ]
        raise SystemExit(subprocess.call(command, cwd=ROOT, env=os.environ.copy()))
    elif args.command == "whatsapp-status":
        command = [
            "npx.cmd" if os.name == "nt" else "npx",
            "--yes",
            "--package",
            "playwright",
            "node",
            str(ROOT / "scripts" / "whatsapp_web_driver.js"),
            "status",
        ]
        raise SystemExit(subprocess.call(command, cwd=ROOT, env=os.environ.copy()))


if __name__ == "__main__":
    main()
