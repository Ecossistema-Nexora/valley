<#
PROPOSITO: Instalar watchdog persistente de regeneracao do token Cloudflare Valley.

CONTEXTO: O dominio fixo admin.brasildesconto.com.br depende do named tunnel
valley-admin. O watchdog reexecuta a regeneracao sem pedir confirmacao e grava
evidencias locais ate que o tunnel fique saudavel.

REGRAS: Nao imprime segredos, nao habilita ngrok, roda no usuario atual e chama
somente scripts do repositorio Valley.
#>

param(
    [string]$TaskName = 'ValleyCloudflareTokenRegeneration',

    [ValidateRange(1, 1440)]
    [int]$IntervalMinutes = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-cloudflare-token-regeneration-task.json'
$ScriptPath = Join-Path $RepoRoot 'scripts\ensure_valley_cloudflare_token_regeneration.ps1'
$HiddenTaskRunner = Join-Path $RepoRoot 'scripts\valley_hidden_task_runner.vbs'
$HiddenTaskHardener = Join-Path $RepoRoot 'scripts\register_valley_hidden_runtime_tasks.ps1'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    throw "Script de regeneracao nao encontrado: $ScriptPath"
}
if (-not (Test-Path -LiteralPath $HiddenTaskRunner -PathType Leaf)) {
    throw "Runner oculto nao encontrado: $HiddenTaskRunner"
}

$PowerShell = (Get-Command powershell.exe).Source
$CommandLine = "$PowerShell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $ScriptPath -StartAfterRefresh -PersistUserEnv"
$Arguments = "`"$HiddenTaskRunner`" `"$RepoRoot`" `"$CommandLine`""
$Action = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR 'System32\wscript.exe') -Argument $Arguments -WorkingDirectory $RepoRoot
$Trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 20) `
    -Hidden
$CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Principal = New-ScheduledTaskPrincipal -UserId $CurrentIdentity -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force | Out-Null
if (Test-Path -LiteralPath $HiddenTaskHardener -PathType Leaf) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HiddenTaskHardener | Out-Null
}

$Payload = [ordered]@{
    status = 'installed'
    task_name = $TaskName
    installed_at_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    interval_minutes = $IntervalMinutes
    script = (Resolve-Path $ScriptPath).Path
    hidden_runner = (Resolve-Path $HiddenTaskRunner).Path
    policy = 'cloudflare_only_ngrok_disabled_release_blocked_until_validated'
    status_path = (Join-Path $RuntimeDir 'valley-cloudflare-token-regeneration-status.json')
}

$Payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatusPath -Encoding UTF8
$Payload | ConvertTo-Json -Depth 5
