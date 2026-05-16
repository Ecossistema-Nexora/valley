#!/usr/bin/env python3
"""Publica a entrega Stitch v060 como fonte ativa do Valley.

O script consome somente os resultados ja salvos em tmp/runtime, baixa os
HTML/PNG gerados pelo Stitch, cria galeria publica versionada e atualiza os
contratos locais que admin e Flutter usam como fonte de verdade.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
VERSION = "20260516_valley_erp_v060"
PROJECT_ID = "12516070127536900621"
PROJECT_NAME = "projects/12516070127536900621"
PROJECT_TITLE = "Valley ERP - Omniverse Operacional"
DESIGN_SYSTEM = "assets/c566fbedbd564135b573140ef520a79f"
DESIGN_MD_SCREEN = "projects/12516070127536900621/screens/3647313235686944126"
PUBLIC_HOST = "https://admin.brasildesconto.com.br"
PUBLIC_BASE_PATH = f"/stitch/{VERSION}"

RESULTS_PATH = ROOT / "tmp" / "runtime" / "stitch_v060_generation_results.json"
ENV_PATH = ROOT / ".env"
MCP_URL = "https://stitch.googleapis.com/mcp"
SOURCE_EXPORT_ROOT = ROOT / "docs" / "design" / "stitch_exports" / VERSION / "stitch_valley_erp"
PUBLIC_ROOT = ROOT / "admin" / "stitch" / VERSION
PUBLIC_EXPORT_ROOT = PUBLIC_ROOT / "stitch_valley_erp"
PUBLIC_INDEX_ROOT = ROOT / "admin" / "stitch"
INVENTORY_JSON = ROOT / "docs" / "design" / "stitch_valley_erp_inventory.json"
INVENTORY_V060_JSON = ROOT / "docs" / "design" / "stitch_valley_erp_v060_inventory.json"
INVENTORY_MD = ROOT / "docs" / "design" / "STITCH_VALLEY_ERP_INVENTORY.md"
INTEGRATION_MAP_MD = ROOT / "docs" / "design" / "STITCH_VALLEY_ERP_INTEGRATION_MAP.md"
SOURCE_OF_TRUTH_MD = ROOT / "docs" / "design" / "STITCH_VALLEY_SOURCE_OF_TRUTH.md"
DESIGN_TOKENS_JSON = ROOT / "docs" / "design" / "stitch_valley_design_tokens.json"
PUBLICATION_MD = ROOT / "docs" / "design" / "STITCH_VALLEY_TEMPLATE_PUBLICATION.md"
PUBLICATION_V060_MD = ROOT / "docs" / "design" / "STITCH_VALLEY_V060_PUBLICATION.md"
RUNTIME_STATUS_PATH = ROOT / "tmp" / "runtime" / "valley-stitch-v060-publication.json"
SOURCE_TRUTH_PATHS = [
    ROOT / "config" / "design" / "valley_stitch_source_of_truth.json",
    ROOT / "frontend" / "flutter" / "assets" / "data" / "valley_stitch_source_of_truth.json",
    ROOT / "admin" / "product" / "assets" / "assets" / "data" / "valley_stitch_source_of_truth.json",
]

TITLE_TO_KEY = {
    "Admin Valley - Painel Modo Deus": "admin_god_mode",
    "Valley ERP - Login Lojista": "merchant_login",
    "Valley ERP - Cadastro de Empresa e Usuários": "merchant_onboarding",
    "Valley ERP - Cadastro de Empresa e Usuarios": "merchant_onboarding",
    "Valley ERP - Dashboard Operacional Lojista": "merchant_dashboard",
    "Valley ERP - Produtos, Estoque e Pedidos": "merchant_operations",
    "Valley ERP - Financeiro, Agenda e Integrações": "merchant_finance_agenda_integrations",
    "Valley ERP - Financeiro, Agenda e Integracoes": "merchant_finance_agenda_integrations",
    "Valley APK - Home MVP Modular": "customer_home",
    "Valley APK - Stock e Marketplace": "customer_stock_marketplace",
    "Valley APK - Checkout e Pagamento": "customer_checkout_payment",
    "Valley APK - Minhas Compras e Rastreio": "customer_purchases_tracking",
    "Valley APK - Central de Mensagens": "customer_messages",
    "Valley APK - Suporte Helena AI": "customer_helena_support",
    "Valley APK - Chat com Lojista": "customer_merchant_chat",
}

COURIER_KEY_SEQUENCE = [
    "courier_home_green",
    "courier_delivery_flow_green",
]


@dataclass(frozen=True)
class StitchScreen:
    key: str
    title: str
    source_prompt_key: str
    screen_id: str
    project_id: str
    project_name: str
    device: str
    form_factor: str
    surface: str
    group: str
    priority: str
    width: int
    height: int
    html_path: str
    screen_path: str
    metadata_path: str
    public_html_path: str
    public_screen_path: str
    public_html_url: str
    public_screen_url: str
    integration_target: str
    conformity: str


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def public_url(path: str) -> str:
    return f"{PUBLIC_HOST}{path}"


def load_dotenv_value(key: str) -> str | None:
    if not ENV_PATH.exists():
        return None
    for raw_line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        current_key, value = line.split("=", 1)
        if current_key.strip() == key:
            return value.strip().strip('"').strip("'")
    return None


def stitch_api_key() -> str | None:
    return os.getenv("STITCH_API_KEY") or load_dotenv_value("STITCH_API_KEY")


def mcp_call(api_key: str, method: str, params: dict[str, Any], request_id: int) -> dict[str, Any]:
    body = {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
    request = Request(
        MCP_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "X-Goog-Api-Key": api_key,
        },
        method="POST",
    )
    with urlopen(request, timeout=90) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if "error" in payload:
        raise RuntimeError(json.dumps(payload["error"], ensure_ascii=False))
    return payload


def refresh_screen_from_mcp(screen: dict[str, Any], api_key: str, request_id: int) -> dict[str, Any]:
    screen_id = str(screen.get("screen_id") or "")
    if not screen_id:
        return screen
    name = f"{PROJECT_NAME}/screens/{screen_id}"
    payload = mcp_call(
        api_key,
        "tools/call",
        {
            "name": "get_screen",
            "arguments": {
                "name": name,
                "projectId": PROJECT_ID,
                "screenId": screen_id,
            },
        },
        request_id,
    )
    content = payload.get("result", {}).get("structuredContent") or {}
    if not isinstance(content, dict):
        return screen
    updated = dict(screen)
    updated["title"] = str(content.get("title") or updated["title"])
    updated["project_name"] = str(content.get("name") or updated["project_name"])
    updated["device"] = str(content.get("deviceType") or updated["device"])
    updated["form_factor"] = "mobile" if str(updated["device"]).upper() == "MOBILE" else "desktop"
    updated["width"] = int(content.get("width") or updated["width"] or 0)
    updated["height"] = int(content.get("height") or updated["height"] or 0)
    updated["html_url"] = str(((content.get("htmlCode") or {}).get("downloadUrl")) or updated["html_url"])
    updated["screen_url"] = str(((content.get("screenshot") or {}).get("downloadUrl")) or updated["screen_url"])
    return updated


def slugify(value: str) -> str:
    clean = re.sub(r"[^a-zA-Z0-9]+", "_", value.strip().lower())
    return clean.strip("_") or "screen"


def classify(title: str, prompt_key: str, device: str) -> tuple[str, str, str, str]:
    lower_title = title.lower()
    lower_prompt = prompt_key.lower()
    if "entregador" in lower_title or lower_prompt.startswith("courier"):
        return "courier_mobile", "entregador", "frontend/flutter/lib/src/ui", "Tema verde e fluxo de entrega"
    if lower_prompt.startswith("customer") or "apk" in lower_title:
        return "customer_mobile", "usuario", "frontend/flutter/lib/src/ui", "MVP Android, Stock, Marketplace, checkout e suporte"
    if lower_prompt.startswith("merchant") or "lojista" in lower_title:
        return "merchant_erp", "lojista", "admin/app.js merchant ERP + Flutter handoff", "Login, onboarding e operacao lojista"
    if lower_prompt.startswith("admin") or "modo deus" in lower_title:
        return "admin_web", "admin", "admin/app.js + admin/styles.css", "Governanca total e Modo Deus"
    form = "mobile" if device.upper() == "MOBILE" else "desktop"
    return "shared_design", form, "docs/design handoff", "Referencia visual compartilhada"


def unique_key(title: str, prompt_key: str, seen: set[str], courier_index: int) -> tuple[str, int]:
    if title in TITLE_TO_KEY:
        key = TITLE_TO_KEY[title]
    elif "Entregador - Home Logística Verde" in title or "Entregador - Home Logistica Verde" in title:
        key = COURIER_KEY_SEQUENCE[min(courier_index, len(COURIER_KEY_SEQUENCE) - 1)]
        courier_index += 1
    else:
        key = slugify(title or prompt_key)
    if key not in seen:
        seen.add(key)
        return key, courier_index

    suffix = 2
    candidate = f"{key}_{suffix}"
    while candidate in seen:
        suffix += 1
        candidate = f"{key}_{suffix}"
    seen.add(candidate)
    return candidate, courier_index


def load_screens() -> list[dict[str, Any]]:
    if not RESULTS_PATH.exists():
        raise SystemExit(f"Resultados Stitch v060 nao encontrados: {RESULTS_PATH}")
    raw_items = json.loads(RESULTS_PATH.read_text(encoding="utf-8-sig"))
    screens: list[dict[str, Any]] = []
    seen: set[str] = set()
    courier_index = 0

    for item in raw_items:
        if not isinstance(item, dict) or not item.get("ok"):
            continue
        raw_payload = json.loads(str(item.get("raw") or "{}"))
        prompt_key = str(item.get("key") or "")
        device = str(item.get("device") or "")
        for component in raw_payload.get("outputComponents") or []:
            for screen in ((component.get("design") or {}).get("screens") or []):
                title = str(screen.get("title") or prompt_key)
                key, courier_index = unique_key(title, prompt_key, seen, courier_index)
                surface, group, integration_target, conformity = classify(title, prompt_key, device)
                screens.append(
                    {
                        "key": key,
                        "title": title,
                        "source_prompt_key": prompt_key,
                        "screen_id": str(screen.get("id") or ""),
                        "project_id": str(raw_payload.get("projectId") or PROJECT_ID),
                        "project_name": str(screen.get("name") or ""),
                        "device": str(screen.get("deviceType") or device or "DESKTOP"),
                        "form_factor": "mobile" if str(screen.get("deviceType") or device).upper() == "MOBILE" else "desktop",
                        "surface": surface,
                        "group": group,
                        "priority": "P0",
                        "width": int(screen.get("width") or 0),
                        "height": int(screen.get("height") or 0),
                        "html_url": ((screen.get("htmlCode") or {}).get("downloadUrl") or ""),
                        "screen_url": ((screen.get("screenshot") or {}).get("downloadUrl") or ""),
                        "integration_target": integration_target,
                        "conformity": conformity,
                    }
                )
    if not screens:
        raise SystemExit("Nenhuma tela Stitch v060 valida foi encontrada.")
    return screens


def download(url: str, target: Path) -> int:
    if not url:
        raise RuntimeError(f"URL vazia para {target}")
    request = Request(url, headers={"User-Agent": "Valley-Codex-Stitch-Publisher/1.0"})
    try:
        with urlopen(request, timeout=90) as response:
            content = response.read()
    except URLError as exc:
        raise RuntimeError(f"Falha ao baixar {url}: {exc}") from exc
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    return len(content)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def reset_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def materialize_screens(raw_screens: list[dict[str, Any]], refresh_mcp: bool) -> tuple[list[StitchScreen], dict[str, Any]]:
    reset_dir(SOURCE_EXPORT_ROOT)
    reset_dir(PUBLIC_EXPORT_ROOT)
    materialized: list[StitchScreen] = []
    download_failures: list[str] = []
    api_key = stitch_api_key() if refresh_mcp else None
    refresh_count = 0

    for index, initial_screen in enumerate(raw_screens, start=1):
        screen = initial_screen
        if api_key:
            screen = refresh_screen_from_mcp(initial_screen, api_key, 1000 + index)
            refresh_count += 1
        key = screen["key"]
        source_dir = SOURCE_EXPORT_ROOT / key
        public_dir = PUBLIC_EXPORT_ROOT / key
        source_html = source_dir / "code.html"
        source_png = source_dir / "screen.png"
        public_html = public_dir / "code.html"
        public_png = public_dir / "screen.png"

        try:
            html_bytes = download(str(screen["html_url"]), source_html)
            png_bytes = download(str(screen["screen_url"]), source_png)
        except RuntimeError as exc:
            download_failures.append(f"{key}: {exc}")
            continue

        public_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_html, public_html)
        shutil.copy2(source_png, public_png)

        metadata = {
            **{k: v for k, v in screen.items() if k not in {"html_url", "screen_url"}},
            "source_html_bytes": html_bytes,
            "source_screen_bytes": png_bytes,
            "published_at_utc": utc_now(),
            "source_html_path": source_html.relative_to(ROOT).as_posix(),
            "source_screen_path": source_png.relative_to(ROOT).as_posix(),
            "public_html_path": public_html.relative_to(ROOT).as_posix(),
            "public_screen_path": public_png.relative_to(ROOT).as_posix(),
        }
        write_json(source_dir / "metadata.json", metadata)
        write_json(public_dir / "metadata.json", metadata)

        html_path = source_html.relative_to(ROOT).as_posix()
        screen_path = source_png.relative_to(ROOT).as_posix()
        metadata_path = (source_dir / "metadata.json").relative_to(ROOT).as_posix()
        public_html_path = f"{PUBLIC_BASE_PATH}/stitch_valley_erp/{key}/code.html"
        public_screen_path = f"{PUBLIC_BASE_PATH}/stitch_valley_erp/{key}/screen.png"
        materialized.append(
            StitchScreen(
                key=key,
                title=str(screen["title"]),
                source_prompt_key=str(screen["source_prompt_key"]),
                screen_id=str(screen["screen_id"]),
                project_id=str(screen["project_id"]),
                project_name=str(screen["project_name"]),
                device=str(screen["device"]),
                form_factor=str(screen["form_factor"]),
                surface=str(screen["surface"]),
                group=str(screen["group"]),
                priority=str(screen["priority"]),
                width=int(screen["width"]),
                height=int(screen["height"]),
                html_path=html_path,
                screen_path=screen_path,
                metadata_path=metadata_path,
                public_html_path=public_html_path,
                public_screen_path=public_screen_path,
                public_html_url=public_url(public_html_path),
                public_screen_url=public_url(public_screen_path),
                integration_target=str(screen["integration_target"]),
                conformity=str(screen["conformity"]),
            )
        )

    if download_failures:
        raise RuntimeError("Falhas no download Stitch v060:\n" + "\n".join(download_failures))
    return materialized, {
        "html_files": len(materialized),
        "screen_files": len(materialized),
        "mcp_refreshed_screens": refresh_count,
    }


def build_manifest(screens: list[StitchScreen]) -> dict[str, Any]:
    by_surface = Counter(screen.surface for screen in screens)
    by_group = Counter(screen.group for screen in screens)
    by_form_factor = Counter(screen.form_factor for screen in screens)
    return {
        "status": "ok",
        "service": "valley-stitch-v060-publication",
        "version": VERSION,
        "project_title": PROJECT_TITLE,
        "project_id": PROJECT_ID,
        "project_name": PROJECT_NAME,
        "design_system": DESIGN_SYSTEM,
        "design_md_screen": DESIGN_MD_SCREEN,
        "generated_at_utc": utc_now(),
        "source_results": RESULTS_PATH.relative_to(ROOT).as_posix(),
        "source_export_dir": SOURCE_EXPORT_ROOT.relative_to(ROOT).as_posix(),
        "public_root": PUBLIC_ROOT.relative_to(ROOT).as_posix(),
        "public_base_path": PUBLIC_BASE_PATH,
        "public_index_path": f"{PUBLIC_BASE_PATH}/",
        "public_index_url": public_url(f"{PUBLIC_BASE_PATH}/"),
        "public_manifest_path": f"{PUBLIC_BASE_PATH}/manifest.json",
        "public_manifest_url": public_url(f"{PUBLIC_BASE_PATH}/manifest.json"),
        "template_count": len(screens),
        "p0_total": len(screens),
        "by_surface": dict(sorted(by_surface.items())),
        "by_group": dict(sorted(by_group.items())),
        "by_form_factor": dict(sorted(by_form_factor.items())),
        "screens": [asdict(screen) for screen in sorted(screens, key=lambda item: (item.group, item.key))],
        "obsolete_versions": ["20260513_valley_erp", "20260513_valley_erp_v2"],
        "rule": "Stitch v060 e a fonte ativa obrigatoria para paineis web, ERP lojista, APK usuario e APK entregador. Artefatos 20260513 foram descartados como referencia ativa.",
    }


def render_index(manifest: dict[str, Any]) -> str:
    cards = []
    rows = []
    for screen in manifest["screens"]:
        title = html.escape(str(screen["title"]))
        key = html.escape(str(screen["key"]))
        surface = html.escape(str(screen["surface"]))
        group = html.escape(str(screen["group"]))
        form_factor = html.escape(str(screen["form_factor"]))
        href = html.escape(str(screen["public_html_path"]).removeprefix(f"{PUBLIC_BASE_PATH}/"))
        png = html.escape(str(screen["public_screen_path"]).removeprefix(f"{PUBLIC_BASE_PATH}/"))
        cards.append(
            f"""
            <article class="card">
              <a href="{href}" target="_blank" rel="noopener">
                <img src="{png}" alt="{title}" loading="lazy" />
                <span class="pill">{group}</span>
                <strong>{title}</strong>
                <small>{surface} / {form_factor} / {key}</small>
              </a>
            </article>
            """
        )
        rows.append(
            f"""
            <tr>
              <td>{group}</td>
              <td><a href="{href}" target="_blank" rel="noopener">{title}</a></td>
              <td>{surface}</td>
              <td>{form_factor}</td>
              <td><a href="{png}" target="_blank" rel="noopener">PNG</a></td>
            </tr>
            """
        )

    generated = html.escape(str(manifest["generated_at_utc"]))
    count = int(manifest["template_count"])
    by_group = html.escape(json.dumps(manifest["by_group"], ensure_ascii=False))
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Valley Stitch v060</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f6f8fb;
      --panel: #ffffff;
      --ink: #15151d;
      --muted: #667085;
      --line: #d9dee8;
      --night: #07051f;
      --violet: #6f2cff;
      --green: #0f7a4a;
      --cyan: #20c8f3;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: Inter, Arial, sans-serif;
    }}
    header {{
      padding: 24px clamp(18px, 4vw, 52px);
      background: var(--night);
      color: #fff;
      border-bottom: 4px solid var(--violet);
    }}
    h1 {{ margin: 0 0 8px; font-size: clamp(26px, 4vw, 40px); letter-spacing: 0; }}
    header p {{ margin: 0; max-width: 980px; color: #e8eaf2; }}
    main {{ padding: 24px clamp(18px, 4vw, 52px) 48px; }}
    .stats, .grid {{ display: grid; gap: 14px; }}
    .stats {{ grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); margin-bottom: 24px; }}
    .stat, .card, table {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
    }}
    .stat {{ padding: 14px 16px; }}
    .stat strong {{ display: block; font-size: 24px; }}
    .stat span, .card small {{ color: var(--muted); font-size: 13px; }}
    h2 {{ margin: 24px 0 12px; font-size: 20px; letter-spacing: 0; }}
    .grid {{ grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); }}
    .card a {{ display: block; padding: 10px; color: inherit; text-decoration: none; }}
    .card img {{
      width: 100%;
      aspect-ratio: 16 / 10;
      object-fit: cover;
      border-radius: 6px;
      border: 1px solid var(--line);
      background: #eef1f5;
    }}
    .card strong {{ display: block; margin-top: 10px; font-size: 14px; }}
    .pill {{
      display: inline-block;
      margin-top: 10px;
      padding: 3px 8px;
      border-radius: 999px;
      background: #eaf7f1;
      color: var(--green);
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
    <h1>Valley Stitch v060</h1>
    <p>Entrega ativa gerada no projeto privado Stitch para Admin, Lojista, Usuario Android e Entregador.</p>
  </header>
  <main>
    <section class="stats">
      <article class="stat"><strong>{count}</strong><span>telas publicadas</span></article>
      <article class="stat"><strong>v060</strong><span>fonte ativa obrigatoria</span></article>
      <article class="stat"><strong>{generated}</strong><span>gerado em UTC</span></article>
      <article class="stat"><strong>{by_group}</strong><span>grupos cobertos</span></article>
    </section>
    <h2>Galeria</h2>
    <section class="grid">
      {''.join(cards)}
    </section>
    <h2>Manifesto</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Grupo</th><th>Tela</th><th>Superficie</th><th>Formato</th><th>PNG</th></tr></thead>
        <tbody>{''.join(rows)}</tbody>
      </table>
    </div>
  </main>
</body>
</html>
"""


