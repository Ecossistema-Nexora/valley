#!/usr/bin/env python3
"""PROPOSITO: Importar o export Stitch Valley ERP para assets versionaveis e inventario.

CONTEXTO: O ZIP do Stitch contem telas HTML/PNG e DESIGN.md. O repositorio
deve preservar o export bruto em docs/design/stitch_exports e manter uma copia
temporaria em tmp/stitch-import para analises locais.

REGRAS: Nao sobrescreve UI existente, nao grava segredos, nao executa deploy e
nao promove HTML bruto para runtime sem uma conversao controlada.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import zipfile
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ZIP = Path.home() / "Downloads" / "stitch_valley_erp (1).zip"
STAGING_ROOT = ROOT / "tmp" / "stitch-import"
DOCS_DIR = ROOT / "docs" / "design"
VERSIONED_EXPORT_ROOT = DOCS_DIR / "stitch_exports" / "20260513_valley_erp"
INVENTORY_JSON = DOCS_DIR / "stitch_valley_erp_inventory.json"
INVENTORY_MD = DOCS_DIR / "STITCH_VALLEY_ERP_INVENTORY.md"
TOKENS_JSON = DOCS_DIR / "stitch_valley_design_tokens.json"
INTEGRATION_MAP_MD = DOCS_DIR / "STITCH_VALLEY_ERP_INTEGRATION_MAP.md"


@dataclass(frozen=True)
class StitchScreen:
    key: str
    title: str
    surface: str
    locale: str
    form_factor: str
    html_path: str
    screen_path: str
    html_bytes: int
    screen_bytes: int
    priority: str
    integration_target: str


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_title(key: str) -> str:
    words = key.replace("valley_", "").replace("_pt_br", "").split("_")
    replacements = {
        "blico": "publico",
        "gest": "gestao",
        "log": "logistica",
        "rios": "relatorios",
        "avan": "avancados",
        "es": "coes",
        "integra": "integracoes",
        "cat": "catalogo",
        "usu": "usuario",
    }
    cleaned = [replacements.get(word, word) for word in words if word]
    return " ".join(word.capitalize() for word in cleaned)


def classify_surface(key: str) -> str:
    if "portal" in key or "home_p" in key or "produto" in key or "checkout" in key or "minhas_compras" in key:
        return "usuario_publico"
    if "mobile" in key or "login" in key or "home_do_usu" in key:
        return "flutter_mobile"
    if "admin" in key:
        return "admin_web"
    if "erp" in key or "lojista" in key or "pdv" in key:
        return "erp_lojista"
    return "shared_design"


def form_factor(key: str) -> str:
    return "mobile" if "mobile" in key else "desktop"


def locale(key: str) -> str:
    return "pt-BR" if "pt_br" in key else "generic"


def priority(key: str, surface: str) -> str:
    p0_terms = (
        "login",
        "portal_p_blico_pt_br",
        "admin_central",
        "erp_do_lojista",
        "painel_de_controle",
        "gest_o_de_pedidos_pt_br",
        "gest_o_de_estoque",
        "cadastro_de_sku",
        "checkout",
        "minhas_compras",
    )
    p1_terms = (
        "financeiro",
        "log_stica",
        "marketplace",
        "relat_rios",
        "configura",
        "suporte",
        "auditoria",
        "fiscal",
    )
    if any(term in key for term in p0_terms):
        return "P0"
    if any(term in key for term in p1_terms):
        return "P1"
    if surface in {"usuario_publico", "admin_web", "erp_lojista"}:
        return "P2"
    return "P3"


def integration_target(surface: str, key: str) -> str:
    if surface == "admin_web":
        return "admin/app.js + admin/styles.css"
    if surface == "erp_lojista":
        return "admin/app.js merchant ERP tabs"
    if surface in {"flutter_mobile", "usuario_publico"}:
        return "frontend/flutter/lib/src/ui"
    if "DESIGN" in key:
        return "Valley design tokens"
    return "docs/design handoff"


def safe_extract(zip_path: Path, staging_dir: Path) -> None:
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.infolist():
            target = staging_dir / member.filename
            resolved = target.resolve()
            if not str(resolved).startswith(str(staging_dir.resolve())):
                raise RuntimeError(f"Entrada insegura no ZIP: {member.filename}")
        archive.extractall(staging_dir)


def source_fingerprint(zip_path: Path) -> dict[str, object]:
    stat = zip_path.stat()
    return {
        "path": str(zip_path),
        "bytes": stat.st_size,
        "modified_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
    }


def parse_design_tokens(design_md: Path) -> dict[str, object]:
    if not design_md.exists():
        return {}
    text = design_md.read_text(encoding="utf-8-sig")
    parts = text.split("---", 2)
    frontmatter = parts[1] if len(parts) >= 3 else ""
    tokens: dict[str, object] = {
        "source": design_md.relative_to(ROOT).as_posix(),
        "generated_at_utc": utc_now(),
        "raw_frontmatter_lines": len(frontmatter.splitlines()),
        "colors": {},
        "typography_tokens": [],
    }

    current_section = ""
    for raw_line in frontmatter.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            continue
        if not raw_line.startswith(" ") and line.endswith(":"):
            current_section = line[:-1]
            continue
        if current_section == "colors" and ":" in line:
            key, value = line.strip().split(":", 1)
            tokens["colors"][key] = value.strip().strip("'").strip('"')
        elif current_section == "typography" and raw_line.startswith("  ") and line.strip().endswith(":"):
            tokens["typography_tokens"].append(line.strip().strip(":"))
    return tokens


def build_inventory(export_dir: Path, zip_path: Path, staging_dir: Path) -> tuple[list[StitchScreen], dict[str, object]]:
    root = export_dir / "stitch_valley_erp"
    screens: list[StitchScreen] = []

    for html in sorted(root.glob("*/code.html")):
        screen_dir = html.parent
        key = screen_dir.name
        png = screen_dir / "screen.png"
        surface = classify_surface(key)
        item = StitchScreen(
            key=key,
            title=normalize_title(key),
            surface=surface,
            locale=locale(key),
            form_factor=form_factor(key),
            html_path=html.relative_to(ROOT).as_posix(),
            screen_path=png.relative_to(ROOT).as_posix() if png.exists() else "",
            html_bytes=html.stat().st_size,
            screen_bytes=png.stat().st_size if png.exists() else 0,
            priority=priority(key, surface),
            integration_target=integration_target(surface, key),
        )
        screens.append(item)

    by_surface = Counter(screen.surface for screen in screens)
    by_priority = Counter(screen.priority for screen in screens)
    by_form_factor = Counter(screen.form_factor for screen in screens)
    by_locale = Counter(screen.locale for screen in screens)
    summary = {
        "generated_at_utc": utc_now(),
        "source_zip": str(zip_path),
        "source_zip_fingerprint": source_fingerprint(zip_path),
        "versioned_export_dir": export_dir.relative_to(ROOT).as_posix(),
        "staging_dir": staging_dir.relative_to(ROOT).as_posix(),
        "screen_count": len(screens),
        "by_surface": dict(sorted(by_surface.items())),
        "by_priority": dict(sorted(by_priority.items())),
        "by_form_factor": dict(sorted(by_form_factor.items())),
        "by_locale": dict(sorted(by_locale.items())),
    }
    return screens, summary


def write_inventory(screens: list[StitchScreen], summary: dict[str, object], design_tokens: dict[str, object]) -> None:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    source_zip_name = Path(str(summary["source_zip"])).name
    export_dir = str(summary["versioned_export_dir"])
    INVENTORY_JSON.write_text(
        json.dumps(
            {
                "summary": summary,
                "design_tokens": design_tokens,
                "screens": [asdict(screen) for screen in screens],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    lines = [
        "# Stitch Valley ERP Inventory",
        "",
        "<!--",
        "PROPOSITO: Inventariar o export Stitch Valley ERP.",
        "CONTEXTO: Artefato gerado por scripts/import_stitch_valley_erp_export.py.",
        "REGRAS: Nao editar manualmente listas extensas; reexecutar o importador.",
        "-->",
        "",
        f"- Gerado em UTC: `{summary['generated_at_utc']}`",
        f"- Assets brutos versionados: `{summary['versioned_export_dir']}`",
        f"- Staging temporario: `{summary['staging_dir']}`",
        f"- Telas HTML: `{summary['screen_count']}`",
        f"- Por superficie: `{json.dumps(summary['by_surface'], ensure_ascii=False)}`",
        f"- Por prioridade: `{json.dumps(summary['by_priority'], ensure_ascii=False)}`",
        f"- Por formato: `{json.dumps(summary['by_form_factor'], ensure_ascii=False)}`",
        "",
        "## P0",
        "",
        "| Tela | Superficie | Formato | Locale | Alvo |",
        "| --- | --- | --- | --- | --- |",
    ]
    for screen in screens:
        if screen.priority != "P0":
            continue
        lines.append(
            f"| `{screen.key}` | {screen.surface} | {screen.form_factor} | {screen.locale} | {screen.integration_target} |"
        )
    lines.extend([
        "",
        "## Todas As Telas",
        "",
        "| Prioridade | Tela | Superficie | Formato | Locale | HTML | PNG |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ])
    for screen in screens:
        lines.append(
            f"| {screen.priority} | `{screen.key}` | {screen.surface} | {screen.form_factor} | "
            f"{screen.locale} | `{screen.html_path}` | `{screen.screen_path}` |"
        )
    INVENTORY_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")

    TOKENS_JSON.write_text(json.dumps(design_tokens, ensure_ascii=False, indent=2), encoding="utf-8")

    p0 = [screen for screen in screens if screen.priority == "P0"]
    integration_lines = [
        "# Stitch Valley ERP Integration Map",
        "",
        "<!--",
        "PROPOSITO: Mapear a conversao das telas Stitch para Valley.",
        "CONTEXTO: Este mapa orienta Figma handoff, Flutter e admin web a partir da fonte Stitch ativa.",
        "REGRAS: Implementar por ondas, validar em browser/Flutter e manter tokens Valley/Helena/V-Coin.",
        "-->",
        "",
        "## Decisao",
        "",
        f"- Fonte primaria de design: export Stitch `{source_zip_name}`.",
        f"- Assets brutos versionados: `{export_dir}/`.",
        "- Staging local ignorado: `tmp/stitch-import/`.",
        "- Handoff de design: promover P0 para Figma antes de codificar grandes superficies.",
        "- Implementacao: converter componentes e fluxos, mantendo HTML bruto como galeria de referencia e fonte ativa de inspecao.",
        "",
        "## Onda 1 - P0",
        "",
        "| Tela Stitch | Superficie Valley | Alvo tecnico | Criterio de aceite |",
        "| --- | --- | --- | --- |",
    ]
    for screen in p0:
        integration_lines.append(
            f"| `{screen.key}` | {screen.surface} | {screen.integration_target} | "
            "Sem botao morto, responsivo e validado em browser/mobile |"
        )
    integration_lines.extend([
        "",
        "## Onda 2 - P1",
        "",
        "- Financeiro, logistica, marketplace, relatorios, configuracoes, suporte e auditoria.",
        "- Depois da Onda 1, aplicar os mesmos componentes base para evitar duplicacao visual.",
        "",
        "## Guardrails",
        "",
        "- Nao introduzir referencias proibidas de produto; usar Valley, Helena e V-Coin.",
        "- Manter assets brutos versionados e publicados como referencia de handoff e fonte ativa de inspecao.",
        "- Nao quebrar o APK v038 nem o gate Cloudflare validado.",
        "- Rodar Playwright/browser para admin web e build Flutter quando tocar UI executavel.",
    ])
    INTEGRATION_MAP_MD.write_text("\n".join(integration_lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Importa export Stitch Valley ERP para staging e inventario.")
    parser.add_argument("--zip", default=str(DEFAULT_ZIP), help="Caminho do ZIP exportado pelo Stitch.")
    parser.add_argument("--staging", default=str(STAGING_ROOT), help="Diretorio de staging ignorado pelo Git.")
    parser.add_argument(
        "--versioned-export",
        default=str(VERSIONED_EXPORT_ROOT),
        help="Diretorio versionavel para preservar assets brutos do Stitch.",
    )
    args = parser.parse_args()

    zip_path = Path(args.zip)
    staging_dir = Path(args.staging)
    versioned_export_dir = Path(args.versioned_export)
    if not staging_dir.is_absolute():
        staging_dir = ROOT / staging_dir
    if not versioned_export_dir.is_absolute():
        versioned_export_dir = ROOT / versioned_export_dir
    if not zip_path.exists():
        raise SystemExit(f"ZIP nao encontrado: {zip_path}")

    safe_extract(zip_path=zip_path, staging_dir=staging_dir)
    safe_extract(zip_path=zip_path, staging_dir=versioned_export_dir)
    design_md = versioned_export_dir / "stitch_valley_erp" / "valley" / "DESIGN.md"
    design_tokens = parse_design_tokens(design_md)
    screens, summary = build_inventory(versioned_export_dir, zip_path, staging_dir)
    write_inventory(screens, summary, design_tokens)

    print(
        json.dumps(
            {
                "status": "ok",
                "screen_count": len(screens),
                "inventory_json": INVENTORY_JSON.relative_to(ROOT).as_posix(),
                "inventory_md": INVENTORY_MD.relative_to(ROOT).as_posix(),
                "integration_map": INTEGRATION_MAP_MD.relative_to(ROOT).as_posix(),
                "tokens": TOKENS_JSON.relative_to(ROOT).as_posix(),
                "staging": staging_dir.relative_to(ROOT).as_posix(),
                "versioned_export": versioned_export_dir.relative_to(ROOT).as_posix(),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
