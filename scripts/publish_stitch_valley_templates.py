#!/usr/bin/env python3
"""PROPOSITO: Publicar templates Stitch do Valley como assets web duraveis.

CONTEXTO: O export Stitch versionado em docs/design/stitch_exports precisa
ficar acessivel no runtime publico sem substituir a UI principal do Valley.

REGRAS: Copia apenas assets versionados, gera manifest auditavel, nao grava
segredos e nao altera endpoints API existentes.
"""

from __future__ import annotations

import html
import json
import shutil
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
VERSION = "20260513_valley_erp"
SOURCE_EXPORT_ROOT = ROOT / "docs" / "design" / "stitch_exports" / VERSION / "stitch_valley_erp"
INVENTORY_JSON = ROOT / "docs" / "design" / "stitch_valley_erp_inventory.json"
PUBLIC_ROOT = ROOT / "admin" / "stitch" / VERSION
PUBLIC_EXPORT_ROOT = PUBLIC_ROOT / "stitch_valley_erp"
PUBLIC_INDEX_ROOT = ROOT / "admin" / "stitch"
RUNTIME_STATUS_PATH = ROOT / "tmp" / "runtime" / "valley-stitch-template-publication.json"
PUBLICATION_MD = ROOT / "docs" / "design" / "STITCH_VALLEY_TEMPLATE_PUBLICATION.md"
PUBLIC_HOST = "https://admin.brasildesconto.com.br"
PUBLIC_BASE_PATH = f"/stitch/{VERSION}"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def copy_export() -> None:
    if not SOURCE_EXPORT_ROOT.exists():
        raise SystemExit(f"Export versionado nao encontrado: {SOURCE_EXPORT_ROOT}")
    if PUBLIC_EXPORT_ROOT.exists():
        shutil.rmtree(PUBLIC_EXPORT_ROOT)
    PUBLIC_ROOT.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SOURCE_EXPORT_ROOT, PUBLIC_EXPORT_ROOT)


def public_url(path: str) -> str:
    return f"{PUBLIC_HOST}{path}"


def build_manifest() -> dict[str, Any]:
    inventory = load_json(INVENTORY_JSON)
    screens = inventory.get("screens") if isinstance(inventory.get("screens"), list) else []
    normalized_screens: list[dict[str, Any]] = []
    for screen in screens:
        if not isinstance(screen, dict):
            continue
        key = str(screen.get("key") or "").strip()
        if not key:
            continue
        html_path = f"{PUBLIC_BASE_PATH}/stitch_valley_erp/{key}/code.html"
        screen_path = f"{PUBLIC_BASE_PATH}/stitch_valley_erp/{key}/screen.png"
        normalized_screens.append(
            {
                "key": key,
                "title": str(screen.get("title") or key),
                "surface": str(screen.get("surface") or "shared_design"),
                "priority": str(screen.get("priority") or "P3"),
                "form_factor": str(screen.get("form_factor") or "desktop"),
                "locale": str(screen.get("locale") or "generic"),
                "integration_target": str(screen.get("integration_target") or ""),
                "public_html_path": html_path,
                "public_html_url": public_url(html_path),
                "public_screen_path": screen_path,
                "public_screen_url": public_url(screen_path),
            }
        )

    by_surface = Counter(str(item["surface"]) for item in normalized_screens)
    by_priority = Counter(str(item["priority"]) for item in normalized_screens)
    by_form_factor = Counter(str(item["form_factor"]) for item in normalized_screens)
    return {
        "status": "ok",
        "service": "valley-stitch-template-publication",
        "version": VERSION,
        "generated_at_utc": utc_now(),
        "source_export_dir": SOURCE_EXPORT_ROOT.relative_to(ROOT).as_posix(),
        "public_root": PUBLIC_ROOT.relative_to(ROOT).as_posix(),
        "public_base_path": PUBLIC_BASE_PATH,
        "public_index_path": f"{PUBLIC_BASE_PATH}/",
        "public_index_url": public_url(f"{PUBLIC_BASE_PATH}/"),
        "public_manifest_path": f"{PUBLIC_BASE_PATH}/manifest.json",
        "public_manifest_url": public_url(f"{PUBLIC_BASE_PATH}/manifest.json"),
        "template_count": len(normalized_screens),
        "by_surface": dict(sorted(by_surface.items())),
        "by_priority": dict(sorted(by_priority.items())),
        "by_form_factor": dict(sorted(by_form_factor.items())),
        "screens": sorted(
            normalized_screens,
            key=lambda item: (item["priority"], item["surface"], item["key"]),
        ),
    }


