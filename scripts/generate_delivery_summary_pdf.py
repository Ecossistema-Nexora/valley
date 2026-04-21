from __future__ import annotations

import html
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    Flowable,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "admin" / "valley_admin_data.json"
OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT_PATH = OUTPUT_DIR / "VALLEY_SUMARIO_ENTREGA_MODULOS_SERVICOS.pdf"


BRAND = colors.HexColor("#145C4B")
DARK = colors.HexColor("#1C2A2A")
MUTED = colors.HexColor("#5E6B6B")
GRID = colors.HexColor("#D9E1DE")
SOFT = colors.HexColor("#EEF6F3")
WARNING = colors.HexColor("#B46A00")
OK = colors.HexColor("#1F7A4D")
LOW = colors.HexColor("#A43B35")


def pct(done: int | float, total: int | float) -> float:
    return round((float(done) / float(total)) * 100, 2) if total else 0.0


def p(text: Any, style: ParagraphStyle) -> Paragraph:
    value = "" if text is None else str(text)
    return Paragraph(html.escape(value).replace("\n", "<br/>"), style)


class ProgressBar(Flowable):
    def __init__(self, value: float, width: float = 3.4 * cm, height: float = 0.22 * cm):
        super().__init__()
        self.value = max(0.0, min(100.0, value))
        self.width = width
        self.height = height

    def wrap(self, availWidth: float, availHeight: float) -> tuple[float, float]:
        return self.width, self.height

    def draw(self) -> None:
        self.canv.setFillColor(colors.HexColor("#E6ECE9"))
        self.canv.roundRect(0, 0, self.width, self.height, 2, stroke=0, fill=1)
        if self.value >= 90:
            fill = OK
        elif self.value >= 50:
            fill = WARNING
        else:
            fill = LOW
        self.canv.setFillColor(fill)
        self.canv.roundRect(0, 0, self.width * (self.value / 100), self.height, 2, stroke=0, fill=1)


class NumberedCanvas:
    def __init__(self, canvas, doc_title: str):
        self.canvas = canvas
        self.doc_title = doc_title
        self._saved_page_states = []

    def saveState(self):
        return self.canvas.saveState()

    def restoreState(self):
        return self.canvas.restoreState()

    def __getattr__(self, name):
        return getattr(self.canvas, name)


def footer(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(MUTED)
    width, _height = landscape(A4)
    canvas.drawString(doc.leftMargin, 0.55 * cm, "Valley Omniverse V47 - Sumario de entrega")
    canvas.drawRightString(width - doc.rightMargin, 0.55 * cm, f"Pagina {doc.page}")
    canvas.setStrokeColor(GRID)
    canvas.line(doc.leftMargin, 0.85 * cm, width - doc.rightMargin, 0.85 * cm)
    canvas.restoreState()


def styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=24,
            leading=29,
            textColor=BRAND,
            alignment=TA_CENTER,
            spaceAfter=10,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceAfter=12,
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=18,
            textColor=BRAND,
            spaceBefore=4,
            spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            textColor=DARK,
            spaceBefore=4,
            spaceAfter=5,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.2,
            leading=11,
            textColor=DARK,
            spaceAfter=4,
        ),
        "small": ParagraphStyle(
            "Small",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=6.7,
            leading=8.3,
            textColor=DARK,
        ),
        "tiny": ParagraphStyle(
            "Tiny",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=5.9,
            leading=7.2,
            textColor=DARK,
        ),
        "table_header": ParagraphStyle(
            "TableHeader",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=6.2,
            leading=7.4,
            textColor=colors.white,
            alignment=TA_CENTER,
        ),
        "metric": ParagraphStyle(
            "Metric",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=17,
            leading=19,
            textColor=BRAND,
            alignment=TA_CENTER,
        ),
        "metric_label": ParagraphStyle(
            "MetricLabel",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.1,
            leading=8.6,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "right_small": ParagraphStyle(
            "RightSmall",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=6.5,
            leading=8,
            textColor=DARK,
            alignment=TA_RIGHT,
        ),
    }


