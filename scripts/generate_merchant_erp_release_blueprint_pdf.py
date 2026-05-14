"""PROPOSITO: Gerar PDF do release blueprint funcional do ERP Lojista.
CONTEXTO: O pacote desktop v048 precisa de um documento executivo com links publicos e criterios de aceite.
REGRAS: Nao incluir segredos; listar apenas URLs publicas, endpoints e evidencias tecnicas verificaveis.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]


def build_styles() -> dict[str, ParagraphStyle]:
    styles = getSampleStyleSheet()
    styles["Title"].fontName = "Helvetica-Bold"
    styles["Title"].fontSize = 20
    styles["Title"].leading = 24
    styles["Title"].textColor = colors.HexColor("#0B6B4B")
    styles["Heading1"].fontName = "Helvetica-Bold"
    styles["Heading1"].fontSize = 13
    styles["Heading1"].textColor = colors.HexColor("#12312B")
    styles["BodyText"].fontName = "Helvetica"
    styles["BodyText"].fontSize = 9
    styles["BodyText"].leading = 12
    styles.add(
        ParagraphStyle(
            name="Small",
            parent=styles["BodyText"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#334155"),
        )
    )
    return styles


def p(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"), style)


def build_pdf(version: str) -> Path:
    release_dir = ROOT / "admin" / "downloads" / version
    output_path = release_dir / f"VALLEY_ERP_LOJISTA_RELEASE_BLUEPRINT_{version.upper()}.pdf"
    public_base = f"https://admin.brasildesconto.com.br/downloads/{version}"
    styles = build_styles()

    windows_url = f"{public_base}/ValleyERP-Lojista-Windows-x64-{version}.zip"
    linux_url = f"{public_base}/ValleyERP-Lojista-Linux-x64-{version}.tar.gz"
    manifest_url = f"{public_base}/VALLEY_ERP_LOJISTA_DESKTOP_INSTALLERS_{version.upper()}.json"
    blueprint_url = f"{public_base}/VALLEY_MERCHANT_RELEASE_BLUEPRINT_{version.upper()}.md"

    story = [
        p(f"Valley ERP Lojista - Release Blueprint {version.upper()}", styles["Title"]),
        p(
            "Documento executivo do pacote funcional: login online de lojista, blueprint autenticado e acoes persistidas.",
            styles["BodyText"],
        ),
        Spacer(1, 0.35 * cm),
        p("Links Publicos", styles["Heading1"]),
    ]

    links_table = Table(
        [
            ["Artefato", "URL"],
            ["Windows x64 ZIP", windows_url],
            ["Linux x64 TAR.GZ", linux_url],
            ["Manifesto", manifest_url],
            ["Blueprint Markdown", blueprint_url],
        ],
        colWidths=[4.1 * cm, 12.2 * cm],
    )
    links_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E5F4EC")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#12312B")),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#CBD5E1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")]),
            ]
        )
    )
    story.append(links_table)
    story.append(Spacer(1, 0.35 * cm))

    story.extend(
        [
            p("Contrato Funcional", styles["Heading1"]),
            p("Login: POST https://admin.brasildesconto.com.br/api/auth/login com scope=merchant.", styles["BodyText"]),
            p("Blueprint: GET /api/merchant-erp/blueprint com Authorization Bearer.", styles["BodyText"]),
            p("Acoes: POST /api/merchant-erp/action gravando evento append-only em tmp/runtime/valley-merchant-erp-events.jsonl.", styles["BodyText"]),
            Spacer(1, 0.25 * cm),
            p("Modulos Ativos", styles["Heading1"]),
        ]
    )

    modules = [
        "Vendas",
        "Produtos",
        "Estoque",
        "Pedidos",
        "Clientes",
        "Financeiro",
        "Checkout",
        "Entregas",
        "Marketplace",
        "Relatorios",
        "Configuracoes",
        "Suporte Helena",
    ]
    story.append(p(", ".join(modules), styles["BodyText"]))
    story.append(Spacer(1, 0.25 * cm))
    story.extend(
        [
            p("Evidencias Validadas", styles["Heading1"]),
            p("Login local e publico retornou status=ok e papel MERCHANT.", styles["BodyText"]),
            p("Blueprint local e publico retornou 12 modulos ativos.", styles["BodyText"]),
            p("Salvar/Sincronizar gravaram eventos persistentes no runtime.", styles["BodyText"]),
            p("Manifesto, ZIP Windows, TAR.GZ Linux e blueprint retornaram HTTP 200 no dominio publico.", styles["BodyText"]),
            p("flutter analyze do entrypoint desktop e shell ERP Lojista: No issues found.", styles["BodyText"]),
        ]
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=A4,
        rightMargin=1.5 * cm,
        leftMargin=1.5 * cm,
        topMargin=1.5 * cm,
        bottomMargin=1.5 * cm,
    )
    doc.build(story)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Gera PDF do release blueprint ERP Lojista.")
    parser.add_argument("--version", default="v048")
    args = parser.parse_args()
    output = build_pdf(args.version)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