def render_index(manifest: dict[str, Any]) -> str:
    screens = manifest["screens"]
    cards = []
    rows = []
    for screen in screens:
        title = html.escape(str(screen["title"]))
        key = html.escape(str(screen["key"]))
        surface = html.escape(str(screen["surface"]))
        priority = html.escape(str(screen["priority"]))
        form_factor = html.escape(str(screen["form_factor"]))
        locale = html.escape(str(screen["locale"]))
        href = html.escape(str(screen["public_html_path"]).removeprefix(f"{PUBLIC_BASE_PATH}/"))
        png = html.escape(str(screen["public_screen_path"]).removeprefix(f"{PUBLIC_BASE_PATH}/"))
        if screen["priority"] == "P0":
            cards.append(
                f"""
                <article class="card">
                  <a href="{href}" target="_blank" rel="noopener">
                    <img src="{png}" alt="{title}" loading="lazy" />
                    <span class="pill">{priority}</span>
                    <strong>{title}</strong>
                    <small>{surface} / {form_factor} / {locale}</small>
                  </a>
                </article>
                """
            )
        rows.append(
            f"""
            <tr>
              <td>{priority}</td>
              <td><a href="{href}" target="_blank" rel="noopener">{title}</a></td>
              <td>{surface}</td>
              <td>{form_factor}</td>
              <td>{locale}</td>
              <td><a href="{png}" target="_blank" rel="noopener">PNG</a></td>
            </tr>
            """
        )

    summary = html.escape(json.dumps(manifest["by_surface"], ensure_ascii=False))
    generated = html.escape(str(manifest["generated_at_utc"]))
    template_count = int(manifest["template_count"])
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Valley Stitch ERP Templates</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f7f8fb;
      --panel: #ffffff;
      --ink: #151821;
      --muted: #5f6675;
      --line: #d8dee9;
      --accent: #006c49;
      --accent-2: #131b2e;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: Inter, Arial, sans-serif;
    }}
    header {{
      padding: 24px clamp(18px, 4vw, 48px);
      background: var(--accent-2);
      color: #fff;
      border-bottom: 4px solid var(--accent);
    }}
    h1 {{ margin: 0 0 8px; font-size: clamp(26px, 4vw, 42px); }}
    header p {{ margin: 0; color: #dce4ef; max-width: 980px; }}
    main {{ padding: 24px clamp(18px, 4vw, 48px) 48px; }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
      gap: 12px;
      margin-bottom: 24px;
    }}
    .stat, .card, table {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
    }}
    .stat {{ padding: 14px 16px; }}
    .stat strong {{ display: block; font-size: 24px; }}
    .stat span {{ color: var(--muted); font-size: 13px; }}
    h2 {{ margin: 24px 0 12px; font-size: 20px; }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 14px;
    }}
    .card a {{ color: inherit; text-decoration: none; display: block; padding: 10px; }}
    .card img {{
      width: 100%;
      aspect-ratio: 16 / 10;
      object-fit: cover;
      border-radius: 6px;
      border: 1px solid var(--line);
      background: #eef1f5;
    }}
    .card strong {{ display: block; margin-top: 10px; font-size: 14px; }}
    .card small {{ color: var(--muted); }}
    .pill {{
      display: inline-block;
      margin-top: 10px;
      padding: 3px 8px;
      border-radius: 999px;
      background: #eaf7f1;
      color: var(--accent);
      font-weight: 700;
      font-size: 12px;
    }}
    .table-wrap {{ overflow-x: auto; }}
    table {{ width: 100%; border-collapse: collapse; min-width: 760px; }}
    th, td {{ padding: 9px 10px; border-bottom: 1px solid var(--line); text-align: left; font-size: 13px; }}
    th {{ background: #eef2f7; }}
    a {{ color: #0645ad; }}
  </style>
</head>
<body>
  <header>
    <h1>Valley Stitch ERP Templates</h1>
    <p>Galeria release dos templates importados do Stitch para referencia de implantacao web, Flutter e admin.</p>
  </header>
  <main>
    <section class="stats">
      <div class="stat"><strong>{template_count}</strong><span>templates publicados</span></div>
      <div class="stat"><strong>{generated}</strong><span>gerado em UTC</span></div>
      <div class="stat"><strong>{summary}</strong><span>distribuicao por superficie</span></div>
    </section>
    <h2>Onda P0</h2>
    <section class="grid">{"".join(cards)}</section>
    <h2>Todos os templates</h2>
    <section class="table-wrap">
      <table>
        <thead><tr><th>Prioridade</th><th>Template</th><th>Superficie</th><th>Formato</th><th>Locale</th><th>Preview</th></tr></thead>
        <tbody>{"".join(rows)}</tbody>
      </table>
    </section>
  </main>
</body>
</html>
"""


def write_publication_doc(manifest: dict[str, Any]) -> None:
    lines = [
        "# Stitch Valley Template Publication",
        "",
        "<!--",
        "PROPOSITO: Registrar a publicacao web dos templates Stitch.",
        "CONTEXTO: Artefato gerado por scripts/publish_stitch_valley_templates.py.",
        "REGRAS: Nao editar manualmente; reexecutar o publicador quando o export mudar.",
        "-->",
        "",
        f"- Status: `{manifest['status']}`",
        f"- Versao: `{manifest['version']}`",
        f"- Gerado em UTC: `{manifest['generated_at_utc']}`",
        f"- Templates publicados: `{manifest['template_count']}`",
        f"- Indice publico: [{manifest['public_index_url']}]({manifest['public_index_url']})",
        f"- Manifest publico: [{manifest['public_manifest_url']}]({manifest['public_manifest_url']})",
        f"- Pasta runtime: `{manifest['public_root']}`",
        "",
        "## P0",
        "",
        "| Template | Superficie | Link |",
        "| --- | --- | --- |",
    ]
    for screen in manifest["screens"]:
        if screen["priority"] != "P0":
            continue
        lines.append(
            f"| `{screen['key']}` | {screen['surface']} | [{screen['public_html_path']}]({screen['public_html_url']}) |"
        )
    lines.extend(["", "## Todas As Telas", "", "| Prioridade | Template | Superficie | Link |", "| --- | --- | --- | --- |"])
    for screen in manifest["screens"]:
        lines.append(
            f"| {screen['priority']} | `{screen['key']}` | {screen['surface']} | "
            f"[abrir]({screen['public_html_url']}) |"
        )
    PUBLICATION_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_latest_redirect() -> None:
    PUBLIC_INDEX_ROOT.mkdir(parents=True, exist_ok=True)
    (PUBLIC_INDEX_ROOT / "index.html").write_text(
        f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="0; url=/{PUBLIC_BASE_PATH.strip('/')}/" />
  <title>Valley Stitch Templates</title>
</head>
<body>
  <a href="{PUBLIC_BASE_PATH}/">Abrir templates Stitch Valley</a>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> int:
    copy_export()
    manifest = build_manifest()
    write_json(PUBLIC_ROOT / "manifest.json", manifest)
    (PUBLIC_ROOT / "index.html").write_text(render_index(manifest), encoding="utf-8")
    write_latest_redirect()
    write_json(RUNTIME_STATUS_PATH, manifest)
    write_publication_doc(manifest)
    print(
        json.dumps(
            {
                "status": "ok",
                "template_count": manifest["template_count"],
                "public_index_url": manifest["public_index_url"],
                "public_manifest_url": manifest["public_manifest_url"],
                "runtime_status": RUNTIME_STATUS_PATH.relative_to(ROOT).as_posix(),
                "publication_doc": PUBLICATION_MD.relative_to(ROOT).as_posix(),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
