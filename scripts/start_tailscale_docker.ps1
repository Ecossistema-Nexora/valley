param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$envFile = Join-Path $root '.env'

if (Test-Path -LiteralPath $envFile) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') {
            continue
        }
        $index = $line.IndexOf('=')
        $key = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim().Trim('"').Trim("'")
        if (-not [string]::IsNullOrWhiteSpace($key) -and [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($key, 'Process'))) {
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

if ([string]::IsNullOrWhiteSpace($env:TS_AUTHKEY) -and -not [string]::IsNullOrWhiteSpace($env:TAILSCALE_AUTHKEY)) {
    $env:TS_AUTHKEY = $env:TAILSCALE_AUTHKEY
}

if ([string]::IsNullOrWhiteSpace($env:TS_AUTHKEY)) {
    throw 'TS_AUTHKEY ou TAILSCALE_AUTHKEY nao configurado. Crie uma auth key no Tailscale Admin e grave apenas no .env local.'
}

Push-Location -LiteralPath $root
try {
    docker compose --profile tailscale up -d tailscale
    docker compose exec -T tailscale tailscale ip -4
}
finally {
    Pop-Location
}
