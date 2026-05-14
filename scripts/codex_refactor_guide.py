#!/usr/bin/env python3
"""SCRIPT DE ORIENTACAO CODEX - REFATORACAO ESTRUTURAL

Este script guia o agente na renomeacao e validacao de arquivos.
Refinado para validar a hierarquia V2 e comentarios estruturados.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_HEADERS = ("PROPOSITO:", "CONTEXTO:", "REGRAS:")
ACTIVITY_WRAPPER = ROOT / "scripts" / "invoke_valley_module_activity.ps1"
STATUS_PATH = ROOT / "tmp" / "runtime" / "codex-refactor-guide-status.json"

FILE_MAPPING = {
    "docs/specs/valley-front-end-final-product-proposal.md": "docs/specs/proposta_frontend_final.md",
    "docs/specs/valley-helena-master-spec.md": "docs/specs/helena_especificacao_mestra.md",
    "scripts/generate_manual_pdf.py": "scripts/automacao_gerador_pdf.py",
    "scripts/valley_module_automation.py": "scripts/automacao_sincronizador_modulos.py",
}

DEFAULT_CHECK_FILES = (
    "docs/specs/proposta_frontend_final.md",
    "docs/specs/helena_especificacao_mestra.md",
    "scripts/automacao_gerador_pdf.py",
    "scripts/automacao_sincronizador_modulos.py",
    "scripts/codex_refactor_guide.py",
)


def repo_path(path: str | Path) -> Path:
    """Resolve caminhos relativos a partir da raiz do repo."""

    candidate = Path(path)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read_text(path: Path) -> str:
    """Le arquivo texto em UTF-8 com suporte a BOM."""

    return path.read_text(encoding="utf-8-sig")


def status_entry(kind: str, path: str, status: str, message: str) -> dict[str, str]:
    """Cria entrada padronizada para status JSON."""

    return {
        "kind": kind,
        "path": path,
        "status": status,
        "message": message,
    }


def validate_refactor() -> list[dict[str, str]]:
    """Valida se os caminhos antigos e novos da refatoracao estrutural estao coerentes."""

    print("=== Iniciando Validacao de Estrutura ===")
    results: list[dict[str, str]] = []
    for old, new in FILE_MAPPING.items():
        old_path = repo_path(old)
        new_path = repo_path(new)
        if old_path.exists():
            message = f"O arquivo {old} ainda nao foi movido para {new}."
            print(f"[PENDENTE] {message}")
            results.append(status_entry("refactor", old, "pending", message))
        elif new_path.exists():
            message = f"{new} validado com sucesso."
            print(f"[OK] {message}")
            results.append(status_entry("refactor", new, "ok", message))
        else:
            message = f"Caminho nao encontrado: {new}"
            print(f"[ERRO] {message}")
            results.append(status_entry("refactor", new, "error", message))
    return results


def comment_check(paths: Iterable[str] = DEFAULT_CHECK_FILES) -> list[dict[str, str]]:
    """Valida headers estruturados obrigatorios em novos arquivos orientadores."""

    print("\n=== Verificando Comentarios em PT-BR ===")
    print("[INFO] Todos os novos arquivos devem conter o header: 'PROPOSITO:', 'CONTEXTO:' e 'REGRAS:'.")
    results: list[dict[str, str]] = []
    for raw_path in paths:
        path = repo_path(raw_path)
        if not path.exists():
            message = f"Arquivo nao encontrado para header check: {raw_path}"
            print(f"[PENDENTE] {message}")
            results.append(status_entry("header", raw_path, "pending", message))
            continue

        content = read_text(path)
        missing = [header for header in REQUIRED_HEADERS if header not in content]
        if missing:
            message = f"Headers ausentes em {raw_path}: {', '.join(missing)}"
            print(f"[PENDENTE] {message}")
            results.append(status_entry("header", raw_path, "pending", message))
            continue

        message = f"Headers estruturados encontrados em {raw_path}"
        print(f"[OK] {message}")
        results.append(status_entry("header", raw_path, "ok", message))
    return results


def resolve_existing_mapping_target(file_path: str) -> str:
    """Usa o caminho antigo quando o alvo novo ainda nao foi materializado."""

    path = repo_path(file_path)
    if path.exists():
        return file_path
    for old, new in FILE_MAPPING.items():
        if new == file_path and repo_path(old).exists():
            return old
    return file_path


def hierarchy_check(file_path: str) -> dict[str, str]:
    """Valida se o arquivo possui secao de hierarquia V2."""

    resolved_file_path = resolve_existing_mapping_target(file_path)
    print(f"\n=== Verificando Secao de Hierarquia em {resolved_file_path} ===")
    path = repo_path(resolved_file_path)
    if not path.exists():
        message = f"Arquivo nao encontrado para check: {file_path}"
        print(f"[ERRO] {message}")
        return status_entry("hierarchy", file_path, "error", message)

    content = read_text(path)
    if "Hierarquia de Diretórios" in content or "Hierarquia de Diretorios" in content:
        message = f"Secao de hierarquia encontrada em {resolved_file_path}"
        print(f"[OK] {message}")
        return status_entry("hierarchy", resolved_file_path, "ok", message)

    message = f"Secao de hierarquia ausente em {resolved_file_path}"
    print(f"[PENDENTE] {message}")
    return status_entry("hierarchy", resolved_file_path, "pending", message)


def invoke_module_activity(activity_name: str, mode: str) -> dict[str, object]:
    """Aciona o Valley Module Automation Engine via wrapper persistente."""

    if not ACTIVITY_WRAPPER.exists():
        return {
            "status": "skipped",
            "message": f"Wrapper nao encontrado: {ACTIVITY_WRAPPER}",
        }

    command = [
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
    ]
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    payload: dict[str, object] = {
        "status": "success" if completed.returncode == 0 else "failed",
        "exit_code": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }
    try:
        parsed = json.loads(completed.stdout)
        if isinstance(parsed, dict):
            payload["payload"] = parsed
    except json.JSONDecodeError:
        pass
    return payload


def write_status(results: list[dict[str, str]], automation: dict[str, object]) -> None:
    """Persiste o resultado da rotina sem segredos."""

    STATUS_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "status": "ok" if all(item["status"] != "error" for item in results) else "error",
        "results": results,
        "automation": automation,
    }
    STATUS_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    """Executa o roteiro de refatoracao estrutural e aciona automacao modular."""

    parser = argparse.ArgumentParser(description="Guia Codex para refatoracao estrutural Valley.")
    parser.add_argument(
        "--mode",
        choices=("checkpoint", "admin", "release", "sync"),
        default="checkpoint",
        help="Modo do Valley Module Automation Engine a acionar no final.",
    )
    parser.add_argument(
        "--hierarchy-file",
        default="docs/specs/proposta_frontend_final.md",
        help="Arquivo alvo para validar secao de hierarquia V2.",
    )
    args = parser.parse_args()

    results: list[dict[str, str]] = []
    results.extend(validate_refactor())
    results.extend(comment_check())
    results.append(hierarchy_check(args.hierarchy_file))
    automation = invoke_module_activity("codex-refactor-guide", args.mode)
    write_status(results, automation)

    has_error = any(item["status"] == "error" for item in results)
    automation_failed = automation.get("status") == "failed"
    return 1 if has_error or automation_failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
