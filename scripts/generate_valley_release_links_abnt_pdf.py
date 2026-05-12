#!/usr/bin/env python3
"""Gera PDF ABNT com links clicaveis dos grupos Admin, Lojista e Usuario."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Iterable

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
SUBDOMAINS_PATH = ROOT / "output" / "deployment" / "valley-module-subdomains.json"
PDF_PATH = ROOT / "output" / "pdf" / "VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf"
MD_PATH = ROOT / "output" / "pdf" / "VALLEY_RELEASE_LINKS_MODULOS_ABNT.md"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def public_url(host: str) -> str:
    return f"https://{host.strip().strip('/')}/"


def link_paragraph(text: str, url: str, style: ParagraphStyle) -> Paragraph:
    safe_text = (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )
    safe_url = str(url).replace("&", "&amp;")
    return Paragraph(f'<link href="{safe_url}"><font color="#0645AD">{safe_text}</font></link>', style)


def group_records(records: list[dict]) -> dict[str, list[dict]]:
    admin_records = []
    lojista_records = []
    usuario_records = [
        {
            "title": "Portal público Valley",
            "name": "brasildesconto.com.br",
            "module_code": "USUARIO",
            "related": "Entrada oficial da marca e catálogo público",
        },
        {
            "title": "Produto web/mobile",
            "name": "brasildesconto.com.br/product",
            "module_code": "USUARIO",
            "related": "Catálogo, checkout, rastreio e conta do usuário",
        },
    ]

    seen_admin: set[str] = set()
    seen_lojista: set[str] = set()
    for record in records:
        host = str(record.get("name") or "")
        kind = str(record.get("kind") or "")
        if not host or "*" in host:
            continue
        normalized = host.lower()
        if kind == "merchant_erp_workspace" or normalized.endswith("-lojista.brasildesconto.com.br") or normalized == "lojista.brasildesconto.com.br":
            if normalized not in seen_lojista:
                lojista_records.append(record)
                seen_lojista.add(normalized)
            continue
        if (
            kind in {"admin_gateway", "static_workspace", "module_workspace", "static_workspace_cost_zero_alias", "module_workspace_cost_zero_alias"}
            or normalized.endswith("-admin.brasildesconto.com.br")
            or normalized == "admin.brasildesconto.com.br"
        ):
            if normalized not in seen_admin:
                admin_records.append(record)
                seen_admin.add(normalized)

    admin_records.sort(key=lambda item: (str(item.get("kind") or ""), str(item.get("name") or "")))
    lojista_records.sort(key=lambda item: str(item.get("name") or ""))
    return {"Admin": admin_records, "Lojista": lojista_records, "Usuário": usuario_records}


def relation_for(group: str, record: dict) -> str:
    host = str(record.get("name") or "")
    if group == "Admin":
        if "marketplace" in host:
            return "Controla integrações, canais, lojistas e publicações."
        if "stock" in host or "dropshipping" in host:
            return "Alimenta catálogo, fornecedores, estoque e precificação."
        if "finance" in host or "checkout" in host or "pay" in host:
            return "Conecta checkout, repasses, taxas e conciliação."
        if "merchant" in host or "lojista" in host:
            return "Abre gestão de lojistas e vínculos com ERP."
        return "Controla módulo, regras, governança e operação global."
    if group == "Lojista":
        if "inventario" in host:
            return "Conta estoque físico e ajusta altas, baixas, avarias e volumes."
        if "transportadora" in host or "logistica" in host:
            return "Movimenta pedidos, CD, docas, rotas e entrega final."
        if "pdv" in host:
            return "Registra venda presencial, caixa e conciliação."
        if "produtos" in host or "estoque" in host:
            return "Gerencia catálogo, saldo, SKU e publicação."
        return "Opera rotina empresarial do lojista no ERP."
    return str(record.get("related") or "Jornada pública do usuário final.")


def module_code(record: dict, fallback: str) -> str:
    code = str(record.get("module_code") or "").strip()
    if code:
        return code
    key = str(record.get("key") or "").replace("merchant-", "").replace("module-", "").upper()
    return key or fallback.upper()


def rows_for_group(group: str, records: Iterable[dict], small: ParagraphStyle) -> list[list[object]]:
    rows: list[list[object]] = [[
        Paragraph("<b>Módulo</b>", small),
        Paragraph("<b>Tela/Painel</b>", small),
        Paragraph("<b>Link clicável</b>", small),
        Paragraph("<b>Relação operacional</b>", small),
    ]]
    for record in records:
        host = str(record.get("name") or "")
        url = public_url(host)
        if "/product" in host:
            url = "https://brasildesconto.com.br/product/"
        rows.append([
            Paragraph(module_code(record, group), small),
            Paragraph(str(record.get("title") or host), small),
            link_paragraph(host, url, small),
            Paragraph(relation_for(group, record), small),
        ])
    return rows


def build_markdown(groups: dict[str, list[dict]]) -> None:
    lines = [
        "# Valley - Links Release por Módulo",
        "",
        "Documento fonte do PDF ABNT com links clicáveis separados em Admin, Lojista e Usuário.",
        "",
    ]
    for group, records in groups.items():
        lines.extend([f"## {group}", "", "| Módulo | Tela/Painel | Link | Relação |", "|---|---|---|---|"])
        for record in records:
            host = str(record.get("name") or "")
            url = public_url(host)
            if "/product" in host:
                url = "https://brasildesconto.com.br/product/"
            lines.append(
                f"| {module_code(record, group)} | {record.get('title') or host} | [{host}]({url}) | {relation_for(group, record)} |"
            )
        lines.append("")
    MD_PATH.parent.mkdir(parents=True, exist_ok=True)
    MD_PATH.write_text("\n".join(lines), encoding="utf-8")


def footer(canvas, doc) -> None:  # noqa: ANN001 - ReportLab callback
    canvas.saveState()
    canvas.setFont("Times-Roman", 9)
    canvas.drawRightString(A4[0] - 2 * cm, 1.2 * cm, f"Página {doc.page}")
    canvas.drawString(3 * cm, 1.2 * cm, "Valley - Release Blueprint")
    canvas.restoreState()


def main() -> None:
    manifest = load_json(SUBDOMAINS_PATH)
    groups = group_records(manifest.get("records") if isinstance(manifest.get("records"), list) else [])
    build_markdown(groups)

    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "ABNTTitle",
        parent=styles["Title"],
        fontName="Times-Bold",
        fontSize=14,
        leading=18,
        alignment=TA_CENTER,
        spaceAfter=18,
    )
    h1 = ParagraphStyle(
        "ABNTH1",
        parent=styles["Heading1"],
        fontName="Times-Bold",
        fontSize=12,
        leading=15,
        spaceBefore=12,
        spaceAfter=8,
    )
    body = ParagraphStyle(
        "ABNTBody",
        parent=styles["BodyText"],
        fontName="Times-Roman",
        fontSize=12,
        leading=18,
        alignment=TA_JUSTIFY,
        firstLineIndent=1.25 * cm,
    )
    small = ParagraphStyle(
        "ABNTSmall",
        parent=styles["BodyText"],
        fontName="Times-Roman",
        fontSize=8.4,
        leading=10.5,
    )

    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=A4,
        leftMargin=3 * cm,
        rightMargin=2 * cm,
        topMargin=3 * cm,
        bottomMargin=2 * cm,
        title="Valley - Links Release por Modulo",
        author="Valley",
        subject="PDF ABNT com links clicaveis por grupo",
    )

    story: list[object] = [
        Spacer(1, 5 * cm),
        Paragraph("VALLEY", title),
        Paragraph("DOCUMENTO RELEASE DE LINKS CLICÁVEIS POR MÓDULO", title),
        Spacer(1, 1.2 * cm),
        Paragraph("Admin, Lojista e Usuário", title),
        Spacer(1, 6 * cm),
        Paragraph(f"Brasil, {datetime.now().strftime('%d/%m/%Y')}", title),
        PageBreak(),
        Paragraph("1 INTRODUÇÃO", h1),
        Paragraph(
            "Este documento consolida os links públicos do ecossistema Valley em padrão ABNT, com separação por grupo operacional. Os links são clicáveis e relacionam cada módulo ao painel ou jornada correspondente.",
            body,
        ),
        Paragraph("2 ROTAS OFICIAIS", h1),
        Paragraph(
            "A base oficial de divulgação da marca é brasildesconto.com.br. Os acessos externos devem operar por Cloudflare, sem dependência de rede local ou Tailscale na versão release.",
            body,
        ),
    ]

    for index, (group, records) in enumerate(groups.items(), start=3):
        story.append(Paragraph(f"{index} GRUPO {group.upper()}", h1))
        table = Table(
            rows_for_group(group, records, small),
            colWidths=[2.2 * cm, 3.9 * cm, 4.7 * cm, 5.6 * cm],
            repeatRows=1,
        )
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF8")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#0B1020")),
                    ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#B7C1D1")),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 4),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ]
            )
        )
        story.extend([table, Spacer(1, 0.4 * cm)])

    story.extend(
        [
            Paragraph("6 CONCLUSÃO", h1),
            Paragraph(
                "Os links listados neste documento formam a malha release do Valley para operação comercial, gestão do lojista e jornada pública do usuário final.",
                body,
            ),
        ]
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(json.dumps({"pdf": str(PDF_PATH), "markdown": str(MD_PATH)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
