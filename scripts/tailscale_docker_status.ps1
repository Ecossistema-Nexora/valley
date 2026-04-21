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