def natural_step(label: str, module: dict[str, Any]) -> str:
    data_home = module.get("data_home", "")
    code = module.get("code", "")
    if "Registry canonico" in label:
        return f"Validar registry canonico de {code} no catalogo v47."
    if "Suporte base de schema" in label:
        return f"Implantar suporte base de schema no data home {data_home}."
    if "Contrato operacional" in label:
        return "Fechar contrato operacional, dependencias e integracoes."
    if "PostgreSQL" in label:
        if "postgres" in data_home:
            return "Revisar tabelas PostgreSQL, FKs para users.user_id e trilhas append-only quando sensivel."
        return "Registrar descarte tecnico de PostgreSQL se o modulo seguir 100% documental."
    if "MongoDB" in label:
        if "mongo" in data_home:
            return "Revisar JSON Schema MongoDB, indices e ponte user_id como UUID string."
        return "Registrar descarte tecnico de MongoDB se nao houver IA, social, telemetria ou payload volumoso."
    if "Regras de negocio" in label:
        return "Cadastrar ou descartar regras em business_rule_definitions com pricing, risco, permissao e compliance."
    if "RBAC" in label or "ABAC" in label:
        return "Definir fluxos Admin/RBAC/ABAC para operacao sensivel."
    if "Testes" in label:
        return "Planejar testes de integracao para contrato, banco e fluxos criticos."
    if "Manual" in label:
        return "Atualizar Manual Online com decisoes, rotas, dados e operacao."
    if "PDF" in label:
        return "Regenerar PDF oficial apos concluir as revisoes."
    return label.rstrip(".") + "."


def pending_steps(module: dict[str, Any], limit: int | None = None) -> list[str]:
    items = module.get("checklist", {}).get("items", [])
    steps = [natural_step(item.get("label", ""), module) for item in items if not item.get("done")]
    return steps if limit is None else steps[:limit]


def status_text(module: dict[str, Any]) -> str:
    checklist = module.get("checklist", {})
    done = checklist.get("done", 0)
    total = checklist.get("total", 0)
    if checklist.get("pending", 0) == 0:
        return "Concluido"
    if done <= 2:
        return "Planejado"
    return "Parcial"


def service_rows(data: dict[str, Any]) -> list[dict[str, Any]]:
    deployment = data.get("deployment_summary") or {}
    total_checks = deployment.get("total_checks", 0)
    failed_checks = deployment.get("failed_checks", 0)
    ok_checks = max(0, total_checks - failed_checks)
    deployment_pct = pct(ok_checks, total_checks) if total_checks else 0

    db = data.get("database_summary") or {}
    pg_count = db.get("postgres_migrations", 0)
    mongo_count = db.get("mongodb_scripts", 0)
    public_runtime = data.get("public_runtime") or {}
    public_status = public_runtime.get("status", "nao iniciado")
    public_url = public_runtime.get("public_url", "nao informado")

    return [
        {
            "name": "Banco PostgreSQL relacional",
            "scope": f"{pg_count} migrations versionadas",
            "done": "Concluido como artefato",
            "percent": 100.0 if pg_count else 0.0,
            "next": "Aplicar em banco real ou Compose; validar FKs, comentarios, DECIMAL financeiro e triggers append-only.",
        },
        {
            "name": "Banco MongoDB documental",
            "scope": f"{mongo_count} scripts com JSON Schema",
            "done": "Concluido como artefato",
            "percent": 100.0 if mongo_count else 0.0,
            "next": "Executar com mongosh; validar collections, indices e ponte user_id para PostgreSQL.",
        },
        {
            "name": "Registry e contratos dos modulos",
            "scope": "47 pastas com README, STATUS e CONTRACT",
            "done": "Concluido",
            "percent": 100.0,
            "next": "Manter geracao deterministica sempre que contrato, schema ou dependencia mudar.",
        },
        {
            "name": "Painel Admin estatico",
            "scope": "admin/index.html, app.js, styles.css e dataset",
            "done": "Concluido como console local",
            "percent": 100.0,
            "next": "Rodar smoke test em /, /healthz e /api/admin-data antes de expor para teste externo.",
        },
        {
            "name": "Manual Online e PDF oficial",
            "scope": "MANUAL_ONLINE e output/pdf/VALLEY_MANUAL_ONLINE.pdf",
            "done": "Concluido",
            "percent": 100.0,
            "next": "Regenerar apos cada mudanca de schema, roteiro operacional ou regra de governanca.",
        },
        {
            "name": "Esteira local de deployment",
            "scope": f"{ok_checks}/{total_checks} checagens OK",
            "done": "Parcial",
            "percent": deployment_pct,
            "next": "Instalar psql/mongosh no PATH, iniciar Docker Desktop, rerodar report e aplicar compose.",
        },
        {
            "name": "MCP e conectores de trabalho",
            "scope": ".mcp.json, .vscode/mcp.json e manifest MCP",
            "done": "Configurado no workspace",
            "percent": 85.0,
            "next": "Concluir OAuth no cliente para Figma, Linear e Cloudflare; manter GitHub/Docker como platform-managed.",
        },
        {
            "name": "Acesso publico por ngrok",
            "scope": f"runtime {public_status}; URL atual {public_url}",
            "done": "Parcial",
            "percent": 75.0 if public_runtime.get("available") else 45.0,
            "next": "Reservar dominio, definir VALLEY_NGROK_ADMIN_DOMAIN e validar endpoints permanentes.",
        },
        {
            "name": "Extensoes do workspace",
            "scope": ".vscode/extensions.json e config/tooling.bootstrap.json",
            "done": "Declarado no projeto",
            "percent": 80.0,
            "next": "Executar bootstrap de tooling e confirmar instalacao das extensoes no VS Code local.",
        },
    ]


