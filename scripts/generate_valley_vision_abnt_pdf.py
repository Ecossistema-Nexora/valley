#!/usr/bin/env python3
"""Gera um PDF em formato ABNT a partir de docs/specs/valley_vision.md."""

from __future__ import annotations

import datetime as dt
import re
from dataclasses import dataclass
from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
SOURCE_MD = ROOT / "docs" / "specs" / "valley_vision.md"
OUTPUT_PDF = ROOT / "output" / "pdf" / "VALLEY_VISION_ABNT.pdf"

LEFT_MARGIN = 3 * cm
RIGHT_MARGIN = 2 * cm
TOP_MARGIN = 3 * cm
BOTTOM_MARGIN = 2 * cm
TEXT_WIDTH = A4[0] - LEFT_MARGIN - RIGHT_MARGIN


@dataclass
class Styles:
    cover_org: ParagraphStyle
    cover_title: ParagraphStyle
    cover_subtitle: ParagraphStyle
    cover_meta: ParagraphStyle
    title: ParagraphStyle
    heading1: ParagraphStyle
    heading2: ParagraphStyle
    body: ParagraphStyle
    bullet: ParagraphStyle
    numbered: ParagraphStyle
    table_cell: ParagraphStyle


def build_styles() -> Styles:
    base = getSampleStyleSheet()

    cover_org = ParagraphStyle(
        "CoverOrg",
        parent=base["Normal"],
        fontName="Times-Bold",
        fontSize=12,
        leading=18,
        alignment=TA_CENTER,
        spaceAfter=0.25 * cm,
    )
    cover_title = ParagraphStyle(
        "CoverTitle",
        parent=base["Title"],
        fontName="Times-Bold",
        fontSize=16,
        leading=22,
        alignment=TA_CENTER,
        spaceAfter=0.5 * cm,
    )
    cover_subtitle = ParagraphStyle(
        "CoverSubtitle",
        parent=base["Normal"],
        fontName="Times-Roman",
        fontSize=12,
        leading=18,
        alignment=TA_CENTER,
    )
    cover_meta = ParagraphStyle(
        "CoverMeta",
        parent=base["Normal"],
        fontName="Times-Roman",
        fontSize=12,
        leading=18,
        alignment=TA_CENTER,
    )
    title = ParagraphStyle(
        "AbntTitle",
        parent=base["Title"],
        fontName="Times-Bold",
        fontSize=14,
        leading=18,
        alignment=TA_CENTER,
        spaceAfter=0.4 * cm,
        spaceBefore=0,
    )
    heading1 = ParagraphStyle(
        "Heading1Abnt",
        parent=base["Heading1"],
        fontName="Times-Bold",
        fontSize=12,
        leading=18,
        alignment=TA_JUSTIFY,
        spaceBefore=0.6 * cm,
        spaceAfter=0.2 * cm,
        keepWithNext=True,
    )
    heading2 = ParagraphStyle(
        "Heading2Abnt",
        parent=base["Heading2"],
        fontName="Times-Bold",
        fontSize=12,
        leading=18,
        alignment=TA_JUSTIFY,
        spaceBefore=0.35 * cm,
        spaceAfter=0.15 * cm,
        keepWithNext=True,
    )
    body = ParagraphStyle(
        "BodyAbnt",
        parent=base["BodyText"],
        fontName="Times-Roman",
        fontSize=12,
        leading=18,
        alignment=TA_JUSTIFY,
        firstLineIndent=1.25 * cm,
        spaceAfter=0,
        spaceBefore=0,
    )
    bullet = ParagraphStyle(
        "BulletAbnt",
        parent=body,
        firstLineIndent=0,
        leftIndent=1.25 * cm,
        bulletIndent=0.6 * cm,
    )
    numbered = ParagraphStyle(
        "NumberedAbnt",
        parent=body,
        firstLineIndent=0,
        leftIndent=1.25 * cm,
        bulletIndent=0.6 * cm,
    )
    table_cell = ParagraphStyle(
        "TableCellAbnt",
        parent=base["BodyText"],
        fontName="Times-Roman",
        fontSize=10,
        leading=14,
        alignment=TA_JUSTIFY,
        spaceAfter=0,
        spaceBefore=0,
    )
    return Styles(
        cover_org=cover_org,
        cover_title=cover_title,
        cover_subtitle=cover_subtitle,
        cover_meta=cover_meta,
        title=title,
        heading1=heading1,
        heading2=heading2,
        body=body,
        bullet=bullet,
        numbered=numbered,
        table_cell=table_cell,
    )


