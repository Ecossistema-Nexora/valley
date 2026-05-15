<#
PROPOSITO: Registrar a rotina persistente Valley/Gemini no Agendador de Tarefas.

CONTEXTO: O usuario pediu um loop continuo no qual o Codex seleciona cinco
arquivos, o Gemini executa, informa conclusao, e o Codex libera o proximo lote.
Este instalador cria uma tarefa local que chama o watchdog periodicamente.

REGRAS: A tarefa roda no usuario atual, sem salvar senha, sem privilegio
elevado, sem deploy e sem acao destrutiva. A persistencia fica documentada no
runtime local e pode ser removida pelo nome da tarefa.
#>

param(
    [string]$TaskName = 'ValleyGeminiRefactorLoop',

    [ValidateRange(1, 1440)]
    [int]$IntervalMinutes = 5,

    [ValidateSet('checkpoint', 'admin', 'release', 'sync')]
    [string]$EngineMode = 'checkpoint'
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $Root 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-gemini-refactor-scheduled-task.json'
$Watchdog = Join-Path $Root 'scripts\run_valley_gemini_refactor_watchdog.ps1'
$HiddenTaskRunner = Join-Path $Root 'scripts\valley_hidden_task_runner.vbs'
$HiddenTaskHardener = Join-Path $Root 'scripts\register_valley_hidden_runtime_tasks.ps1'

if (-not (Test-Path $RuntimeDir)) {
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
}

if (-not (Test-Path $Watchdog)) {
    throw "Watchdog nao encontrado: $Watchdog"
}
if (-not (Test-Path $HiddenTaskRunner)) {
    throw "Runner oculto nao encontrado: $HiddenTaskRunner"
}

$PowerShell = (Get-Command powershell.exe).Source
$CommandLine = "$PowerShell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $Watchdog -Command loop -BatchSize 5 -MaxCycles 1 -EngineMode $EngineMode"
$Arguments = "`"$HiddenTaskRunner`" `"$Root`" `"$CommandLine`""
$Action = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR 'System32\wscript.exe') -Argument $Arguments -WorkingDirectory $Root
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -Hidden
$CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Principal = New-ScheduledTaskPrincipal -UserId $CurrentIdentity -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force | Out-Null
if (Test-Path -LiteralPath $HiddenTaskHardener -PathType Leaf) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HiddenTaskHardener | Out-Null
}

$Payload = [ordered]@{
    task_name = $TaskName
    installed_at_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    interval_minutes = $IntervalMinutes
    engine_mode = $EngineMode
    watchdog = (Resolve-Path $Watchdog).Path
    hidden_runner = (Resolve-Path $HiddenTaskRunner).Path
    batch_size_limit = 5
    policy = 'emit_next_batch_only_after_gemini_done_signal'
}

$Payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatusPath -Encoding UTF8
$Payload | ConvertTo-Json -Depth 5
