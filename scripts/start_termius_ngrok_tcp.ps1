# PROPOSITO: Automatizar start termius ngrok tcp no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_termius_ngrok_tcp.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [int]$LocalPort = 22
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtime = Join-Path $root 'tmp\runtime'
$log = Join-Path $runtime 'termius-ngrok-tcp.log'
$errLog = Join-Path $runtime 'termius-ngrok-tcp.err.log'
$envFile = Join-Path $root '.env'
$hiddenProcessScript = Join-Path $PSScriptRoot 'valley_hidden_process.ps1'

if (Test-Path -LiteralPath $hiddenProcessScript -PathType Leaf) {
    . $hiddenProcessScript
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

if (-not (Test-Path -LiteralPath $runtime)) {
    New-Item -ItemType Directory -Path $runtime | Out-Null
}

$ngrok = Get-Command ngrok -ErrorAction Stop

if (-not [string]::IsNullOrWhiteSpace($env:VALLEY_NGROK_AUTHTOKEN)) {
    & $ngrok.Source config add-authtoken $env:VALLEY_NGROK_AUTHTOKEN | Out-Null
}
else {
    $ngrokConfig = Join-Path $env:USERPROFILE 'AppData\Local\ngrok\ngrok.yml'
    $legacyConfig = Join-Path $env:USERPROFILE '.ngrok2\ngrok.yml'
    $hasSavedToken = (Test-Path -LiteralPath $ngrokConfig -PathType Leaf) -or (Test-Path -LiteralPath $legacyConfig -PathType Leaf)
    if (-not $hasSavedToken) {
        throw 'VALLEY_NGROK_AUTHTOKEN nao configurado e nenhum authtoken salvo do ngrok foi encontrado.'
    }
}

if (Get-Command Start-ValleyHiddenProcess -ErrorAction SilentlyContinue) {
    Start-ValleyHiddenProcess `
        -FilePath $ngrok.Source `
        -ArgumentList @('tcp', $LocalPort.ToString(), '--log', $log) `
        -WorkingDirectory $root `
        -StdoutLog $log `
        -StderrLog $errLog | Out-Null
} else {
    Start-Process `
        -FilePath $ngrok.Source `
        -ArgumentList @('tcp', $LocalPort.ToString(), '--log', $log) `
        -WorkingDirectory $root `
        -WindowStyle Hidden | Out-Null
}

Write-Host "ngrok TCP iniciado para localhost:$LocalPort. Consulte o endpoint no log/API local do ngrok."