def transform_inline(text: str) -> str:
    parts = re.split(r"(`[^`]+`)", text)
    rendered: list[str] = []
    for part in parts:
        if not part:
            continue
        if part.startswith("`") and part.endswith("`"):
            rendered.append(f'<font name="Courier">{escape(part[1:-1])}</font>')
            continue
        rendered.append(escape(part))
    return "".join(rendered)


def is_special_line(line: str) -> bool:
    stripped = line.strip()
    return (
        not stripped
        or stripped.startswith("#")
        or stripped.startswith("|")
        or stripped.startswith("```")
        or re.match(r"^[-*]\s+", stripped) is not None
        or re.match(r"^\d+\.\s+", stripped) is not None
    )


def parse_paragraph(lines: list[str], start: int) -> tuple[str, int]:
    buffer: list[str] = []
    index = start
    while index < len(lines):
        line = lines[index]
        if is_special_line(line):
            break
        buffer.append(line.strip())
        index += 1
    return " ".join(part for part in buffer if part), index


def parse_list_item(lines: list[str], start: int, prefix_pattern: str) -> tuple[str, int]:
    first = re.sub(prefix_pattern, "", lines[start].strip(), count=1).strip()
    buffer = [first]
    index = start + 1
    while index < len(lines):
        stripped = lines[index].strip()
        raw = lines[index]
        if not stripped:
            break
        if is_special_line(raw) and not raw.startswith(" "):
            break
        buffer.append(stripped)
        index += 1
    return " ".join(part for part in buffer if part), index


def parse_table(lines: list[str], start: int) -> tuple[list[list[str]], int]:
    rows: list[list[str]] = []
    index = start
    while index < len(lines):
        raw = lines[index].strip()
        if not raw.startswith("|"):
            break
        cells = [cell.strip() for cell in raw.strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell.replace(" ", "")) for cell in cells):
            index += 1
            continue
        rows.append(cells)
        index += 1
    return rows, index


def column_widths(rows: list[list[str]]) -> list[float]:
    column_count = max(len(row) for row in rows)
    weights = [1.0] * column_count
    for column_index in range(column_count):
        max_len = max(len(row[column_index]) if column_index < len(row) else 0 for row in rows)
        weights[column_index] = max(1.0, min(4.0, max_len / 18.0))
    total = sum(weights)
    widths = [(TEXT_WIDTH * weight) / total for weight in weights]
    minimum = 2.2 * cm
    shortfall = sum(max(0.0, minimum - width) for width in widths)
    widths = [max(minimum, width) for width in widths]
    if shortfall > 0:
        adjustable_indexes = [i for i, width in enumerate(widths) if width > minimum]
        if adjustable_indexes:
            reduction = shortfall / len(adjustable_indexes)
            for index in adjustable_indexes:
                widths[index] = max(minimum, widths[index] - reduction)
    return widths


