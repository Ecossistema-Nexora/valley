#!/usr/bin/env python3
"""PROPOSITO: Gerar checklist persistente para refatoracao estrutural assistida.

CONTEXTO: A rotina orienta agentes externos, como Gemini Code Assist, a varrer
pastas e arquivos do Valley, propor renomeacoes seguras, adicionar comentarios
estruturados e deixar evidencias de cada ciclo para o Codex aceitar e revalidar.

REGRAS: Nao apaga arquivos, nao move arquivos automaticamente, nao grava
segredos e nao executa deploy. Toda mudanca externa e aceita por revarredura,
registro no ledger e acionamento do Valley Module Automation Engine.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "tmp" / "runtime"
OUTPUT_DIR = ROOT / "output" / "refactor"
CHECKLIST_JSON = RUNTIME_DIR / "valley-gemini-refactor-checklist.json"
CHECKLIST_MD = OUTPUT_DIR / "VALLEY_GEMINI_REFACTOR_CHECKLIST.md"
CURRENT_TASK_MD = RUNTIME_DIR / "valley-gemini-current-task.md"
TASK_QUEUE_JSONL = RUNTIME_DIR / "valley-gemini-refactor-task-queue.jsonl"
ACCEPTANCE_LEDGER_JSONL = RUNTIME_DIR / "valley-gemini-refactor-acceptance-ledger.jsonl"
STATUS_JSON = RUNTIME_DIR / "valley-gemini-refactor-loop-status.json"
COMPLETION_SIGNAL_JSON = RUNTIME_DIR / "valley-gemini-completion-signal.json"
ACTIVITY_WRAPPER = ROOT / "scripts" / "invoke_valley_module_activity.ps1"
BATCH_SIZE_LIMIT = 5

REQUIRED_HEADERS = ("PROPOSITO:", "CONTEXTO:", "REGRAS:")
TEXT_EXTENSIONS = {
    ".css",
    ".dart",
    ".html",
    ".js",
    ".json",
    ".md",
    ".mongo",
    ".ps1",
    ".py",
    ".sql",
    ".ts",
    ".txt",
    ".yaml",
    ".yml",
}
HEADER_EXTENSIONS = {".dart", ".md", ".ps1", ".py", ".sql", ".ts", ".txt"}
GENERATED_OR_VENDOR_SEGMENTS = {
    ".dart_tool",
    ".git",
    ".playwright",
    ".venv",
    "__pycache__",
    "build",
    "canvaskit",
    "node_modules",
    "tmp",
}
SKIP_PREFIXES = {
    "admin/product/main.dart.js",
    "frontend/flutter/build/",
    "admin/product/flutter_service_worker.js",
}

FILE_MAPPING = {
    "docs/specs/valley-front-end-final-product-proposal.md": "docs/specs/proposta_frontend_final.md",
    "docs/specs/valley-helena-master-spec.md": "docs/specs/helena_especificacao_mestra.md",
    "scripts/generate_manual_pdf.py": "scripts/automacao_gerador_pdf.py",
    "scripts/valley_module_automation.py": "scripts/automacao_sincronizador_modulos.py",
}


@dataclass(frozen=True)
class PendingItem:
    path: str
    kind: str
    severity: str
    detail: str
    suggested_action: str


def utc_now() -> str:
    """Retorna timestamp UTC compacto para ledgers."""

    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def ensure_dirs() -> None:
    """Cria diretorios de saida e runtime."""

    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def relative(path: Path) -> str:
    """Converte caminho absoluto para relativo POSIX."""

    return path.relative_to(ROOT).as_posix()


def is_skipped(path: Path) -> bool:
    """Filtra arquivos gerados, vendor e runtime para evitar ruido."""

    rel = relative(path)
    if any(rel.startswith(prefix) for prefix in SKIP_PREFIXES):
        return True
    return any(part in GENERATED_OR_VENDOR_SEGMENTS for part in path.relative_to(ROOT).parts)


def list_repo_files() -> list[Path]:
    """Lista arquivos versionados e novos sem depender de varredura destrutiva."""

    command = ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, check=False)
    if completed.returncode == 0:
        raw_paths = completed.stdout.decode("utf-8", errors="ignore").split("\0")
        files = [ROOT / item for item in raw_paths if item]
        return sorted(path for path in files if path.is_file() and not is_skipped(path))

    files: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        base = Path(dirpath)
        dirnames[:] = [name for name in dirnames if name not in GENERATED_OR_VENDOR_SEGMENTS]
        for filename in filenames:
            path = base / filename
            if path.is_file() and not is_skipped(path):
                files.append(path)
    return sorted(files)


def read_text(path: Path) -> str:
    """Le texto em UTF-8 com tolerancia a BOM."""

    return path.read_text(encoding="utf-8-sig")


def should_have_structured_header(path: Path) -> bool:
    """Define quais arquivos devem receber header PROPOSITO/CONTEXTO/REGRAS."""

    rel = relative(path)
    if path.suffix.lower() not in HEADER_EXTENSIONS:
        return False
    return rel.startswith(("scripts/", "docs/", "MANUAL_ONLINE/", "PLANOS/"))


def file_digest(paths: Iterable[Path]) -> str:
    """Gera digest leve da lista de arquivos e mtimes."""

    digest = hashlib.sha256()
    for path in paths:
        stat = path.stat()
        digest.update(relative(path).encode("utf-8"))
        digest.update(str(stat.st_mtime_ns).encode("ascii"))
        digest.update(str(stat.st_size).encode("ascii"))
    return digest.hexdigest()


def scan_pending() -> tuple[list[PendingItem], dict[str, object]]:
    """Varre arquivos, mapeia pendencias e retorna resumo."""

    files = list_repo_files()
    pending: list[PendingItem] = []

    for old, new in FILE_MAPPING.items():
        old_path = ROOT / old
        new_path = ROOT / new
        if old_path.exists() and not new_path.exists():
            pending.append(
                PendingItem(
                    path=old,
                    kind="rename_pending",
                    severity="medium",
                    detail=f"Arquivo antigo ainda existe e alvo novo nao existe: {new}",
                    suggested_action=(
                        "Planejar renomeacao, atualizar referencias com rg e validar imports antes de mover."
                    ),
                )
            )

    for path in files:
        rel = relative(path)
        suffix = path.suffix.lower()
        if suffix not in TEXT_EXTENSIONS:
            continue

        try:
            content = read_text(path)
        except UnicodeDecodeError:
            continue

        if should_have_structured_header(path):
            missing = [header for header in REQUIRED_HEADERS if header not in content]
            if missing:
                pending.append(
                    PendingItem(
                        path=rel,
                        kind="structured_header_missing",
                        severity="low",
                        detail=f"Headers ausentes: {', '.join(missing)}",
                        suggested_action=(
                            "Adicionar comentario/header no formato correto do arquivo com PROPOSITO, CONTEXTO e REGRAS."
                        ),
                    )
                )

        if rel.startswith("docs/specs/") and "front-end" in rel and "Hierarquia de Diret" not in content:
            pending.append(
                PendingItem(
                    path=rel,
                    kind="hierarchy_v2_missing",
                    severity="medium",
                    detail="Documento de front-end sem secao de Hierarquia de Diretorios.",
                    suggested_action="Adicionar secao de hierarquia V2 com mapa de pastas e responsabilidade de cada camada.",
                )
            )

    summary = {
        "generated_at_utc": utc_now(),
        "files_scanned": len(files),
        "pending_total": len(pending),
        "pending_by_kind": {},
        "digest": file_digest(files),
    }
    by_kind: dict[str, int] = {}
    for item in pending:
        by_kind[item.kind] = by_kind.get(item.kind, 0) + 1
    summary["pending_by_kind"] = by_kind
    return pending, summary


def write_checklist(pending: list[PendingItem], summary: dict[str, object]) -> None:
    """Escreve checklist JSON e Markdown para acompanhamento humano e externo."""

    ensure_dirs()
    payload = {
        "summary": summary,
        "items": [item.__dict__ for item in pending],
    }
    CHECKLIST_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = [
        "# Valley - Gemini Refactor Checklist",
        "",
        f"- Gerado em UTC: `{summary['generated_at_utc']}`",
        f"- Arquivos varridos: `{summary['files_scanned']}`",
        f"- Pendencias: `{summary['pending_total']}`",
        f"- Digest: `{summary['digest']}`",
        "",
        "## Regras",
        "",
        "- Nao apagar arquivos.",
        "- Nao mover arquivos sem atualizar referencias e validar imports.",
        "- Todo arquivo novo orientador deve conter `PROPOSITO:`, `CONTEXTO:` e `REGRAS:`.",
        "- Ao terminar cada lote, deixar as alteracoes no workspace para aceitacao automatica por revarredura.",
        "",
        "## Checklist",
        "",
    ]
    if not pending:
        lines.append("- [x] Nenhuma pendencia estrutural encontrada.")
    else:
        for index, item in enumerate(pending, start=1):
            lines.append(
                f"- [ ] {index}. `{item.kind}` em `{item.path}` - {item.detail} "
                f"Acao: {item.suggested_action}"
            )
    CHECKLIST_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_next_task(pending: list[PendingItem], batch_size: int) -> dict[str, object]:
    """Gera tarefa atual para agentes Gemini trabalharem em lote seguro."""

    ensure_dirs()
    safe_batch_size = min(max(batch_size, 1), BATCH_SIZE_LIMIT)
    task_id = f"gemini-refactor-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
    batch = pending[:safe_batch_size]
    task = {
        "task_id": task_id,
        "created_at_utc": utc_now(),
        "status": "pending" if batch else "done",
        "batch_size": len(batch),
        "batch_size_limit": BATCH_SIZE_LIMIT,
        "items": [item.__dict__ for item in batch],
        "instructions": [
            "Trabalhar somente os arquivos listados neste lote. Nao passar de 5 arquivos.",
            "Aplicar apenas alteracoes seguras, pequenas e rastreaveis.",
            "Adicionar headers/comentarios estruturados sem quebrar sintaxe.",
            "Para renomeacoes, atualizar referencias antes de mover e deixar evidencia.",
            "Nao mexer em segredos, credenciais, builds gerados, .git, tmp ou node_modules.",
            (
                "Ao terminar, informar ao Codex exatamente: "
                f"GEMINI_DONE task_id={task_id} files=<quantidade> status=done"
            ),
        ],
        "completion_signal_path": COMPLETION_SIGNAL_JSON.relative_to(ROOT).as_posix(),
        "completion_message": f"GEMINI_DONE task_id={task_id} files=<quantidade> status=done",
    }

    lines = [
        f"# {task_id}",
        "",
        "## Instrucoes",
        "",
        *[f"- {item}" for item in task["instructions"]],
        "",
        "## Sinal Obrigatorio de Conclusao",
        "",
        f"- Responder ao Codex: `GEMINI_DONE task_id={task_id} files=<quantidade> status=done`",
        f"- Opcionalmente gravar `{task['completion_signal_path']}` com `task_id`, `status=done` e `files_changed`.",
        "- A proxima tarefa so deve ser emitida depois do aceite por revarredura do Codex.",
        "",
        "## Lote Atual",
        "",
    ]
    if not batch:
        lines.append("- [x] Sem pendencias restantes.")
    else:
        for index, item in enumerate(batch, start=1):
            lines.append(f"- [ ] {index}. `{item.path}`")
            lines.append(f"  - Tipo: `{item.kind}`")
            lines.append(f"  - Detalhe: {item.detail}")
            lines.append(f"  - Acao: {item.suggested_action}")
    CURRENT_TASK_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    with TASK_QUEUE_JSONL.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(task, ensure_ascii=False) + "\n")
    return task


def load_json_file(path: Path) -> dict[str, object]:
    """Carrega JSON opcional de runtime com tolerancia a arquivo ausente."""

    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def current_status() -> dict[str, object]:
    """Retorna o ultimo status persistido da rotina."""

    return load_json_file(STATUS_JSON)


def completion_signal() -> dict[str, object]:
    """Retorna o sinal de conclusao preenchido pelo Gemini, quando houver."""

    return load_json_file(COMPLETION_SIGNAL_JSON)


def completion_matches(task_id: str) -> bool:
    """Confere se o Gemini concluiu exatamente a tarefa pendente atual."""

    signal = completion_signal()
    return (
        bool(task_id)
        and str(signal.get("task_id") or "") == task_id
        and str(signal.get("status") or "").lower() == "done"
    )


def has_waiting_task(status: dict[str, object]) -> bool:
    """Detecta tarefa pendente aguardando sinal do Gemini."""

    current_task = status.get("current_task")
    if not isinstance(current_task, dict):
        return False
    return (
        str(current_task.get("status") or "") == "pending"
        and bool(current_task.get("task_id"))
        and not completion_matches(str(current_task.get("task_id") or ""))
    )


def reuse_waiting_task(status: dict[str, object]) -> dict[str, object]:
    """Reaproveita a tarefa atual quando ainda falta conclusao do Gemini."""

    current_task = status.get("current_task")
    if not isinstance(current_task, dict):
        return {}
    return {
        "task_id": current_task.get("task_id"),
        "created_at_utc": current_task.get("created_at_utc", status.get("updated_at_utc")),
        "status": "pending",
        "batch_size": current_task.get("batch_size", 0),
        "batch_size_limit": BATCH_SIZE_LIMIT,
        "items": current_task.get("items", []),
        "waiting_for_gemini": True,
        "completion_signal_path": COMPLETION_SIGNAL_JSON.relative_to(ROOT).as_posix(),
    }


def reset_completion_signal(previous_task_id: str) -> None:
    """Marca o sinal anterior como aceito para liberar o proximo lote."""

    payload = {
        "task_id": "",
        "status": "waiting",
        "files_changed": [],
        "finished_at_utc": "",
        "accepted_previous_task_id": previous_task_id,
        "accepted_at_utc": utc_now(),
        "message": "Gemini deve preencher este arquivo ou responder GEMINI_DONE ao Codex.",
    }
    COMPLETION_SIGNAL_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def git_snapshot() -> dict[str, object]:
    """Captura status do workspace sem alterar nada."""

    def run_git(args: list[str]) -> str:
        completed = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True, check=False)
        return completed.stdout.strip() if completed.returncode == 0 else completed.stderr.strip()

    return {
        "status_short": run_git(["status", "--short"]),
        "changed_files": run_git(["diff", "--name-only"]).splitlines(),
        "untracked_files": run_git(["ls-files", "--others", "--exclude-standard"]).splitlines(),
    }


def record_acceptance(activity: str, summary: dict[str, object], task: dict[str, object]) -> None:
    """Aceita mudancas externas por registro e revarredura, sem revert ou reset."""

    ensure_dirs()
    payload = {
        "accepted_at_utc": utc_now(),
        "activity": activity,
        "summary": summary,
        "task": {
            "task_id": task.get("task_id"),
            "status": task.get("status"),
            "batch_size": task.get("batch_size"),
        },
        "workspace": git_snapshot(),
        "auto_accept_policy": "accept_by_rescan_no_revert",
        "next_task_policy": "emit_next_batch_only_after_gemini_done_signal",
    }
    with ACCEPTANCE_LEDGER_JSONL.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def invoke_module_activity(activity_name: str, mode: str) -> dict[str, object]:
    """Aciona o Valley Module Automation Engine pelo wrapper obrigatorio."""

    if not ACTIVITY_WRAPPER.exists():
        return {"status": "skipped", "message": "activity wrapper missing"}
    completed = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ACTIVITY_WRAPPER),
            "-ActivityName",
            activity_name,
            "-Mode",
            mode,
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "status": "success" if completed.returncode == 0 else "failed",
        "exit_code": completed.returncode,
        "stdout_tail": completed.stdout[-3000:],
        "stderr_tail": completed.stderr[-3000:],
    }


def write_status(
    command: str,
    summary: dict[str, object],
    task: dict[str, object],
    automation: dict[str, object],
    loop_state: str = "pending",
) -> None:
    """Persiste status da ultima execucao."""

    ensure_dirs()
    payload = {
        "status": "done" if summary.get("pending_total") == 0 else loop_state,
        "command": command,
        "updated_at_utc": utc_now(),
        "summary": summary,
        "current_task": {
            "task_id": task.get("task_id"),
            "created_at_utc": task.get("created_at_utc"),
            "status": task.get("status"),
            "batch_size": task.get("batch_size"),
            "items": task.get("items", []),
            "waiting_for_gemini": task.get("waiting_for_gemini", False),
        },
        "automation": automation,
        "paths": {
            "checklist_json": CHECKLIST_JSON.relative_to(ROOT).as_posix(),
            "checklist_md": CHECKLIST_MD.relative_to(ROOT).as_posix(),
            "current_task_md": CURRENT_TASK_MD.relative_to(ROOT).as_posix(),
            "task_queue_jsonl": TASK_QUEUE_JSONL.relative_to(ROOT).as_posix(),
            "acceptance_ledger_jsonl": ACCEPTANCE_LEDGER_JSONL.relative_to(ROOT).as_posix(),
            "completion_signal_json": COMPLETION_SIGNAL_JSON.relative_to(ROOT).as_posix(),
        },
    }
    STATUS_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def run_cycle(command: str, batch_size: int, engine_mode: str) -> tuple[int, dict[str, object]]:
    """Executa varredura e emite proxima tarefa apenas apos sinal Gemini."""

    pending, summary = scan_pending()
    write_checklist(pending, summary)

    status = current_status()
    accepted_completed_task = ""
    if has_waiting_task(status):
        task = reuse_waiting_task(status)
        loop_state = "waiting_for_gemini"
    else:
        current_task = status.get("current_task")
        if isinstance(current_task, dict):
            task_id = str(current_task.get("task_id") or "")
            if completion_matches(task_id):
                accepted_completed_task = task_id
                reset_completion_signal(task_id)
        task = write_next_task(pending, batch_size)
        loop_state = "pending"

    if accepted_completed_task:
        task["accepted_completed_task_id"] = accepted_completed_task

    record_acceptance(command, summary, task)
    automation = invoke_module_activity(f"gemini-refactor-{command}", engine_mode)
    write_status(command, summary, task, automation, loop_state)
    return int(summary["pending_total"]), summary


def write_completion_template() -> None:
    """Cria template de sinal de conclusao para Gemini preencher quando terminar."""

    ensure_dirs()
    if COMPLETION_SIGNAL_JSON.exists():
        return
    payload = {
        "task_id": "",
        "status": "waiting",
        "files_changed": [],
        "finished_at_utc": "",
        "message": "Gemini deve preencher este arquivo ou responder GEMINI_DONE ao Codex.",
    }
    COMPLETION_SIGNAL_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    """CLI principal da rotina Gemini/Codex."""

    parser = argparse.ArgumentParser(description="Varredura persistente de refatoracao estrutural Valley.")
    parser.add_argument("command", choices=["scan", "next-task", "loop"], help="Acao da rotina.")
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE_LIMIT, help="Quantidade de pendencias por tarefa. Maximo: 5.")
    parser.add_argument("--sleep-seconds", type=int, default=60, help="Pausa entre ciclos no modo loop.")
    parser.add_argument("--max-cycles", type=int, default=1, help="Limite de ciclos para evitar loop irrestrito.")
    parser.add_argument(
        "--engine-mode",
        choices=["checkpoint", "admin", "release", "sync"],
        default="checkpoint",
        help="Modo do Valley Module Automation Engine acionado a cada ciclo.",
    )
    args = parser.parse_args()
    write_completion_template()

    cycles = max(args.max_cycles, 1)
    last_summary: dict[str, object] = {}
    for cycle in range(1, cycles + 1):
        pending_total, last_summary = run_cycle(args.command, args.batch_size, args.engine_mode)
        print(json.dumps({"cycle": cycle, "pending_total": pending_total, "summary": last_summary}, ensure_ascii=False))
        if args.command != "loop" or pending_total == 0:
            break
        if cycle < cycles:
            time.sleep(max(args.sleep_seconds, 1))

    return 0 if int(last_summary.get("pending_total", 0)) == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
