# PROPOSITO: Automatizar termius tailscale status no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/termius_tailscale_status.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param()

$ErrorActionPreference = 'Stop'

function Load-LocalEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvFile
    )

    if (-not (Test-Path -LiteralPath $EnvFile)) {
        return
    }

    foreach ($line in Get-Content -LiteralPath $EnvFile) {
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

    throw 'tailscale.exe nao encontrado.'
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$envFile = Join-Path $root '.env'
$runtimeDir = Join-Path $root 'tmp\runtime'
$endpointsPath = Join-Path $runtimeDir 'termius-tailscale-endpoints.txt'

Load-LocalEnv -EnvFile $envFile
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

$tailscale = Resolve-Tailscale
$ip = & $tailscale ip -4 2>$null
$status = & $tailscale status --json 2>$null
$windowsIp = ($ip | Select-Object -First 1)
$wslDistro = if ([string]::IsNullOrWhiteSpace($env:VALLEY_TAILSCALE_WSL_DISTRO)) { 'Ubuntu' } else { $env:VALLEY_TAILSCALE_WSL_DISTRO }
$wslUser = if ([string]::IsNullOrWhiteSpace($env:VALLEY_TAILSCALE_WSL_USER)) { 'eretazan' } else { $env:VALLEY_TAILSCALE_WSL_USER }
$dockerHostname = if ([string]::IsNullOrWhiteSpace($env:VALLEY_TAILSCALE_DOCKER_HOSTNAME)) { 'valley-mcp-docker' } else { $env:VALLEY_TAILSCALE_DOCKER_HOSTNAME }
$dockerIp = ''
$wslIp = ''
$wslSshReady = $false
$wslTailIpCommand = 'tailscale --socket=/run/tailscale/tailscaled.sock ip -4 2>/dev/null | head -n 1'
$wslSshCommand = "ss -lntp | grep ':22 ' || true"

Push-Location -LiteralPath $root
try {
    try {
        $dockerIp = (docker compose exec -T tailscale tailscale ip -4 2>$null | Select-Object -First 1)
    }
    catch {
        $dockerIp = ''
    }
}
finally {
    Pop-Location
}

try {
    $wslIp = (wsl.exe -d $wslDistro -u root -- bash -lc $wslTailIpCommand 2>$null | Select-Object -First 1)
    $wslSshReady = -not [string]::IsNullOrWhiteSpace((wsl.exe -d $wslDistro -u root -- bash -lc $wslSshCommand 2>$null))
}
catch {
    $wslIp = ''
    $wslSshReady = $false
}

if ([string]::IsNullOrWhiteSpace($wslIp)) {
    $wslSshReady = $false
}

$endpointLines = @(
    '[windows-host]',
    ('host=' + $windowsIp),
    'port=22',
    ('username=' + $env:USERNAME),
    'auth=SSH key ou senha local do Windows',
    '',
    '[wsl2-ubuntu]',
    ('host=' + $wslIp),
    'port=22',
    ('username=' + $wslUser),
    ('ssh_ready=' + $wslSshReady.ToString().ToLowerInvariant()),
    'auth=senha Linux do usuario ou chave SSH importada no Termius',
    '',
    '[docker-mcp]',
    ('host=' + $dockerIp),
    'port=22',
    'username=root',
    ('hostname=' + $dockerHostname),
    'auth=apenas se voce instalar ssh dentro do container; por padrao use este IP para reachability de servicos MCP',
    '',
    'notes=WSL2 so permanece online enquanto a distro estiver iniciada.'
)
$endpointLines | Set-Content -LiteralPath $endpointsPath -Encoding UTF8
[pscustomobject]@{
    Route = 'tailscale'
    TailscaleIPv4 = $windowsIp
    TermiusHost = $windowsIp
    TermiusPort = 22
    TermiusUser = $env:USERNAME
    StatusJsonAvailable = -not [string]::IsNullOrWhiteSpace($status)
    WslDistro = $wslDistro
    WslIPv4 = $wslIp
    WslSshReady = $wslSshReady
    DockerIPv4 = $dockerIp
    EndpointsFile = $endpointsPath
} | Format-List
