#!/usr/bin/env python3
"""Wrapper local de mongosh que executa dentro do Docker Compose do projeto."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def normalize_args(args: list[str]) -> tuple[list[str], str | None]:
    """Remove URI local e converte --file arquivo Windows para stdin do container."""

    if args and (args[0].startswith('mongodb://') or args[0].startswith('mongodb+srv://')):
        args = args[1:]

    normalized: list[str] = []
    stdin_data: str | None = None
    index = 0

    while index < len(args):
        arg = args[index]
        next_arg = args[index + 1] if index + 1 < len(args) else None

        if arg == '--file' and next_arg:
            path = Path(next_arg)
            if path.exists():
                stdin_data = path.read_text(encoding='utf-8')
                normalized.extend(['--file', '/dev/stdin'])
                index += 2
                continue

        normalized.append(arg)
        index += 1

    return normalized, stdin_data


def main() -> int:
    args, stdin_data = normalize_args(sys.argv[1:])
    command = ['docker', 'compose', 'exec', '-T', 'mongodb', 'mongosh', 'mongodb://localhost:27017/valley', *args]

    if stdin_data is None:
        return subprocess.call(command, cwd=ROOT)

    result = subprocess.run(command, cwd=ROOT, input=stdin_data, text=True, check=False)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
