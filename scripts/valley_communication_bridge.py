#!/usr/bin/env python3
"""Ponte segura Telegram/WhatsApp para filas Codex do projeto Valley."""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import subprocess
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "config" / "bridge" / "VALLEY_COMMUNICATION_BRIDGE.json"
NOTIFICATION_POLICY_PATH = ROOT / "config" / "bridge" / "VALLEY_NOTIFICATION_POLICY.json"
ENV_PATH = ROOT / ".env"
TELEGRAM_QUEUE = ROOT / "ordem_telegram.md"
UNIVERSAL_QUEUE = ROOT / "ordem_universal.md"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
PLAYWRIGHT_RUNTIME_DIR = ROOT / "tmp" / "node-playwright"
PLAYWRIGHT_NODE_MODULES = PLAYWRIGHT_RUNTIME_DIR / "node_modules"
STATUS_PATH = RUNTIME_DIR / "codex-live-status.json"
CODEX_INBOX_PATH = RUNTIME_DIR / "codex-inbox.jsonl"
WORK_STATUS_PATH = RUNTIME_DIR / "bridge-work-status.json"
WHATSAPP_LINK_STATE_PATH = RUNTIME_DIR / "whatsapp-link-state.json"
APK_WATCH_STATE_PATH = RUNTIME_DIR / "apk-watch-state.json"
DEFAULT_APK_PATH = ROOT / "frontend" / "flutter" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"

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


