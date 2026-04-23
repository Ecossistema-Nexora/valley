from __future__ import annotations

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT / ".env"


def load_dotenv_value(key: str) -> str | None:
    if not ENV_FILE.exists():
        return None

    for raw_line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        current_key, value = line.split("=", 1)
        if current_key.strip() != key:
            continue
        return value.strip().strip('"').strip("'")
    return None


def mask_secret(secret: str) -> str:
    if len(secret) <= 8:
        return "*" * len(secret)
    return f"{secret[:4]}...{secret[-4:]}"


def main() -> int:
    env_value = os.getenv("STITCH_API_KEY")
    file_value = load_dotenv_value("STITCH_API_KEY")

    print("Valley Stitch environment check")
    print(f"Workspace root: {ROOT}")
    print(f".env exists: {'yes' if ENV_FILE.exists() else 'no'}")
    print(f"STITCH_API_KEY in process env: {'yes' if env_value else 'no'}")
    print(f"STITCH_API_KEY in .env: {'yes' if file_value else 'no'}")

    if env_value:
      print(f"Process env fingerprint: {mask_secret(env_value)}")
    if file_value:
      print(f".env fingerprint: {mask_secret(file_value)}")

    if env_value:
        print("Status: ready. VS Code MCP can resolve ${env:STITCH_API_KEY}.")
        return 0

    if file_value:
        print("Status: key found in .env, but not loaded in the current shell process.")
        print("PowerShell: $env:STITCH_API_KEY = (Get-Content .env | Select-String '^STITCH_API_KEY=').ToString().Split('=',2)[1]")
        return 0

    print("Status: missing. Add STITCH_API_KEY to .env or export it in the shell before opening MCP.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
