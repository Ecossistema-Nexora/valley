# PROPOSITO: Automatizar install valley communication bridge task no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/install_valley_communication_bridge_task.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
  [string]$TaskName = 'ValleyCommunicationBridge',
  [int]$IntervalSeconds = 30
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $root 'scripts\start_valley_communication_bridge.ps1'
$runner = Join-Path $root 'scripts\valley_hidden_task_runner.vbs'
$hardener = Join-Path $root 'scripts\register_valley_hidden_runtime_tasks.ps1'

if (-not (Test-Path -LiteralPath $launcher)) {
  throw "Launcher nao encontrado: $launcher"
}
if (-not (Test-Path -LiteralPath $runner)) {
  throw "Runner oculto nao encontrado: $runner"
}

$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
$commandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`" -HiddenRuntime -IntervalSeconds $IntervalSeconds"
$runnerArgs = '"{0}" "{1}" "{2}"' -f $runner, $root, $commandLine

$action = New-ScheduledTaskAction -Execute $wscript -Argument $runnerArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
  -Hidden `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Force | Out-Null

if (Test-Path -LiteralPath $hardener -PathType Leaf) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hardener | Out-Null
}
Start-ScheduledTask -TaskName $TaskName

Write-Output "Scheduled task registrada e iniciada: $TaskName"
