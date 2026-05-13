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
ADMIN_RUNTIME_PATH = ROOT / "tmp" / "runtime" / "valley-admin-public-runtime.json"
PRODUCT_RUNTIME_PATH = ROOT / "tmp" / "runtime" / "valley-product-public-runtime.json"
LOCALHOST_RUN_STATUS_PATH = ROOT / "tmp" / "runtime" / "valley-localhost-run-status.json"
STITCH_PUBLICATION_PATH = ROOT / "tmp" / "runtime" / "valley-stitch-template-publication.json"
DOWNLOADS_ROOT = ROOT / "admin" / "downloads"
PDF_PATH = ROOT / "output" / "pdf" / "VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf"
MD_PATH = ROOT / "output" / "pdf" / "VALLEY_RELEASE_LINKS_MODULOS_ABNT.md"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_optional_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        payload = load_json(path)
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def latest_apk_release_manifest() -> dict:
    manifests = sorted(
        DOWNLOADS_ROOT.glob("v*/VALLEY_APK_RELEASE_ABI_*.json"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    for manifest_path in manifests:
        payload = load_optional_json(manifest_path)
        if payload:
            payload["_manifest_path"] = str(manifest_path.relative_to(ROOT))
            return payload
    return {}


def public_url(host: str) -> str:
    if host.startswith("http://") or host.startswith("https://"):
        path_part = host.split("?", 1)[0].rstrip("/")
        has_file_extension = "." in path_part.rsplit("/", 1)[-1]
        if host.endswith("/") or has_file_extension:
            return host
        return f"{host}/"
    return f"https://{host.strip().strip('/')}/"


def host_path_from_url(url: str) -> str:
    raw = str(url or "").strip()
    if raw.startswith("https://"):
        return raw.removeprefix("https://").rstrip("/")
    if raw.startswith("http://"):
        return raw.removeprefix("http://").rstrip("/")
    return raw.strip("/")


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
    admin_runtime = load_optional_json(ADMIN_RUNTIME_PATH)
    product_runtime = load_optional_json(PRODUCT_RUNTIME_PATH)
    localhost_runtime = load_optional_json(LOCALHOST_RUN_STATUS_PATH)
    stitch_publication = load_optional_json(STITCH_PUBLICATION_PATH)
    apk_release = latest_apk_release_manifest()
    admin_public_url = str(
        admin_runtime.get("public_url") or localhost_runtime.get("public_url") or ""
    ).strip()
    product_public_url = str(
        product_runtime.get("public_url") or localhost_runtime.get("product_url") or ""
    ).strip()
    product_api_url = str(
        product_runtime.get("public_api_url") or localhost_runtime.get("api_url") or ""
    ).strip()

    admin_records = []
    lojista_records = []
    usuario_records = [
        {
            "title": "Runtime operacional atual",
            "name": admin_public_url,
            "module_code": "ADMIN",
            "related": "Painel web ativo validado para testes externos enquanto o dominio fixo aguarda reparo do tunnel.",
        },
        {
            "title": "Portal público Valley",
            "name": "brasildesconto.com.br",
            "module_code": "USUARIO",
            "related": "Entrada oficial da marca e catálogo público",
        },
        {
            "title": "Produto web/mobile operacional atual",
            "name": product_public_url,
            "module_code": "USUARIO",
            "related": "Catálogo, checkout, rastreio e conta do usuário na rota pública validada.",
        },
        {
            "title": "API pública operacional atual",
            "name": product_api_url,
            "module_code": "API",
            "related": "Endpoint público validado para shell de produto e ações do aplicativo.",
        },
        {
            "title": "Produto web/mobile",
            "name": "brasildesconto.com.br/product",
            "module_code": "USUARIO",
            "related": "Catálogo, checkout, rastreio e conta do usuário",
        },
    ]

    if admin_public_url:
        admin_records.append(
            {
                "title": "Painel admin operacional atual",
                "name": admin_public_url,
                "module_code": "ADMIN",
                "related": "Admin e workspaces web atualizados com a rota pública validada.",
                "kind": "runtime_current",
            }
        )

    seen_admin: set[str] = set()
    seen_lojista: set[str] = set()
    for record in records:
        host = str(record.get("name") or "")
        kind = str(record.get("kind") or "")
        is_cost_zero = bool(record.get("cost_zero_ssl_compatible"))
        if not host or "*" in host:
            continue
        normalized = host.lower()
        if normalized.endswith(".admin.brasildesconto.com.br") and not is_cost_zero:
            continue
        if kind == "merchant_erp_workspace" or normalized.endswith("-lojista.brasildesconto.com.br") or normalized == "lojista.brasildesconto.com.br":
            if normalized not in seen_lojista:
                lojista_records.append(record)
                seen_lojista.add(normalized)
            continue
        if (
            kind in {"admin_gateway", "static_workspace_cost_zero_alias", "module_workspace_cost_zero_alias"}
            or normalized.endswith("-admin.brasildesconto.com.br")
            or normalized == "admin.brasildesconto.com.br"
        ):
            if normalized not in seen_admin:
                admin_records.append(record)
                seen_admin.add(normalized)

    usuario_records = [record for record in usuario_records if str(record.get("name") or "").strip()]
    admin_records.sort(key=lambda item: (str(item.get("kind") or ""), str(item.get("name") or "")))
    lojista_records.sort(key=lambda item: str(item.get("name") or ""))

    stitch_records = []
    if stitch_publication.get("public_index_url"):
        stitch_records.append(
            {
                "title": "Galeria release Stitch ERP",
                "name": host_path_from_url(str(stitch_publication.get("public_index_url") or "")),
                "module_code": "STITCH",
                "related": "Indice publico com todos os templates Stitch publicados para handoff e validacao.",
                "kind": "stitch_gallery",
            }
        )
    screens = stitch_publication.get("screens")
    if isinstance(screens, list):
        for screen in screens:
            if not isinstance(screen, dict):
                continue
            html_url = str(screen.get("public_html_url") or "").strip()
            if not html_url:
                continue
            stitch_records.append(
                {
                    "title": str(screen.get("title") or screen.get("key") or "Template Stitch"),
                    "name": host_path_from_url(html_url),
                    "module_code": "STITCH",
                    "related": (
                        f"{screen.get('priority') or 'P3'} / "
                        f"{screen.get('surface') or 'shared_design'} / "
                        f"{screen.get('form_factor') or 'desktop'}"
                    ),
                    "kind": "stitch_template",
                }
            )

    download_records = []
    artifacts = apk_release.get("artifacts")
    if isinstance(artifacts, list):
        recommended = str(apk_release.get("recommended_android") or "")
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                continue
            url = str(artifact.get("public_url") or "").strip()
            if not url:
                continue
            name = str(artifact.get("name") or artifact.get("file") or "APK")
            download_records.append(
                {
                    "title": (
                        "APK Android recomendado"
                        if name == recommended
                        else f"APK Android {name.replace('app-', '').replace('-release.apk', '')}"
                    ),
                    "name": url,
                    "module_code": "APK",
                    "related": (
                        f"{apk_release.get('version') or 'release'} / "
                        f"{apk_release.get('app_version') or 'sem versao'} / "
                        f"{artifact.get('bytes') or 0} bytes / SHA1 {artifact.get('sha1') or ''}"
                    ),
                    "kind": "release_download",
                }
            )
    manifest_path = str(apk_release.get("_manifest_path") or "")
    if manifest_path:
        public_manifest_path = manifest_path.replace("\\", "/")
        if public_manifest_path.startswith("admin/"):
            public_manifest_path = public_manifest_path.removeprefix("admin/")
        download_records.append(
            {
                "title": "Manifest release APK",
                "name": f"https://admin.brasildesconto.com.br/{public_manifest_path}",
                "module_code": "APK",
                "related": "Manifest ABI com hashes, URL publica e build embarcado.",
                "kind": "release_manifest",
            }
        )

    return {
        "Admin": admin_records,
        "Lojista": lojista_records,
        "Usuário": usuario_records,
        "Templates Stitch": stitch_records,
        "Downloads Release": download_records,
    }


def relation_for(group: str, record: dict) -> str:
    host = str(record.get("name") or "")
    if group == "Templates Stitch":
        return str(record.get("related") or "Template Stitch publicado como referencia de handoff.")
    if group == "Downloads Release":
        return str(record.get("related") or "Artefato publico de release.")
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


def display_title(record: dict, host: str) -> str:
    title = str(record.get("title") or host)
    return title.replace(" HTTPS alias", "")


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
        if host == "brasildesconto.com.br/product":
            url = "https://brasildesconto.com.br/product/"
        rows.append([
            Paragraph(module_code(record, group), small),
            Paragraph(display_title(record, host), small),
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
            if host == "brasildesconto.com.br/product":
                url = "https://brasildesconto.com.br/product/"
            lines.append(
                f"| {module_code(record, group)} | {display_title(record, host)} | [{host}]({url}) | {relation_for(group, record)} |"
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
        Paragraph("Admin, Lojista, Usuário e Templates Stitch", title),
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

    conclusion_index = 3 + len(groups)
    story.extend(
        [
            Paragraph(f"{conclusion_index} CONCLUSÃO", h1),
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
