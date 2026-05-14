# PROPOSITO: Automatizar tailscale docker status no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/tailscale_docker_status.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location -LiteralPath $root
try {
    docker compose ps tailscale
    docker compose exec -T tailscale tailscale status 2>$null
    docker compose exec -T tailscale tailscale ip -4 2>$null
}
finally {
    Pop-Location
}
