#!/usr/bin/env python3
# PROPOSITO: Automatizar valley codex token budget no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/valley_codex_token_budget.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Gera estimativa segura de consumo de tokens e ordem de retomada.

Nao consulta saldo real do Codex porque essa informacao nao e exposta ao
workspace. O objetivo e produzir um controle operacional honesto para ciclos
autonomos seguros.
"""

from __future__ import annotations

import json
import os
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / "config" / "autonomy" / "codex_token_budget_policy.json"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
REPORT_PATH = RUNTIME_DIR / "codex-token-budget-report.json"
RESUME_ORDER_PATH = RUNTIME_DIR / "codex-autonomous-resume-order.md"
UNIVERSAL_QUEUE = ROOT / "ordem_universal.md"


def utc_now() -> datetime:
    return datetime.now(UTC).replace(microsecond=0)


def load_policy() -> dict[str, Any]:
    return json.loads(POLICY_PATH.read_text(encoding="utf-8"))


def int_env(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def build_report() -> dict[str, Any]:
    policy = load_policy()
    activities = policy["activity_estimates"]
    total_estimated = sum(int(item["estimated_tokens"]) for item in activities)
    default_budget = int(policy["default_estimated_session_budget_tokens"])
    reserve = int(policy["reserve_tokens_before_pause"])
    total_budget = int_env("CODEX_TOTAL_TOKEN_BUDGET", default_budget)
    used_tokens = int_env("CODEX_USED_TOKENS", 0)
    estimated_balance = int_env(
        "CODEX_ESTIMATED_TOKEN_BALANCE",
        max(0, total_budget - used_tokens),
    )
    usable = max(0, estimated_balance - reserve)
    cycles_before_pause = usable // total_estimated if total_estimated else 0
    minutes = int(policy["replenishment_policy"]["default_resume_after_minutes"])
    resume_at = utc_now() + timedelta(minutes=minutes)

    return {
        "generated_at_utc": utc_now().isoformat().replace("+00:00", "Z"),
        "actual_codex_token_balance_available": False,
        "actual_balance_note": policy["actual_balance_note"],
        "operator_reported_total_budget_tokens": total_budget,
        "operator_reported_used_tokens": used_tokens,
        "estimated_balance_tokens": estimated_balance,
        "reserve_tokens_before_pause": reserve,
        "estimated_tokens_per_safe_cycle": total_estimated,
        "estimated_safe_cycles_before_pause": cycles_before_pause,
        "estimated_resume_at_utc": resume_at.isoformat().replace("+00:00", "Z"),
        "activity_estimates": activities,
        "safe_cycle_commands": policy["safe_cycle_commands"],
        "blocked_without_manual_review": policy["blocked_without_manual_review"],
    }


def write_resume_order(report: dict[str, Any]) -> None:
    lines = [
        "---",
        "source: codex",
        "kind: documentation_update",
        "status: pending",
        "priority: normal",
        "codex_route: auto_start",
        "execution_gate: safe_only",
        f"received_at_utc: {report['generated_at_utc']}",
        "auto_approval: safe_only",
        "---",
        "Retomar o ciclo autonomo seguro Valley quando houver nova janela de tokens.",
        "",
        f"Saldo real disponivel: nao exposto pelo ambiente Codex local.",
        f"Saldo estimado usado: {report['estimated_balance_tokens']} tokens.",
        f"Consumo estimado por ciclo seguro: {report['estimated_tokens_per_safe_cycle']} tokens.",
        f"Reserva antes de pausar: {report['reserve_tokens_before_pause']} tokens.",
        f"Previsao de retomada: {report['estimated_resume_at_utc']}.",
        "",
        "Executar somente comandos seguros do ciclo natural:",
    ]
    lines.extend(f"- `{command}`" for command in report["safe_cycle_commands"])
    lines.extend(
        [
            "",
            "Nao executar deploy, push, apply em banco, pagamentos, delecao, reset, rotação de segredos ou operacoes destrutivas sem revisao manual.",
            "",
        ]
    )
    content = "\n".join(lines)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    RESUME_ORDER_PATH.write_text(content, encoding="utf-8")
    with UNIVERSAL_QUEUE.open("a", encoding="utf-8") as handle:
        handle.write("\n" + content)


def main() -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    report = build_report()
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    write_resume_order(report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
