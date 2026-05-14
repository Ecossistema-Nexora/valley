# PROPOSITO: Automatizar start tailscale wsl keepalive no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_tailscale_wsl_keepalive.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [string]$Distro = '',
    [string]$User = 'root'
)

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

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtimeDir = Join-Path $root 'tmp\runtime'
$envFile = Join-Path $root '.env'
$stdoutLog = Join-Path $runtimeDir 'wsl-tailscale-keepalive.out.log'
$stderrLog = Join-Path $runtimeDir 'wsl-tailscale-keepalive.err.log'

Load-LocalEnv -EnvFile $envFile
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

if ([string]::IsNullOrWhiteSpace($Distro)) {
    $Distro = if ([string]::IsNullOrWhiteSpace($env:VALLEY_TAILSCALE_WSL_DISTRO)) { 'Ubuntu' } else { $env:VALLEY_TAILSCALE_WSL_DISTRO }
}

$existing = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'wsl.exe' -and $_.CommandLine -like "*VALLEY_WSL_KEEPALIVE*" -and $_.CommandLine -like "*$Distro*"
}

if ($existing) {
    [pscustomobject]@{
        Status = 'already_running'
        Distro = $Distro
        ProcessId = $existing.ProcessId
        StdoutLog = $stdoutLog
        StderrLog = $stderrLog
    } | Format-List
    exit 0
}

$command = 'systemctl start ssh >/dev/null 2>&1 || true; echo VALLEY_WSL_KEEPALIVE; while true; do sleep 3600; done'
$arguments = @()
if (-not [string]::IsNullOrWhiteSpace($Distro)) {
    $arguments += @('-d', $Distro)
}
if (-not [string]::IsNullOrWhiteSpace($User)) {
    $arguments += @('-u', $User)
}
$arguments += @('--', 'bash', '-lc', $command)

$process = Start-Process -FilePath 'wsl.exe' -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru

[pscustomobject]@{
    Status = 'started'
    Distro = $Distro
    ProcessId = $process.Id
    StdoutLog = $stdoutLog
    StderrLog = $stderrLog
} | Format-List
