#!/usr/bin/env bash
set -euo pipefail

cd /workspace

export VALLEY_SKIP_DOCKER_CHECKS="${VALLEY_SKIP_DOCKER_CHECKS:-true}"

run_release() {
  python scripts/valley_db_orchestrator.py check
  python scripts/valley_db_orchestrator.py apply-postgres
  python scripts/valley_db_orchestrator.py apply-mongo
  python scripts/valley_db_orchestrator.py report
}

command_name="${1:-release}"

case "${command_name}" in
  release)
    shift || true
    run_release "$@"
    ;;
  check|report|apply-postgres|apply-mongo)
    shift || true
    python scripts/valley_db_orchestrator.py "${command_name}" "$@"
    ;;
  admin)
    shift || true
    python scripts/valley_admin_builder.py build "$@"
    ;;
  sync-modules)
    shift || true
    python scripts/automacao_sincronizador_modulos.py sync "$@"
    ;;
  shell)
    shift || true
    exec bash "$@"
    ;;
  *)
    exec "$@"
    ;;
esac

