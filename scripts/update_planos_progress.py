# PROPOSITO: Automatizar update planos progress no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/update_planos_progress.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Recalculate PLANOS progress columns from per-plan checklists."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLANOS_DIR = ROOT / "PLANOS"
INDEX_PATH = PLANOS_DIR / "INDEX.md"
RULE_PATH = PLANOS_DIR / "REGRA_PROGRESSO.md"

CHECK_RE = re.compile(r"^\s*-\s+\[([ xX])\]\s+")
LINK_RE = re.compile(r"\]\((?:\./)?([^)]+)\)")
PLAN_FILE_RE = re.compile(
    r"^(v\d{3})__(\d{8})-(\d{6})-brt__(.+)\.md$",
    re.IGNORECASE,
)
SUMMARY_BEGIN = "<!-- progresso:inicio -->"
SUMMARY_END = "<!-- progresso:fim -->"
INDEX_HEADER = "\n".join(
    [
        "<!--",
        "PROPOSITO: Documentar INDEX no escopo operacional do Valley.",
        "CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/INDEX.md.",
        "REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.",
        "-->",
        "",
    ]
)
RULE_HEADER = "\n".join(
    [
        "<!--",
        "PROPOSITO: Documentar REGRA PROGRESSO no escopo operacional do Valley.",
        "CONTEXTO: Este arquivo registra a regra obrigatoria de progresso e checklist dos planos.",
        "REGRAS: Manter contagem automatizada, preservar rastreabilidade e atualizar apos cada acao concluida.",
        "-->",
        "",
    ]
)


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


def created_at_from_plan_filename(path: Path) -> tuple[str, str] | None:
    match = PLAN_FILE_RE.match(path.name)
    if not match:
        return None
    version = match.group(1).lower()
    raw_date = match.group(2)
    raw_time = match.group(3)
    created = (
        f"{raw_date[0:4]}-{raw_date[4:6]}-{raw_date[6:8]} "
        f"{raw_time[0:2]}:{raw_time[2:4]}:{raw_time[4:6]} BRT"
    )
    return version, created


def plan_scope_from_file(path: Path) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return re.sub(r"^#\s+v\d{3}\s+-\s+", "", stripped, flags=re.IGNORECASE)
        if stripped.startswith("CONTEXTO:"):
            return stripped.removeprefix("CONTEXTO:").strip()
    return path.stem


def mtime_brt_label(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S BRT")


def discover_plan_rows(existing_rows: list[IndexRow]) -> list[IndexRow]:
    rows_by_version = {row.versao.lower(): row for row in existing_rows}
    for path in sorted(PLANOS_DIR.glob("v*.md")):
        parsed = created_at_from_plan_filename(path)
        if parsed is None:
            continue
        version, created = parsed
        if version in rows_by_version:
            continue
        done, total = checklist_counts(path)
        status = "concluido" if total and done == total else "em_andamento"
        rows_by_version[version] = IndexRow(
            versao=version,
            criado_em_brt=created,
            arquivo=f"[{path.name}](./{path.name})",
            status=status,
            escopo=plan_scope_from_file(path),
            ultima_atualizacao_brt=mtime_brt_label(path),
            done=done,
            total=total,
        )
    return sorted(rows_by_version.values(), key=lambda row: row.versao)


def read_index_rows() -> list[IndexRow]:
    rows: list[IndexRow] = []
    for line in INDEX_PATH.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped.startswith("| v"):
            continue
        cells = parse_table_row(stripped)
        if len(cells) < 6:
            continue
        if not re.fullmatch(r"v\d{3}", cells[0]):
            continue
        plan_path = plan_path_from_cell(cells[2])
        if plan_path is None or not plan_path.exists():
            continue
        ultima_atualizacao = cells[8] if len(cells) >= 9 else cells[5]
        done, total = checklist_counts(plan_path)
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
    return discover_plan_rows(rows)


def build_rule(total_done: int, total_steps: int) -> str:
    produced = (total_done / total_steps * 100) if total_steps else 0.0
    remaining = max(0.0, 100.0 - produced)
    return RULE_HEADER + "\n".join(
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
        INDEX_HEADER.rstrip(),
        "",
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