def load_notification_policy() -> dict[str, Any]:
    default_policy = {
        "telegram": {
            "status_interval_seconds": 300,
            "send_status": True,
            "send_logs": False,
            "send_apk": True,
            "allowed_delivery_kinds": ["status", "apk"],
        }
    }
    if not NOTIFICATION_POLICY_PATH.exists():
        return default_policy
    try:
        payload = json.loads(NOTIFICATION_POLICY_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default_policy

    telegram = payload.get("telegram") or {}
    merged = default_policy["telegram"] | telegram
    return {"telegram": merged}


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
    notification_policy = load_notification_policy()
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
        "notification_policy": notification_policy,
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


def http_multipart(
    url: str,
    fields: dict[str, str],
    file_field: str,
    file_path: Path,
    mime_type: str = "application/octet-stream",
) -> dict[str, Any]:
    boundary = f"----ValleyBoundary{uuid.uuid4().hex}"
    payload = bytearray()

    for key, value in fields.items():
        payload.extend(f"--{boundary}\r\n".encode("utf-8"))
        payload.extend(f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode("utf-8"))
        payload.extend(str(value).encode("utf-8"))
        payload.extend(b"\r\n")

    payload.extend(f"--{boundary}\r\n".encode("utf-8"))
    payload.extend(
        (
            f'Content-Disposition: form-data; name="{file_field}"; '
            f'filename="{file_path.name}"\r\n'
        ).encode("utf-8")
    )
    payload.extend(f"Content-Type: {mime_type}\r\n\r\n".encode("utf-8"))
    payload.extend(file_path.read_bytes())
    payload.extend(b"\r\n")
    payload.extend(f"--{boundary}--\r\n".encode("utf-8"))

    request = urllib.request.Request(
        url,
        data=bytes(payload),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw) if raw else {}


def load_json_file(path: Path, default: dict[str, Any] | None = None) -> dict[str, Any]:
    if not path.exists():
        return {} if default is None else dict(default)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {} if default is None else dict(default)


def default_work_status() -> dict[str, Any]:
    return {
        "activity_name": "Operacao Valley",
        "activity_description": "Monitorando a esteira e mantendo o produto pronto para entrega.",
        "complexity": 2,
        "eta": "00:05:00",
        "progress_percent": 0,
        "next_steps": "Aguardar nova execucao ou atualizar o foco atual.",
        "updated_at_utc": utc_now(),
    }


def load_work_status() -> dict[str, Any]:
    ensure_runtime()
    payload = load_json_file(WORK_STATUS_PATH, default_work_status())
    merged = default_work_status()
    merged.update(payload)
    return merged


def save_work_status(
    *,
    activity_name: str,
    activity_description: str,
    complexity: int,
    eta: str,
    progress_percent: int,
    next_steps: str,
) -> dict[str, Any]:
    ensure_runtime()
    payload = {
        "activity_name": activity_name.strip(),
        "activity_description": activity_description.strip(),
        "complexity": max(1, min(5, complexity)),
        "eta": eta.strip(),
        "progress_percent": max(0, min(100, progress_percent)),
        "next_steps": next_steps.strip(),
        "updated_at_utc": utc_now(),
    }
    WORK_STATUS_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return payload


def build_status_message(status: dict[str, Any], work_status: dict[str, Any]) -> str:
    return (
        "Valley Status 5/5\n"
        f"Nome da atividade: {work_status['activity_name']}\n"
        f"Descricao da atividade: {work_status['activity_description']}\n"
        f"Grau de complexidade: {work_status['complexity']}/5\n"
        f"Tempo previsto para termino: {work_status['eta']}\n"
        f"Percentual concluido: {work_status['progress_percent']}%\n"
        f"Proximos passos naturais: {work_status['next_steps']}\n"
        f"Atualizado em UTC: {work_status['updated_at_utc']}\n"
        f"Telegram pronto: {status['telegram_ready']}\n"
        f"WhatsApp pronto: {status['whatsapp_ready']}"
    )


def upsert_env_value(key: str, value: str) -> None:
    lines: list[str] = []
    replaced = False
    if ENV_PATH.exists():
      lines = ENV_PATH.read_text(encoding="utf-8").splitlines()

    updated: list[str] = []
    for raw_line in lines:
        line = raw_line.rstrip("\n")
        if line.strip().startswith(f"{key}="):
            updated.append(f"{key}={value}")
            replaced = True
        else:
            updated.append(line)

    if not replaced:
        updated.append(f"{key}={value}")

    ENV_PATH.write_text("\n".join(updated).strip() + "\n", encoding="utf-8")
    os.environ[key] = value


def load_whatsapp_link_state() -> dict[str, Any]:
    ensure_runtime()
    return load_json_file(WHATSAPP_LINK_STATE_PATH, {})


def node_command() -> str:
    return "node.exe" if os.name == "nt" else "node"


def npm_command() -> str:
    return "npm.cmd" if os.name == "nt" else "npm"


def ensure_playwright_runtime() -> dict[str, str]:
    """Mantem o Playwright fora do repositorio versionado e visivel ao Node."""

    package_dir = PLAYWRIGHT_NODE_MODULES / "playwright"
    if not package_dir.exists():
        PLAYWRIGHT_RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            [
                npm_command(),
                "install",
                "--prefix",
                str(PLAYWRIGHT_RUNTIME_DIR),
                "--no-save",
                "playwright",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
        if result.returncode != 0:
            raise OSError(
                (result.stderr or result.stdout or "Falha ao instalar Playwright.").strip()
            )

    env = os.environ.copy()
    existing_node_path = env.get("NODE_PATH", "")
    node_path_parts = [str(PLAYWRIGHT_NODE_MODULES)]
    if existing_node_path:
        node_path_parts.append(existing_node_path)
    env["NODE_PATH"] = os.pathsep.join(node_path_parts)
    return env


def whatsapp_driver_command(command: str) -> tuple[list[str], dict[str, str]]:
    env = ensure_playwright_runtime()
    return [
        node_command(),
        str(ROOT / "scripts" / "whatsapp_web_driver.js"),
        command,
    ], env


def save_whatsapp_link_state(payload: dict[str, Any]) -> dict[str, Any]:
    ensure_runtime()
    WHATSAPP_LINK_STATE_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return payload


def clear_whatsapp_link_state() -> None:
    if WHATSAPP_LINK_STATE_PATH.exists():
        WHATSAPP_LINK_STATE_PATH.unlink()


def normalize_phone(raw: str) -> str:
    return "".join(ch for ch in str(raw or "") if ch.isdigit())


def is_valid_pairing_code(raw: str) -> bool:
    candidate = raw.strip().replace(" ", "").replace("-", "")
    return len(candidate) == 8 and candidate.isalnum()


def send_telegram(message: str) -> bool:
    load_local_env()
    token = os.environ.get("VALLEY_TELEGRAM_TOKEN")
    chat_id = os.environ.get("VALLEY_TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        return False
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    http_json(url, {"chat_id": chat_id, "text": message})
    return True


def send_telegram_document(file_path: Path, caption: str = "") -> bool:
    load_local_env()
    token = os.environ.get("VALLEY_TELEGRAM_TOKEN")
    chat_id = os.environ.get("VALLEY_TELEGRAM_CHAT_ID")
    if not token or not chat_id or not file_path.exists():
        return False
    url = f"https://api.telegram.org/bot{token}/sendDocument"
    mime_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    http_multipart(
        url,
        {"chat_id": chat_id, "caption": caption},
        "document",
        file_path,
        mime_type=mime_type,
    )
    return True


def file_sha256(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_apk_watch_state() -> dict[str, Any]:
    ensure_runtime()
    return load_json_file(APK_WATCH_STATE_PATH, {})


def save_apk_watch_state(payload: dict[str, Any]) -> dict[str, Any]:
    ensure_runtime()
    APK_WATCH_STATE_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return payload


def detect_and_send_new_apk(apk_path: Path = DEFAULT_APK_PATH) -> dict[str, Any]:
    load_local_env()
    state = load_apk_watch_state()
    result: dict[str, Any] = {
        "path": str(apk_path),
        "exists": apk_path.exists(),
        "sent": False,
        "reason": "missing",
    }
    if not apk_path.exists():
        return result

    stat = apk_path.stat()
    fingerprint = {
        "sha256": file_sha256(apk_path),
        "size_bytes": stat.st_size,
        "modified_at_epoch": int(stat.st_mtime),
    }
    previous = state.get("apk") or {}
    unchanged = (
        previous.get("sha256") == fingerprint["sha256"]
        and previous.get("size_bytes") == fingerprint["size_bytes"]
        and previous.get("modified_at_epoch") == fingerprint["modified_at_epoch"]
    )
    if unchanged:
        result["reason"] = "unchanged"
        result["apk"] = fingerprint
        return result

    save_apk_watch_state({"apk": fingerprint, "updated_at_utc": utc_now()})
    result["reason"] = "changed"
    result["apk"] = fingerprint

    if not telegram_delivery_allowed("apk"):
        result["reason"] = "changed_but_blocked_by_policy"
        return result

    caption = "Valley APK release atualizado automaticamente"
    result["sent"] = send_telegram_document(apk_path, caption)
    result["reason"] = "sent" if result["sent"] else "send_failed"
    return result


def telegram_delivery_allowed(kind: str) -> bool:
    policy = load_notification_policy().get("telegram", {})
    allowed = set(policy.get("allowed_delivery_kinds", []))
    if kind == "status":
        return bool(policy.get("send_status", True)) and kind in allowed
    if kind == "apk":
        return bool(policy.get("send_apk", True)) and kind in allowed
    if kind == "log":
        return bool(policy.get("send_logs", False)) and kind in allowed
    return kind in allowed


def send_channel_message(source: str, message: str) -> bool:
    if source == "telegram":
        return send_telegram(message)
    if source == "whatsapp_web":
        return send_whatsapp(message)
    return False


def whatsapp_link_summary(phone: str) -> str:
    status_payload = load_json_file(RUNTIME_DIR / "whatsapp-web-status.json", {})
    logged_in = bool(status_payload.get("logged_in"))
    return (
        f"Conexao WhatsApp registrada para {phone}.\n"
        f"Sessao web autenticada: {'sim' if logged_in else 'nao'}.\n"
        "Envie /whatsapp_status para consultar o estado atual."
    )


def handle_control_message(source: str, text: str) -> bool:
    normalized = text.strip()
    lowered = normalized.lower()
    state = load_whatsapp_link_state()

    if lowered in {"/whatsapp", "/ativar_whatsapp", "/connect_whatsapp", "/conectar_whatsapp"}:
        save_whatsapp_link_state(
            {
                "source": source,
                "step": "awaiting_phone",
                "started_at_utc": utc_now(),
            }
        )
        send_channel_message(
            source,
            "Ativacao do WhatsApp iniciada.\nInforme o numero para conexao remota no formato com DDI e DDD.",
        )
        return True

    if lowered == "/whatsapp_status":
        target = os.environ.get("VALLEY_WHATSAPP_WEB_TO") or os.environ.get("VALLEY_WHATSAPP_TO") or "nao configurado"
        send_channel_message(source, whatsapp_link_summary(target))
        return True

    if state.get("source") != source:
        return False

    if state.get("step") == "awaiting_phone":
        phone = normalize_phone(normalized)
        if len(phone) < 10:
            send_channel_message(
                source,
                "Numero invalido. Envie novamente com DDI e DDD, apenas numeros ou formato internacional.",
            )
            return True
        save_whatsapp_link_state(
            {
                **state,
                "step": "awaiting_code",
                "phone": phone,
                "phone_masked": f"+{phone[:2]} {phone[-4:]}",
                "updated_at_utc": utc_now(),
            }
        )
        send_channel_message(
            source,
            "Numero recebido. Agora informe o codigo de 8 caracteres para concluir a conexao.",
        )
        return True

    if state.get("step") == "awaiting_code":
        if not is_valid_pairing_code(normalized):
            send_channel_message(
                source,
                "Codigo invalido. Envie exatamente 8 caracteres alfanumericos.",
            )
            return True
        phone = str(state.get("phone", "")).strip()
        if not phone:
            clear_whatsapp_link_state()
            send_channel_message(
                source,
                "O fluxo perdeu o numero informado. Envie /whatsapp para reiniciar a conexao.",
            )
            return True

        upsert_env_value("VALLEY_WHATSAPP_WEB_TO", phone)
        code_fingerprint = hashlib.sha256(
            normalized.strip().encode("utf-8")
        ).hexdigest()
        save_whatsapp_link_state(
            {
                "source": source,
                "step": "connected",
                "phone": phone,
                "code_sha256": code_fingerprint,
                "connected_at_utc": utc_now(),
            }
        )
        send_channel_message(source, whatsapp_link_summary(phone))
        return True

    return False


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
            if not handle_control_message("telegram", text):
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

    command, env = whatsapp_driver_command("poll")
    env["VALLEY_WHATSAPP_WEB_TO"] = to
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=180, check=False)
    if result.returncode != 0:
        raise OSError((result.stderr or result.stdout or "WhatsApp Web poll failed.").strip())

    payload = json.loads(result.stdout or "{}")
    messages = payload.get("messages", [])
    for message in messages:
        text = str(message)
        if not handle_control_message("whatsapp_web", text):
            append_order(UNIVERSAL_QUEUE, "whatsapp_web", text)
    return len(messages)


def send_whatsapp(message: str) -> bool:
    mode = os.environ.get("VALLEY_WHATSAPP_MODE", "web").strip().lower()
    if mode == "web":
        to = os.environ.get("VALLEY_WHATSAPP_WEB_TO") or os.environ.get("VALLEY_WHATSAPP_TO")
        if not to:
            return False

        command, env = whatsapp_driver_command("send")
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
    work_status = load_work_status()
    message = build_status_message(status, work_status)
    delivered = {
        "telegram": False,
    }
    if telegram_delivery_allowed("status"):
        try:
            delivered["telegram"] = send_telegram(message)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            delivered["telegram_error"] = str(exc)
    else:
        delivered["telegram"] = False
        delivered["telegram_skipped"] = "status_disabled_by_policy"
    status["delivered"] = delivered
    status["work_status"] = work_status
    STATUS_PATH.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    return status


def watch(interval_seconds: int) -> None:
    while True:
        try:
            poll_telegram_once()
            poll_whatsapp_web_once()
            pulse()
            detect_and_send_new_apk()
        except Exception as exc:  # noqa: BLE001 - bridge must keep running and report the fault.
            ensure_runtime()
            error_path = RUNTIME_DIR / "communication-bridge-error.json"
            error_path.write_text(json.dumps({"at": utc_now(), "error": str(exc)}, indent=2), encoding="utf-8")
        time.sleep(interval_seconds)


def main() -> None:
    load_local_env()
    parser = argparse.ArgumentParser(description="Valley Telegram/WhatsApp bridge seguro.")
    parser.add_argument(
        "command",
        choices=[
            "status",
            "pulse",
            "poll-once",
            "watch",
            "whatsapp-login",
            "whatsapp-status",
            "set-work-status",
            "send-telegram-message",
            "send-telegram-document",
        ],
    )
    parser.add_argument("--interval", type=int, default=300)
    parser.add_argument("--message", default="")
    parser.add_argument("--file", default="")
    parser.add_argument("--caption", default="")
    parser.add_argument("--activity-name", default="Operacao Valley")
    parser.add_argument("--activity-description", default="Monitorando a esteira e mantendo o produto pronto para entrega.")
    parser.add_argument("--complexity", type=int, default=2)
    parser.add_argument("--eta", default="00:05:00")
    parser.add_argument("--progress", type=int, default=0)
    parser.add_argument("--next-steps", default="Aguardar nova execucao ou atualizar o foco atual.")
    args = parser.parse_args()

    if args.command == "status":
        print(json.dumps(write_status(), ensure_ascii=False, indent=2))
    elif args.command == "pulse":
        print(json.dumps(pulse(), ensure_ascii=False, indent=2))
    elif args.command == "poll-once":
        print(json.dumps({"telegram_orders": poll_telegram_once(), "at": utc_now()}, indent=2))
    elif args.command == "watch":
        policy_interval = int(
            load_notification_policy().get("telegram", {}).get(
                "status_interval_seconds",
                300,
            )
        )
        watch(max(300, args.interval, policy_interval))
    elif args.command == "whatsapp-login":
        command, env = whatsapp_driver_command("login")
        raise SystemExit(subprocess.call(command, cwd=ROOT, env=env))
    elif args.command == "whatsapp-status":
        command, env = whatsapp_driver_command("status")
        raise SystemExit(subprocess.call(command, cwd=ROOT, env=env))
    elif args.command == "set-work-status":
        payload = save_work_status(
            activity_name=args.activity_name,
            activity_description=args.activity_description,
            complexity=args.complexity,
            eta=args.eta,
            progress_percent=args.progress,
            next_steps=args.next_steps,
        )
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    elif args.command == "send-telegram-message":
        ok = telegram_delivery_allowed("status") and send_telegram(args.message)
        print(json.dumps({"ok": ok}, ensure_ascii=False, indent=2))
    elif args.command == "send-telegram-document":
        file_path = Path(args.file)
        ok = telegram_delivery_allowed("apk") and send_telegram_document(
            file_path,
            args.caption,
        )
        print(
            json.dumps(
                {"ok": ok, "file": str(file_path)},
                ensure_ascii=False,
                indent=2,
            )
        )


if __name__ == "__main__":
    main()
