# PROPOSITO: Automatizar apply valley db via wsl no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/apply_valley_db_via_wsl.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [string]$Distro = '',
    [string]$WslUser = 'root',
    [switch]$RunCheck = $true,
    [switch]$RunReport = $true,
    [switch]$RunSeeds,
    [switch]$RunSmoke,
    [switch]$ResetPostgresVolume
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

function Invoke-WslBash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Script
    )

    $arguments = @()
    if (-not [string]::IsNullOrWhiteSpace($script:Distro)) {
        $arguments += @('-d', $script:Distro)
    }
    if (-not [string]::IsNullOrWhiteSpace($script:WslUser)) {
        $arguments += @('-u', $script:WslUser)
    }
    $arguments += @('--', 'bash', '-lc', $Script)

    & wsl.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed with exit code $LASTEXITCODE."
    }
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtimeDir = Join-Path $root 'tmp\runtime'
$envFile = Join-Path $root '.env'

Load-LocalEnv -EnvFile $envFile
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

if ([string]::IsNullOrWhiteSpace($Distro)) {
    $Distro = if ([string]::IsNullOrWhiteSpace($env:VALLEY_TAILSCALE_WSL_DISTRO)) { 'Ubuntu' } else { $env:VALLEY_TAILSCALE_WSL_DISTRO }
}

if ($root.ProviderPath -notmatch '^[A-Za-z]:\\') {
    throw "Caminho de worktree inesperado: $($root.ProviderPath)"
}

$driveLetter = $root.ProviderPath.Substring(0, 1).ToLowerInvariant()
$linuxRoot = "/mnt/$driveLetter/" + ($root.ProviderPath.Substring(3) -replace '\\', '/')

$bootstrap = @'
set -euo pipefail
cd '__LINUX_ROOT__'
cat > /tmp/psql <<'EOF'
#!/bin/sh
exec python3 '__LINUX_ROOT__/tools/bin/psql_wrapper.py' "$@"
EOF
cat > /tmp/mongosh <<'EOF'
#!/bin/sh
exec python3 '__LINUX_ROOT__/tools/bin/mongosh_wrapper.py' "$@"
EOF
chmod +x /tmp/psql /tmp/mongosh
export PATH="/tmp:$PATH"
'@.Replace('__LINUX_ROOT__', $linuxRoot)

Write-Host "Valley DB via WSL - distro=$Distro user=$WslUser"

Invoke-WslBash -Script ($bootstrap + @"
docker compose up -d postgres mongodb
"@)

if ($ResetPostgresVolume) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $root 'tmp\runtime\db-volume-backups'
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $backupName = "valley-postgres-data-$timestamp-raw-backup.tgz"
    if ($backupDir -notmatch '^[A-Za-z]:\\') {
        throw "Caminho de backup inesperado: $backupDir"
    }
    $backupDriveLetter = $backupDir.Substring(0, 1).ToLowerInvariant()
    $linuxBackupDir = "/mnt/$backupDriveLetter/" + ($backupDir.Substring(3) -replace '\\', '/')

    Invoke-WslBash -Script ($bootstrap + @"
mkdir -p '$linuxBackupDir'
docker run --rm -v valley_valley-postgres-data:/from -v '$linuxBackupDir':/backup alpine sh -lc 'cd /from && tar czf /backup/$backupName .'
docker compose stop postgres || true
docker compose rm -sf postgres || true
docker volume rm valley_valley-postgres-data
docker compose up -d postgres
"@)

    Write-Host "Backup bruto do volume PostgreSQL salvo em $backupDir\\$backupName"
}

Invoke-WslBash -Script ($bootstrap + @'
for attempt in $(seq 1 90); do
  pg_status=$(docker inspect --format='{{.State.Health.Status}}' valley-postgres 2>/dev/null || echo unknown)
  mongo_status=$(docker inspect --format='{{.State.Health.Status}}' valley-mongodb 2>/dev/null || echo unknown)
  echo "postgres:$pg_status mongodb:$mongo_status"
  if [ "$pg_status" = 'healthy' ] && [ "$mongo_status" = 'healthy' ]; then
    exit 0
  fi
  sleep 2
done
exit 1
'@)

if ($RunCheck) {
    Invoke-WslBash -Script ($bootstrap + @"
python3 scripts/valley_db_orchestrator.py check
"@)
}

Invoke-WslBash -Script ($bootstrap + @"
python3 scripts/valley_db_orchestrator.py apply-postgres
python3 scripts/valley_db_orchestrator.py apply-mongo
"@)

if ($RunSeeds) {
    Invoke-WslBash -Script ($bootstrap + @"
python3 scripts/valley_db_orchestrator.py seed-compose
"@)
}

if ($RunSmoke) {
    Invoke-WslBash -Script ($bootstrap + @"
python3 scripts/valley_db_orchestrator.py smoke-compose
"@)
}

if ($RunReport) {
    Invoke-WslBash -Script ($bootstrap + @"
python3 scripts/valley_db_orchestrator.py report
"@)
}

Write-Host 'Aplicacao Valley DB via WSL concluida.'
