"""Recalculate PLANOS progress columns from per-plan checklists."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLANOS_DIR = ROOT / "PLANOS"
INDEX_PATH = PLANOS_DIR / "INDEX.md"
RULE_PATH = PLANOS_DIR / "REGRA_PROGRESSO.md"

CHECK_RE = re.compile(r"^\s*-\s+\[([ xX])\]\s+")
LINK_RE = re.compile(r"\]\((?:\./)?([^)]+)\)")
SUMMARY_BEGIN = "<!-- progresso:inicio -->"
SUMMARY_END = "<!-- progresso:fim -->"


@dataclass
class IndexRow:
    versao: str
    criado_em_brt: str
    arquivo: str
    status: str
    escopo: str
    ultima_atualizacao_brt: str
    done: int
    total: int

    @property
    def produced_percent(self) -> float:
        if self.total <= 0:
            return 100.0 if self.status.strip().lower() == "concluido" else 0.0
        return (self.done / self.total) * 100

    @property
    def remaining_percent(self) -> float:
        return max(0.0, 100.0 - self.produced_percent)

    @property
    def steps_label(self) -> str:
        return f"{self.done}/{self.total}" if self.total else "0/0"


def parse_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def format_percent(value: float) -> str:
    return f"{value:.1f}%"


def plan_path_from_cell(cell: str) -> Path | None:
    match = LINK_RE.search(cell)
    if not match:
        return None
    return PLANOS_DIR / match.group(1)


def checklist_counts(path: Path | None) -> tuple[int, int]:
    if path is None or not path.exists():
        return 0, 0
    done = 0
    total = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        match = CHECK_RE.match(line)
        if not match:
            continue
        total += 1
        if match.group(1).lower() == "x":
            done += 1
    return done, total


def read_index_rows() -> list[IndexRow]:
    rows: list[IndexRow] = []
    for line in INDEX_PATH.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped.startswith("| v"):
            continue
        cells = parse_table_row(stripped)
        if len(cells) < 6:
            continue
        ultima_atualizacao = cells[8] if len(cells) >= 9 else cells[5]
        done, total = checklist_counts(plan_path_from_cell(cells[2]))
        rows.append(
            IndexRow(
                versao=cells[0],
                criado_em_brt=cells[1],
                arquivo=cells[2],
                status=cells[3],
                escopo=cells[4],
                ultima_atualizacao_brt=ultima_atualizacao,
                done=done,
                total=total,
            )
        )
    return rows


def build_rule(total_done: int, total_steps: int) -> str:
    produced = (total_done / total_steps * 100) if total_steps else 0.0
    remaining = max(0.0, 100.0 - produced)
    return "\n".join(
        [
            "# Regra de Progresso dos Planos",
            "",
            "## Regra obrigatoria",
            "",
            "- Todo plano persistido em `PLANOS/` deve ter checklist de etapas.",
            "- Cada etapa deve usar `- [ ]` enquanto estiver pendente e `- [x]` quando estiver concluida.",
            "- A cada nova acao concluida, o plano ativo e o `PLANOS/INDEX.md` devem ser atualizados.",
            "- O progresso produzido e calculado por etapas concluidas sobre etapas totais.",
            "- O percentual faltante e `100% - progresso produzido`.",
            "- O acumulado do `INDEX.md` e calculado desde o primeiro plano listado no indice.",
            "",
            "## Comando canonico",
            "",
            "```powershell",
            "python scripts\\update_planos_progress.py",
            "```",
            "",
            "## Progresso acumulado atual",
            "",
            f"- Etapas concluidas: `{total_done}/{total_steps}`.",
            f"- Produzido: `{format_percent(produced)}`.",
            f"- Falta produzir: `{format_percent(remaining)}`.",
            "",
        ]
    )


def build_index(rows: list[IndexRow]) -> str:
    total_done = sum(row.done for row in rows)
    total_steps = sum(row.total for row in rows)
    produced = (total_done / total_steps * 100) if total_steps else 0.0
    remaining = max(0.0, 100.0 - produced)
    summary = "\n".join(
        [
            SUMMARY_BEGIN,
            "## Progresso acumulado",
            "",
            "- Regra: cada item de checklist dos planos conta como uma etapa.",
            "- Atualize este indice depois de cada acao concluida com `python scripts\\update_planos_progress.py`.",
            f"- Etapas concluidas desde o primeiro plano do indice: `{total_done}/{total_steps}`.",
            f"- Produzido desde o Plano 1: `{format_percent(produced)}`.",
            f"- Falta produzir para a conclusao final acumulada: `{format_percent(remaining)}`.",
            SUMMARY_END,
            "",
        ]
    )
    lines = [
        "# INDEX",
        "",
        summary,
        "| versao | criado_em_brt | arquivo | status | escopo | etapas | produzido | falta_produzir | ultima_atualizacao_brt |",
        "| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- |",
    ]
    for row in rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    row.versao,
                    row.criado_em_brt,
                    row.arquivo,
                    row.status,
                    row.escopo,
                    row.steps_label,
                    format_percent(row.produced_percent),
                    format_percent(row.remaining_percent),
                    row.ultima_atualizacao_brt,
                ]
            )
            + " |"
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    rows = read_index_rows()
    total_done = sum(row.done for row in rows)
    total_steps = sum(row.total for row in rows)
    INDEX_PATH.write_text(build_index(rows), encoding="utf-8")
    RULE_PATH.write_text(build_rule(total_done, total_steps), encoding="utf-8")
    produced = (total_done / total_steps * 100) if total_steps else 0.0
    remaining = max(0.0, 100.0 - produced)
    print(f"Planos indexados: {len(rows)}")
    print(f"Etapas: {total_done}/{total_steps}")
    print(f"Produzido: {format_percent(produced)}")
    print(f"Falta produzir: {format_percent(remaining)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
