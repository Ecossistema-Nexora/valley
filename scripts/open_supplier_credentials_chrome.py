#!/usr/bin/env python3
"""Open a local Chrome credential wizard for pending supplier integrations.

The wizard runs only on 127.0.0.1, writes secrets to the local .env file, then
executes the existing supplier bootstrap and dropshipping repair scripts. It
never prints raw credential values in the browser response or terminal output.
"""

from __future__ import annotations

import argparse
import html
import json
import subprocess
import sys
import threading
import time
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
RUNTIME_DIR = ROOT / "tmp" / "runtime"
STATUS_PATH = RUNTIME_DIR / "valley-dropshipping-integration-status.json"
CHROME_PROFILE_DIR = Path.home() / ".codex" / "chrome-valley-supplier-setup"

PROVIDERS = {
    "amazon": (
        "Amazon",
        ("AMAZON_USER", "AMAZON_PASSWORD"),
        (
            ("AMAZON_CLIENT_ID", "LWA client ID"),
            ("AMAZON_CLIENT_SECRET", "LWA client secret"),
            ("AMAZON_ACCESS_TOKEN", "Access token"),
            ("AMAZON_REFRESH_TOKEN", "Refresh token"),
            ("AMAZON_SELLER_ID", "Seller ID"),
        ),
    ),
    "alibaba": (
        "Alibaba",
        ("ALIBABA_USER", "ALIBABA_PASSWORD"),
        (
            ("ALIBABA_CLIENT_ID", "App key"),
            ("ALIBABA_CLIENT_SECRET", "App secret"),
            ("ALIBABA_ACCESS_TOKEN", "Access token"),
            ("ALIBABA_REFRESH_TOKEN", "Refresh token"),
            ("ALIBABA_SELLER_ID", "Seller ID"),
        ),
    ),
    "shopee": (
        "Shopee",
        ("SHOPEE_USER", "SHOPEE_PASSWORD"),
        (
            ("SHOPEE_CLIENT_ID", "Partner ID"),
            ("SHOPEE_CLIENT_SECRET", "Partner key"),
            ("SHOPEE_ACCESS_TOKEN", "Access token"),
            ("SHOPEE_REFRESH_TOKEN", "Refresh token"),
            ("SHOPEE_SELLER_ID", "Shop ID"),
        ),
    ),
}

SHARED_KEYS = ("VALLEY_SUPPLIER_SHARED_USER", "VALLEY_SUPPLIER_SHARED_PASSWORD")


def load_env_lines() -> list[str]:
    if not ENV_PATH.exists():
        return []
    return ENV_PATH.read_text(encoding="utf-8").splitlines()


def update_env_values(values: dict[str, str]) -> None:
    lines = load_env_lines()
    indexes: dict[str, int] = {}
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key = stripped.split("=", 1)[0].strip()
        if key:
            indexes[key] = index

    for key, value in values.items():
        if not value:
            continue
        rendered = f"{key}={quote_env_value(value)}"
        if key in indexes:
            lines[indexes[key]] = rendered
        else:
            lines.append(rendered)

    ENV_PATH.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def quote_env_value(value: str) -> str:
    if not value:
        return ""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def run_json_command(args: list[str]) -> dict[str, object]:
    completed = subprocess.run(
        args,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=90,
        check=False,
    )
    output = completed.stdout.strip()
    try:
        payload = json.loads(output) if output else {}
    except json.JSONDecodeError:
        payload = {"status": "unparseable_output"}
    payload["returncode"] = completed.returncode
    if completed.returncode != 0:
        payload["stderr_tail"] = completed.stderr[-600:]
    return payload


def bootstrap_and_repair() -> dict[str, object]:
    python = sys.executable
    bootstrap = run_json_command(
        [
            python,
            "scripts/bootstrap_supplier_credentials.py",
            "--providers",
            "amazon,alibaba,shopee",
        ]
    )
    repair = run_json_command([python, "scripts/repair_dropshipping_integrations.py"])
    status = {}
    if STATUS_PATH.exists():
        try:
            status = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            status = {"status": "invalid_status_file"}
    return {
        "status": "ok" if bootstrap.get("returncode") == 0 and repair.get("returncode") == 0 else "failed",
        "bootstrap": {
            "configured_providers": bootstrap.get("configured_providers", []),
            "missing_providers": bootstrap.get("missing_providers", []),
            "secret_values_printed": False,
        },
        "repair_summary": status.get("summary", {}),
        "providers": [
            {
                "key": item.get("key"),
                "status": item.get("status"),
                "pending": item.get("pending", []),
                "secrets": item.get("secrets", {}),
            }
            for item in status.get("providers", [])
            if isinstance(item, dict)
        ]
        if isinstance(status, dict)
        else [],
    }