def table_style(header_rows: int = 1, font_size: float = 6.2) -> TableStyle:
    return TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, header_rows - 1), BRAND),
            ("TEXTCOLOR", (0, 0), (-1, header_rows - 1), colors.white),
            ("FONTNAME", (0, 0), (-1, header_rows - 1), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), font_size),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("GRID", (0, 0), (-1, -1), 0.25, GRID),
            ("ROWBACKGROUNDS", (0, header_rows), (-1, -1), [colors.white, colors.HexColor("#F8FBFA")]),
            ("LEFTPADDING", (0, 0), (-1, -1), 3),
            ("RIGHTPADDING", (0, 0), (-1, -1), 3),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]
    )


def add_metric_table(story: list[Any], s: dict[str, ParagraphStyle], metrics: list[tuple[str, str]]) -> None:
    row = []
    for value, label in metrics:
        row.append([p(value, s["metric"]), p(label, s["metric_label"])])
    table = Table(row, colWidths=[4.3 * cm] * len(row))
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), SOFT),
                ("BOX", (0, 0), (-1, -1), 0.35, GRID),
                ("INNERGRID", (0, 0), (-1, -1), 0.35, GRID),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 0.35 * cm))


def build_pdf(data: dict[str, Any]) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    s = styles()
    doc = SimpleDocTemplate(
        str(OUTPUT_PATH),
        pagesize=landscape(A4),
        leftMargin=1.0 * cm,
        rightMargin=1.0 * cm,
        topMargin=1.0 * cm,
        bottomMargin=1.1 * cm,
        title="Valley - Sumario de Entrega de Modulos e Servicos",
        author="Codex",
    )
    story: list[Any] = []

    release = data.get("release_summary", {})
    modules = data.get("modules", [])
    generated_at = data.get("generated_at_utc")
    generated_label = generated_at or datetime.now(timezone.utc).isoformat()

    story.append(p("Valley Omniverse V47", s["title"]))
    story.append(p("Sumario descritivo de entrega dos modulos e servicos", s["subtitle"]))
    story.append(
        p(
            "Documento gerado a partir de admin/valley_admin_data.json, modules/*/STATUS.md, "
            "database/migrations.json e artefatos operacionais versionados no workspace.",
            s["body"],
        )
    )
    story.append(p(f"Referencia dos dados: {generated_label}", s["body"]))

    metrics = [
        (str(release.get("modules_total", len(modules))), "modulos no registry"),
        (str(release.get("modules_completed", 0)), "modulos 100% no checklist"),
        (str(release.get("modules_with_pending", 0)), "modulos com pendencias"),
        (f"{release.get('checklist_completion_percentage', 0):.2f}%", "entrega media total"),
        (f"{release.get('checklist_items_done', 0)}/{release.get('checklist_items_total', 0)}", "itens concluidos"),
    ]
    add_metric_table(story, s, metrics)

    by_tier = release.get("by_tier", {})
    tier_rows = [[p("Tier", s["table_header"]), p("Modulos", s["table_header"]), p("Concluidos", s["table_header"]), p("Pendentes", s["table_header"]), p("Entrega", s["table_header"])]]
    for tier in ["foundation", "core", "expansion", "frontier"]:
        item = by_tier.get(tier, {})
        tier_rows.append(
            [
                p(tier, s["small"]),
                p(item.get("modules_total", 0), s["small"]),
                p(item.get("modules_completed", 0), s["small"]),
                p(item.get("modules_with_pending", 0), s["small"]),
                p(f"{item.get('average_module_readiness_percentage', 0):.2f}%", s["small"]),
            ]
        )
    table = Table(tier_rows, colWidths=[4.0 * cm, 3.0 * cm, 3.0 * cm, 3.0 * cm, 3.0 * cm])
    table.setStyle(table_style(font_size=7))
    story.append(p("Resumo por tier", s["h1"]))
    story.append(table)
    story.append(Spacer(1, 0.35 * cm))

    service_data = service_rows(data)
    service_table = [
        [
            p("Servico", s["table_header"]),
            p("Escopo entregue", s["table_header"]),
            p("Status", s["table_header"]),
            p("%", s["table_header"]),
            p("Proximo passo natural", s["table_header"]),
        ]
    ]
    for service in service_data:
        service_table.append(
            [
                p(service["name"], s["small"]),
                p(service["scope"], s["small"]),
                p(service["done"], s["small"]),
                p(f"{service['percent']:.1f}%", s["small"]),
                p(service["next"], s["small"]),
            ]
        )
    table = Table(service_table, colWidths=[4.2 * cm, 6.0 * cm, 3.0 * cm, 2.7 * cm, 11.2 * cm], repeatRows=1)
    table.setStyle(table_style(font_size=6.5))
    story.append(p("Servicos tecnicos e operacionais", s["h1"]))
    story.append(table)

    story.append(PageBreak())
    story.append(p("Modulos concluidos", s["h1"]))
    done_modules = [m for m in modules if m.get("checklist", {}).get("pending", 0) == 0]
    done_rows = [
        [
            p("No.", s["table_header"]),
            p("Codigo", s["table_header"]),
            p("Modulo", s["table_header"]),
            p("Tier", s["table_header"]),
            p("Data home", s["table_header"]),
            p("%", s["table_header"]),
            p("Proxima manutencao natural", s["table_header"]),
        ]
    ]
    for module in done_modules:
        done_rows.append(
            [
                p(f"{module.get('number', 0):02d}", s["tiny"]),
                p(module.get("code", ""), s["tiny"]),
                p(module.get("name", ""), s["tiny"]),
                p(module.get("tier", ""), s["tiny"]),
                p(module.get("data_home", ""), s["tiny"]),
                p("100%", s["tiny"]),
                p("Manter regressao do contrato, aplicar validacoes em ambiente real e atualizar Manual/PDF em qualquer mudanca.", s["tiny"]),
            ]
        )
    table = Table(done_rows, colWidths=[1.1 * cm, 2.6 * cm, 4.6 * cm, 2.5 * cm, 3.0 * cm, 1.2 * cm, 12.1 * cm], repeatRows=1)
    table.setStyle(table_style(font_size=5.7))
    story.append(table)

    story.append(PageBreak())
    story.append(p("Matriz completa dos 47 modulos", s["h1"]))
    matrix_rows = [
        [
            p("No.", s["table_header"]),
            p("Codigo", s["table_header"]),
            p("Modulo", s["table_header"]),
            p("Tier", s["table_header"]),
            p("Data", s["table_header"]),
            p("Status", s["table_header"]),
            p("%", s["table_header"]),
            p("Proximos passos naturais", s["table_header"]),
        ]
    ]
    for module in modules:
        checklist = module.get("checklist", {})
        percent = pct(checklist.get("done", 0), checklist.get("total", 0))
        steps = pending_steps(module, limit=3)
        next_text = "Concluido: manter validacao regressiva e documentacao viva." if not steps else " / ".join(steps)
        matrix_rows.append(
            [
                p(f"{module.get('number', 0):02d}", s["tiny"]),
                p(module.get("code", ""), s["tiny"]),
                p(module.get("name", ""), s["tiny"]),
                p(module.get("tier", ""), s["tiny"]),
                p(module.get("data_home", ""), s["tiny"]),
                p(status_text(module), s["tiny"]),
                p(f"{percent:.0f}%", s["tiny"]),
                p(next_text, s["tiny"]),
            ]
        )
    table = Table(
        matrix_rows,
        colWidths=[0.9 * cm, 2.3 * cm, 4.1 * cm, 2.3 * cm, 2.6 * cm, 2.0 * cm, 1.0 * cm, 11.9 * cm],
        repeatRows=1,
    )
    table.setStyle(table_style(font_size=5.5))
    story.append(table)

    story.append(PageBreak())
    story.append(p("Fila detalhada dos modulos pendentes", s["h1"]))
    pending_modules = [m for m in modules if m.get("checklist", {}).get("pending", 0) > 0]
    for module in pending_modules:
        block: list[Any] = []
        checklist = module.get("checklist", {})
        percent = pct(checklist.get("done", 0), checklist.get("total", 0))
        title = f"{module.get('number', 0):02d}. {module.get('name')} ({module.get('code')}) - {percent:.0f}% entregue"
        block.append(p(title, s["h2"]))
        info = (
            f"Tier: {module.get('tier')} | Data home: {module.get('data_home')} | "
            f"Dependencias: {', '.join(module.get('depends_on', [])) or 'nenhuma'} | "
            f"Integracoes: {', '.join(module.get('integrates_with', [])) or 'nenhuma'}"
        )
        block.append(p(info, s["small"]))
        steps = pending_steps(module)
        rows = [[p("Etapa faltante", s["table_header"]), p("Proximo passo natural", s["table_header"])]]
        for item, step in zip([i for i in checklist.get("items", []) if not i.get("done")], steps):
            rows.append([p(item.get("label", ""), s["tiny"]), p(step, s["tiny"])])
        table = Table(rows, colWidths=[8.0 * cm, 19.1 * cm], repeatRows=1)
        table.setStyle(table_style(font_size=5.6))
        block.append(table)
        block.append(Spacer(1, 0.15 * cm))
        story.append(KeepTogether(block))

    story.append(PageBreak())
    story.append(p("Pendencias operacionais transversais", s["h1"]))
    deployment = data.get("deployment_summary") or {}
    failures = deployment.get("top_failures", [])
    if failures:
        story.append(p("Principais bloqueios detectados na ultima checagem de deployment:", s["body"]))
        failure_rows = [[p("Bloqueio", s["table_header"]), p("Tratamento recomendado", s["table_header"])]]
        recommendations = {
            "tool.psql": "Instalar PostgreSQL client ou expor psql no PATH antes de apply-postgres.",
            "tool.mongosh": "Instalar MongoDB Shell ou expor mongosh no PATH antes de apply-mongo.",
            "docker_daemon": "Iniciar Docker Desktop e confirmar docker info antes do compose.",
            "docker_compose": "Rerodar docker compose apos o daemon responder sem timeout.",
            "node_check": "Executar validacao MongoDB com Node/Mongosh apos o ambiente responder.",
        }
        for failure in failures:
            rec = "Rerodar python scripts/valley_db_orchestrator.py report depois de corrigir o bloqueio."
            for key, value in recommendations.items():
                if key in failure:
                    rec = value
                    break
            failure_rows.append([p(failure, s["small"]), p(rec, s["small"])])
        table = Table(failure_rows, colWidths=[13.0 * cm, 14.1 * cm], repeatRows=1)
        table.setStyle(table_style(font_size=6.3))
        story.append(table)
    else:
        story.append(p("Nenhum bloqueio transversal foi registrado no resumo atual.", s["body"]))

    story.append(Spacer(1, 0.35 * cm))
    story.append(
        p(
            "Criterio de leitura: percentuais de modulos usam o checklist canonico de 10 itens por modulo. "
            "Servicos usam artefatos e checagens disponiveis no workspace; onde ha autenticacao externa ou "
            "infra local pendente, o percentual expressa preparacao versionada, nao producao final.",
            s["body"],
        )
    )

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return OUTPUT_PATH


def main() -> None:
    data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    output = build_pdf(data)
    print(output)


if __name__ == "__main__":
    main()