def write_docs(manifest: dict[str, Any]) -> None:
    inventory = {
        "summary": {
            "generated_at_utc": manifest["generated_at_utc"],
            "source_project": PROJECT_NAME,
            "source_project_id": PROJECT_ID,
            "design_system": DESIGN_SYSTEM,
            "versioned_export_dir": SOURCE_EXPORT_ROOT.parent.relative_to(ROOT).as_posix(),
            "screen_count": manifest["template_count"],
            "by_surface": manifest["by_surface"],
            "by_group": manifest["by_group"],
            "by_form_factor": manifest["by_form_factor"],
            "obsolete_versions": manifest["obsolete_versions"],
        },
        "screens": manifest["screens"],
    }
    write_json(INVENTORY_JSON, inventory)
    write_json(INVENTORY_V060_JSON, inventory)

    lines = [
        "# Stitch Valley ERP v060 Publication",
        "",
        "<!--",
        "PROPOSITO: Registrar a publicacao ativa da entrega Stitch v060.",
        "CONTEXTO: Artefato gerado por scripts/publish_stitch_v060_project.py.",
        "REGRAS: Nao conter segredos; v060 substitui os pacotes 20260513 como referencia ativa.",
        "-->",
        "",
        f"- Gerado em UTC: `{manifest['generated_at_utc']}`",
        f"- Projeto Stitch: `{PROJECT_NAME}`",
        f"- Design system: `{DESIGN_SYSTEM}`",
        f"- Galeria publica: `{manifest['public_index_path']}`",
        f"- Manifesto publico: `{manifest['public_manifest_path']}`",
        f"- Telas publicadas: `{manifest['template_count']}`",
        f"- Grupos: `{json.dumps(manifest['by_group'], ensure_ascii=False)}`",
        "",
        "## Telas",
        "",
        "| grupo | chave | titulo | superficie | formato |",
        "| --- | --- | --- | --- | --- |",
    ]
    for screen in manifest["screens"]:
        lines.append(
            f"| {screen['group']} | `{screen['key']}` | {screen['title']} | {screen['surface']} | {screen['form_factor']} |"
        )
    lines.extend(
        [
            "",
            "## Regra De Corte",
            "",
            manifest["rule"],
            "",
        ]
    )
    text = "\n".join(lines)
    PUBLICATION_MD.write_text(text, encoding="utf-8")
    PUBLICATION_V060_MD.write_text(text, encoding="utf-8")
    write_supporting_design_docs(manifest)


