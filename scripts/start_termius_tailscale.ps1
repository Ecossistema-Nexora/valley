param(
    [string]$Hostname = 'valley-codex',
    [switch]$EnableSsh
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$envFile = Join-Path $root '.env'

function Resolve-Tailscale {
    $command = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        'C:\Program Files\Tailscale\tailscale.exe',
        'C:\Program Files (x86)\Tailscale\tailscale.exe',
        "$env:LOCALAPPDATA\Tailscale\tailscale.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw 'tailscale.exe nao encontrado. Instale com winget install --id Tailscale.Tailscale -e'
}

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

$tailscale = Resolve-Tailscale
$arguments = @('up', '--hostname', $Hostname, '--accept-routes')

if ($EnableSsh -or $env:VALLEY_TAILSCALE_SSH -eq 'true') {
    $arguments += '--ssh'
}

if (-not [string]::IsNullOrWhiteSpace($env:TAILSCALE_AUTHKEY)) {
    $arguments += ('--authkey=' + $env:TAILSCALE_AUTHKEY)
}

& $tailscale @arguments
& $tailscale ip -4