def build_table(rows: list[list[str]], styles: Styles) -> Table:
    normalized = [row + [""] * (max(len(r) for r in rows) - len(row)) for row in rows]
    rendered = [
        [Paragraph(transform_inline(cell), styles.table_cell) for cell in row]
        for row in normalized
    ]
    table = Table(rendered, colWidths=column_widths(normalized), repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8ECEA")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.black),
                ("FONTNAME", (0, 0), (-1, 0), "Times-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return table


def add_cover(story: list, styles: Styles) -> None:
    year = str(dt.datetime.now().year)
    story.append(Spacer(1, 3.2 * cm))
    story.append(Paragraph("NEXORA", styles.cover_org))
    story.append(Paragraph("Ecossistema Valley", styles.cover_org))
    story.append(Spacer(1, 6.0 * cm))
    story.append(Paragraph("VALLEY VISION", styles.cover_title))
    story.append(Paragraph("Documento tecnico institucional em formatacao ABNT", styles.cover_subtitle))
    story.append(Spacer(1, 9.0 * cm))
    story.append(Paragraph("Sao Paulo", styles.cover_meta))
    story.append(Paragraph(year, styles.cover_meta))
    story.append(PageBreak())


def add_front_matter(story: list, styles: Styles) -> None:
    story.append(Paragraph("Valley Vision", styles.title))
    story.append(
        Paragraph(
            "Versao em PDF derivada de docs/specs/valley_vision.md com margens, tipografia e espacemento alinhados ao padrao academico ABNT.",
            styles.body,
        )
    )
    story.append(Spacer(1, 0.6 * cm))


def build_story(markdown_text: str, styles: Styles) -> list:
    lines = markdown_text.splitlines()
    story: list = []
    add_cover(story, styles)
    add_front_matter(story, styles)

    index = 0
    in_code_block = False
    code_lines: list[str] = []

    while index < len(lines):
        raw_line = lines[index]
        stripped = raw_line.strip()

        if stripped.startswith("```"):
            if in_code_block and code_lines:
                code_text = " ".join(line.strip() for line in code_lines if line.strip())
                story.append(Paragraph(transform_inline(code_text), styles.body))
                story.append(Spacer(1, 0.15 * cm))
                code_lines = []
            in_code_block = not in_code_block
            index += 1
            continue

        if in_code_block:
            code_lines.append(raw_line)
            index += 1
            continue

        if not stripped:
            story.append(Spacer(1, 0.25 * cm))
            index += 1
            continue

        if stripped.startswith("# "):
            index += 1
            continue

        if stripped.startswith("## "):
            story.append(Paragraph(transform_inline(stripped[3:]), styles.heading1))
            index += 1
            continue

        if stripped.startswith("### "):
            story.append(Paragraph(transform_inline(stripped[4:]), styles.heading2))
            index += 1
            continue

        if stripped.startswith("|"):
            rows, index = parse_table(lines, index)
            if rows:
                story.append(build_table(rows, styles))
                story.append(Spacer(1, 0.25 * cm))
            continue

        bullet_match = re.match(r"^[-*]\s+", stripped)
        if bullet_match:
            item_text, index = parse_list_item(lines, index, r"^[-*]\s+")
            story.append(Paragraph(transform_inline(item_text), styles.bullet, bulletText="-"))
            continue

        number_match = re.match(r"^(\d+)\.\s+", stripped)
        if number_match:
            marker = f"{number_match.group(1)}."
            item_text, index = parse_list_item(lines, index, r"^\d+\.\s+")
            story.append(Paragraph(transform_inline(item_text), styles.numbered, bulletText=marker))
            continue

        paragraph, index = parse_paragraph(lines, index)
        if paragraph:
            story.append(Paragraph(transform_inline(paragraph), styles.body))

    return story


def draw_later_page(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFont("Times-Roman", 10)
    canvas.drawRightString(A4[0] - RIGHT_MARGIN, A4[1] - 2 * cm, str(canvas.getPageNumber()))
    canvas.restoreState()


def main() -> None:
    if not SOURCE_MD.exists():
        raise FileNotFoundError(f"Arquivo fonte nao encontrado: {SOURCE_MD}")

    OUTPUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    styles = build_styles()
    markdown_text = SOURCE_MD.read_text(encoding="utf-8")
    story = build_story(markdown_text, styles)

    document = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        title="Valley Vision",
        author="Nexora",
        subject="Documento tecnico institucional",
    )
    document.build(story, onFirstPage=lambda canvas, doc: None, onLaterPages=draw_later_page)
    print(OUTPUT_PDF)


if __name__ == "__main__":
    main()