def page(title: str, body: str) -> bytes:
    document = f"""<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{html.escape(title)}</title>
    <style>
      :root {{
        color-scheme: dark;
        --bg: #10131a;
        --panel: #171d29;
        --line: #2b3547;
        --text: #edf2f8;
        --muted: #aab6c7;
        --accent: #2fbf8f;
        --danger: #ff6b6b;
      }}
      * {{ box-sizing: border-box; }}
      body {{
        margin: 0;
        font-family: Arial, sans-serif;
        background: var(--bg);
        color: var(--text);
      }}
      main {{
        width: min(1040px, calc(100vw - 32px));
        margin: 32px auto;
      }}
      h1 {{ margin: 0 0 8px; font-size: 28px; }}
      p {{ color: var(--muted); line-height: 1.45; }}
      form, section {{
        background: var(--panel);
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 22px;
      }}
      .grid {{
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
        gap: 16px;
      }}
      fieldset {{
        border: 1px solid var(--line);
        border-radius: 8px;
        padding: 16px;
        margin: 0;
      }}
      legend {{ padding: 0 8px; font-weight: 700; }}
      label {{
        display: block;
        color: var(--muted);
        font-size: 13px;
        margin: 12px 0 6px;
      }}
      input {{
        width: 100%;
        min-height: 42px;
        border: 1px solid var(--line);
        border-radius: 6px;
        background: #0f141f;
        color: var(--text);
        padding: 10px;
      }}
      button {{
        min-height: 42px;
        margin-top: 18px;
        border: 0;
        border-radius: 6px;
        padding: 0 18px;
        background: var(--accent);
        color: #04130e;
        font-weight: 700;
        cursor: pointer;
      }}
      code, pre {{
        display: block;
        max-width: 100%;
        overflow: auto;
        white-space: pre-wrap;
        color: #d7e1ee;
        background: #0f141f;
        border: 1px solid var(--line);
        border-radius: 6px;
        padding: 14px;
      }}
      .danger {{ color: var(--danger); }}
    </style>
  </head>
  <body>
    <main>{body}</main>
  </body>
</html>
"""
    return document.encode("utf-8")


def form_page() -> bytes:
    fields = []
    fields.append(
        """
        <fieldset>
          <legend>Credencial compartilhada</legend>
          <label for="shared_user">Login comum</label>
          <input id="shared_user" name="VALLEY_SUPPLIER_SHARED_USER" autocomplete="username" />
          <label for="shared_password">Senha comum</label>
          <input id="shared_password" name="VALLEY_SUPPLIER_SHARED_PASSWORD" type="password" autocomplete="current-password" />
        </fieldset>
        """
    )
    for key, (label, env_keys, official_keys) in PROVIDERS.items():
        user_key, password_key = env_keys
        official_fields = []
        for env_key, field_label in official_keys:
            input_type = "password" if "SECRET" in env_key or "TOKEN" in env_key else "text"
            official_fields.append(
                f"""
              <label for="{env_key.lower()}">{html.escape(field_label)}</label>
              <input id="{env_key.lower()}" name="{env_key}" type="{input_type}" autocomplete="off" />
                """
            )
        fields.append(
            f"""
            <fieldset>
              <legend>{html.escape(label)}</legend>
              <label for="{key}_user">Login especifico</label>
              <input id="{key}_user" name="{user_key}" autocomplete="username" />
              <label for="{key}_password">Senha especifica</label>
              <input id="{key}_password" name="{password_key}" type="password" autocomplete="current-password" />
              {''.join(official_fields)}
            </fieldset>
            """
        )
    body = f"""
      <h1>Valley Dropshipping - Credenciais Pendentes</h1>
      <p>Preencha a credencial compartilhada, credenciais especificas ou tokens oficiais para Amazon, Alibaba e Shopee. Ao salvar, os valores ficam apenas no .env local e em tmp/runtime; nenhum segredo aparece no retorno.</p>
      <form method="post" action="/save">
        <div class="grid">{''.join(fields)}</div>
        <button type="submit">Salvar e configurar fornecedores</button>
      </form>
    """
    return page("Valley Supplier Setup", body)


def result_page(result: dict[str, object]) -> bytes:
    sanitized = json.dumps(result, ensure_ascii=False, indent=2)
    body = f"""
      <h1>Configuração executada</h1>
      <p>O bootstrap e o reparo foram executados. O resumo abaixo não contém usuário, senha ou token.</p>
      <section><pre>{html.escape(sanitized)}</pre></section>
      <p>Se algum fornecedor continuar como <span class="danger">external_auth_pending</span>, ele exige token OAuth/API oficial no portal do parceiro.</p>
    """
    return page("Valley Supplier Setup - Resultado", body)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/healthz"):
            self.write_json({"status": "ok"})
            return
        self.write_html(form_page())

    def do_POST(self) -> None:  # noqa: N802
        if not self.path.startswith("/save"):
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(length).decode("utf-8", errors="replace")
        values = {
            key: value[0].strip()
            for key, value in parse_qs(raw_body, keep_blank_values=True).items()
            if value and value[0].strip()
        }
        allowed = set(SHARED_KEYS)
        for _, env_keys, official_keys in PROVIDERS.values():
            allowed.update(env_keys)
            allowed.update(env_key for env_key, _ in official_keys)
        update_env_values({key: value for key, value in values.items() if key in allowed})
        result = bootstrap_and_repair()
        self.write_html(result_page(result))

    def write_html(self, body: bytes) -> None:
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def write_json(self, payload: dict[str, object]) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def chrome_path() -> str:
    candidates = [
        Path("C:/Program Files/Google/Chrome/Application/chrome.exe"),
        Path("C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"),
        Path.home() / "AppData/Local/Google/Chrome/Application/chrome.exe",
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return ""


def open_browser(url: str) -> None:
    chrome = chrome_path()
    if chrome:
        CHROME_PROFILE_DIR.mkdir(parents=True, exist_ok=True)
        subprocess.Popen(
            [
                chrome,
                f"--user-data-dir={CHROME_PROFILE_DIR}",
                "--new-window",
                url,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return
    webbrowser.open(url)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Abre wizard local de credenciais de fornecedores no Chrome.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-browser", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    url = f"http://{args.host}:{args.port}/?{urlencode({'source': 'codex'})}"
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    if not args.no_browser:
        threading.Thread(target=lambda: (time.sleep(0.5), open_browser(url)), daemon=True).start()
    print(json.dumps({"status": "ready", "url": url, "chrome": bool(chrome_path())}, ensure_ascii=False))
    server.serve_forever(poll_interval=0.5)


if __name__ == "__main__":
    main()
