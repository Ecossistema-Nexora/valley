#!/usr/bin/env python3
"""Wrapper local de psql que executa dentro do Docker Compose do projeto."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def normalize_args(args: list[str]) -> tuple[list[str], str | None]:
    """Remove URL local e converte -f arquivo Windows para stdin do container."""

    if args and (args[0].startswith('postgresql://') or args[0].startswith('postgres://')):
        args = args[1:]

    normalized: list[str] = []
    stdin_data: str | None = None
    index = 0

    while index < len(args):
        arg = args[index]
        next_arg = args[index + 1] if index + 1 < len(args) else None

        if arg in {'-f', '--file'} and next_arg:
            path = Path(next_arg)
            if path.exists():
                stdin_data = path.read_text(encoding='utf-8')
                index += 2
                continue

        normalized.append(arg)
        index += 1

    return normalized, stdin_data


def main() -> int:
    args, stdin_data = normalize_args(sys.argv[1:])
    command = ['docker', 'compose', 'exec', '-T', 'postgres', 'psql', '-U', 'valley', '-d', 'valley', *args]

    if stdin_data is None:
        return subprocess.call(command, cwd=ROOT)

    result = subprocess.run(command, cwd=ROOT, input=stdin_data, text=True, check=False)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