def write_supporting_design_docs(manifest: dict[str, Any]) -> None:
    screens = manifest["screens"]
    generated_at = manifest["generated_at_utc"]
    SOURCE_OF_TRUTH_MD.write_text(
        "\n".join(
            [
                "PROPOSITO: Registrar a decisao mandataria de fonte da verdade visual e funcional para paineis web e APK Valley.",
                "CONTEXTO: A entrega Stitch v060 foi gerada no projeto privado, publicada localmente e aplicada no admin/Flutter.",
                "REGRAS: Usar Stitch `20260516_valley_erp_v060` como fonte obrigatoria, manter segredos fora do git e nao reintroduzir pacotes 20260513 como produto ativo.",
                "",
                "# Stitch Valley Source Of Truth",
                "",
                "## Decisao",
                "",
                "A entrega Stitch `20260516_valley_erp_v060` passa a ser a fonte da verdade obrigatoria para:",
                "",
                "- paineis web em `admin/`;",
                "- ERP lojista executavel;",
                "- trilhas mobile embarcadas no APK;",
                "- handoff Figma versionado;",
                "- release publico de galeria e manifesto.",
                "",
                "Os pacotes `20260513_valley_erp` e `20260513_valley_erp_v2` ficam obsoletos e nao devem alimentar painel web, APK ou release novo.",
                "",
                "## Artefatos Canonicos",
                "",
                "- Configuracao persistente: `config/design/valley_stitch_source_of_truth.json`.",
                f"- Manifesto publico: `admin/stitch/{VERSION}/manifest.json`.",
                f"- Galeria publica: `admin/stitch/{VERSION}/`.",
                "- Flutter asset: `frontend/flutter/assets/data/valley_stitch_source_of_truth.json`.",
                "- Painel executavel: `admin/app.js` e `admin/index.html`.",
                "- APK/Web Flutter: `frontend/flutter/lib/src/ui/valley_product_shell.dart`.",
                "- Inventario: `docs/design/stitch_valley_erp_v060_inventory.json`.",
                "- Publicacao: `docs/design/STITCH_VALLEY_V060_PUBLICATION.md`.",
                "",
                "## Regra De Publicacao",
                "",
                "1. Toda tela nova deve apontar para uma chave Stitch v060 do manifesto.",
                "2. Web/admin deve validar manifesto e DOM local antes de release.",
                "3. APK release final deve ser gerado pelo fluxo `END-USER-BUILD` quando solicitado.",
                "4. Figma deve consumir o handoff v060 versionado antes de novas codificacoes grandes.",
                "",
            ]
        ),
        encoding="utf-8",
    )

    inventory_lines = [
        "# Stitch Valley ERP Inventory",
        "",
        "<!--",
        "PROPOSITO: Inventariar a entrega Stitch Valley ERP v060.",
        "CONTEXTO: Artefato gerado por scripts/publish_stitch_v060_project.py.",
        "REGRAS: Nao editar manualmente listas extensas; reexecutar o publicador v060.",
        "-->",
        "",
        f"- Gerado em UTC: `{generated_at}`",
        f"- Assets brutos versionados: `{manifest['source_export_dir']}`",
        f"- Galeria publica: `{manifest['public_index_path']}`",
        f"- Telas HTML: `{manifest['template_count']}`",
        f"- Por grupo: `{json.dumps(manifest['by_group'], ensure_ascii=False)}`",
        f"- Por superficie: `{json.dumps(manifest['by_surface'], ensure_ascii=False)}`",
        f"- Por formato: `{json.dumps(manifest['by_form_factor'], ensure_ascii=False)}`",
        "",
        "## Telas Ativas",
        "",
        "| Tela | Grupo | Superficie | Formato | HTML | PNG |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for screen in screens:
        inventory_lines.append(
            f"| `{screen['key']}` | {screen['group']} | {screen['surface']} | {screen['form_factor']} | `{screen['html_path']}` | `{screen['screen_path']}` |"
        )
    INVENTORY_MD.write_text("\n".join(inventory_lines) + "\n", encoding="utf-8")

    integration_lines = [
        "# Stitch Valley ERP Integration Map",
        "",
        "<!--",
        "PROPOSITO: Mapear a conversao das telas Stitch v060 para Valley.",
        "CONTEXTO: Este mapa orienta Figma handoff, Flutter e admin web a partir da fonte Stitch ativa.",
        "REGRAS: Implementar por superficies reais, validar runtime e manter tokens Valley/Helena/V-Coin.",
        "-->",
        "",
        "## Decisao",
        "",
        f"- Fonte primaria de design: projeto Stitch `{PROJECT_NAME}`.",
        f"- Assets brutos versionados: `{manifest['source_export_dir']}`.",
        f"- Galeria ativa: `{manifest['public_index_path']}`.",
        "- Handoff de design: consumir `docs/design/STITCH_VALLEY_V060_PUBLICATION.md` e `docs/specs/stitch_v060_generated_screens_summary.md` no Figma.",
        "- Implementacao: admin web e Flutter devem consumir `config/design/valley_stitch_source_of_truth.json`.",
        "",
        "## P0 v060",
        "",
        "| Tela Stitch | Grupo | Superficie Valley | Alvo tecnico | Criterio de aceite |",
        "| --- | --- | --- | --- | --- |",
    ]
    for screen in screens:
        integration_lines.append(
            f"| `{screen['key']}` | {screen['group']} | {screen['surface']} | {screen['integration_target']} | Sem botao morto, responsivo e validado no runtime local |"
        )
    integration_lines.extend(
        [
            "",
            "## Guardrails",
            "",
            "- Nao introduzir referencias proibidas de produto; usar Valley, Helena e V-Coin.",
            "- Manter assets v060 publicados como referencia de handoff e fonte ativa de inspecao.",
            "- Nao reintroduzir pacotes 20260513 como fonte ativa.",
            "- Rodar validacao browser/HTTP para admin web e build Flutter quando tocar UI executavel.",
            "",
        ]
    )
    INTEGRATION_MAP_MD.write_text("\n".join(integration_lines), encoding="utf-8")

    write_json(
        DESIGN_TOKENS_JSON,
        {
            "source": "docs/specs/valley_stitch_design_system_v060.md",
            "generated_at_utc": generated_at,
            "version": VERSION,
            "design_system": DESIGN_SYSTEM,
            "colors": {
                "night": "#07051F",
                "cosmic": "#151047",
                "violet": "#6F2CFF",
                "lilac": "#BB8CFF",
                "cyan": "#20C8F3",
                "snow": "#FFFFFF",
                "work_surface": "#F6F8FB",
                "ink": "#15151D",
                "muted_ink": "#667085",
                "line": "#D9DEE8",
                "success_green": "#1E8A5A",
                "courier_green": "#0F7A4A",
                "warning_amber": "#C98205",
                "critical_red": "#D04437",
            },
            "typography_tokens": [
                "headline-lg",
                "headline-md",
                "headline-sm",
                "body-lg",
                "body-md",
                "body-sm",
                "label-md",
                "label-sm",
                "data-table",
            ],
            "radius_default_px": 8,
            "letter_spacing": "0",
            "rule": "Courier/logistics screens use courier_green; admin and merchant screens use dense neutral work surfaces with Valley accents.",
        },
    )


def source_truth_payload(manifest: dict[str, Any]) -> dict[str, Any]:
    mobile_p0 = [
        {
            "key": screen["key"],
            "template": screen["key"],
            "surface": screen["surface"],
            "group": screen["group"],
            "title": screen["title"],
            "public_html_url": screen["public_html_url"],
            "public_screen_url": screen["public_screen_url"],
        }
        for screen in manifest["screens"]
        if screen["form_factor"] == "mobile"
    ]
    return {
        "status": "active",
        "mandatory": True,
        "source_name": "Stitch Valley ERP",
        "source_version": VERSION,
        "source_project": PROJECT_NAME,
        "source_project_id": PROJECT_ID,
        "design_system": DESIGN_SYSTEM,
        "design_md_screen": DESIGN_MD_SCREEN,
        "source_results": RESULTS_PATH.relative_to(ROOT).as_posix(),
        "source_export_dir": SOURCE_EXPORT_ROOT.relative_to(ROOT).as_posix(),
        "public_gallery_path": f"{PUBLIC_BASE_PATH}/",
        "public_manifest_path": f"{PUBLIC_BASE_PATH}/manifest.json",
        "public_gallery_url": public_url(f"{PUBLIC_BASE_PATH}/"),
        "public_manifest_url": public_url(f"{PUBLIC_BASE_PATH}/manifest.json"),
        "templates_total": manifest["template_count"],
        "p0_total": manifest["p0_total"],
        "by_group": manifest["by_group"],
        "rule": manifest["rule"],
        "obsolete_versions": manifest["obsolete_versions"],
        "active_web_surfaces": [
            "admin/app.js",
            "admin/styles.css",
            f"admin/stitch/{VERSION}",
        ],
        "active_mobile_surfaces": [
            "frontend/flutter/lib/src/ui/valley_product_shell.dart",
            "frontend/flutter/assets/data/valley_stitch_source_of_truth.json",
        ],
        "p0_templates": [screen["key"] for screen in manifest["screens"]],
        "mobile_rule": "O APK deve tratar Stitch v060 como fonte ativa para usuario e entregador; pacotes 20260513 estao obsoletos.",
        "mobile_p0": mobile_p0,
    }


def write_source_truth(manifest: dict[str, Any]) -> None:
    payload = source_truth_payload(manifest)
    for path in SOURCE_TRUTH_PATHS:
        write_json(path, payload)


def write_public_assets(manifest: dict[str, Any]) -> None:
    write_json(PUBLIC_ROOT / "manifest.json", manifest)
    (PUBLIC_ROOT / "index.html").write_text(render_index(manifest), encoding="utf-8")
    PUBLIC_INDEX_ROOT.mkdir(parents=True, exist_ok=True)
    (PUBLIC_INDEX_ROOT / "index.html").write_text(
        f"""<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="0; url={PUBLIC_BASE_PATH}/" />
  <title>Valley Stitch Templates</title>
</head>
<body>
  <a href="{PUBLIC_BASE_PATH}/">Abrir templates Stitch Valley v060</a>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> int:
    global PUBLIC_HOST
    parser = argparse.ArgumentParser()
    parser.add_argument("--public-host", default=PUBLIC_HOST)
    parser.add_argument("--no-refresh-mcp", action="store_true")
    args = parser.parse_args()
    PUBLIC_HOST = str(args.public_host).rstrip("/")

    raw_screens = load_screens()
    screens, file_summary = materialize_screens(raw_screens, refresh_mcp=not args.no_refresh_mcp)
    manifest = build_manifest(screens)
    write_public_assets(manifest)
    write_docs(manifest)
    write_source_truth(manifest)
    write_json(
        RUNTIME_STATUS_PATH,
        {
            "status": "ok",
            "generated_at_utc": manifest["generated_at_utc"],
            "version": VERSION,
            "project_name": PROJECT_NAME,
            "template_count": manifest["template_count"],
            "public_manifest_path": manifest["public_manifest_path"],
            "public_index_path": manifest["public_index_path"],
            "file_summary": file_summary,
        },
    )
    print(
        json.dumps(
            {
                "status": "ok",
                "version": VERSION,
                "template_count": len(screens),
                "public_manifest_path": manifest["public_manifest_path"],
                "public_index_path": manifest["public_index_path"],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
