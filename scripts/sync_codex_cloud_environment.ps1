# PROPOSITO: Automatizar sync codex cloud environment no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/sync_codex_cloud_environment.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [string]$EnvFile = "tmp/runtime/codex-cloud-secrets.env",
    [string]$SettingsUrl = "https://chatgpt.com/codex/settings",
    [string]$ProfileDir = "tmp/runtime/codex-cloud-browser-profile",
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptPath "..")
Set-Location $RepoRoot

$EnvFilePath = Join-Path $RepoRoot $EnvFile
$RuntimeDir = Join-Path $RepoRoot "tmp/runtime"
$SetupFilePath = Join-Path $RuntimeDir "codex-cloud-setup.sh"
$StatusFilePath = Join-Path $RuntimeDir "codex-cloud-sync-status.json"
$BrowserScript = Join-Path $RepoRoot "scripts/codex_cloud_browser_sync.mjs"

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

if (-not (Test-Path $EnvFilePath)) {
    & python scripts/export_codex_cloud_env.py --output $EnvFile
}

if (-not (Test-Path $EnvFilePath)) {
    throw "Arquivo de secrets nao encontrado: $EnvFilePath"
}

$SetupScript = @'
#!/usr/bin/env bash
set -euo pipefail

python scripts/materialize_codex_cloud_env.py
python scripts/repair_dropshipping_integrations.py
'@
Set-Content -Path $SetupFilePath -Value $SetupScript -Encoding UTF8

$EnvContent = Get-Content -Raw -Path $EnvFilePath
Set-Clipboard -Value $EnvContent

$KeysTotal = 0
$KeysFilled = 0
$KeysMissing = 0
foreach ($Line in ($EnvContent -split "`r?`n")) {
    $Trimmed = $Line.Trim()
    if (-not $Trimmed -or $Trimmed.StartsWith("#") -or -not $Trimmed.Contains("=")) {
        continue
    }
    $KeysTotal += 1
    $Value = $Trimmed.Substring($Trimmed.IndexOf("=") + 1)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        $KeysMissing += 1
    } else {
        $KeysFilled += 1
    }
}

$PlaywrightStatus = "skipped"
if (-not $NoBrowser) {
    $Npx = Get-Command npx -ErrorAction SilentlyContinue
    $Npm = Get-Command npm -ErrorAction SilentlyContinue
    if (($null -ne $Npx) -and ($null -ne $Npm)) {
        $PlaywrightStatus = "started"
        & npx --yes playwright@latest install chromium | Out-Null
        & npm exec --yes --package playwright -- node $BrowserScript --settings-url $SettingsUrl --env-file $EnvFile --setup-file "tmp/runtime/codex-cloud-setup.sh" --profile-dir $ProfileDir
    } else {
        $PlaywrightStatus = "node_tooling_missing_opened_default_browser"
        Start-Process $SettingsUrl
    }
}

$Status = [ordered]@{
    status = "ok"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    settings_url = $SettingsUrl
    env_file = $EnvFile
    setup_file = "tmp/runtime/codex-cloud-setup.sh"
    keys_total = $KeysTotal
    keys_with_values = $KeysFilled
    keys_missing_values = $KeysMissing
    clipboard = "env_file_content"
    browser = $PlaywrightStatus
    secret_values_printed = $false
}

$Status | ConvertTo-Json -Depth 5 | Set-Content -Path $StatusFilePath -Encoding UTF8
$Status | ConvertTo-Json -Depth 5
