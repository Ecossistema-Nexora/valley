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

$commandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $launcher -IntervalSeconds $IntervalSeconds"
$taskCommand = 'wscript.exe "{0}" "{1}" "{2}"' -f $runner, $root, $commandLine

$createArgs = @(
  '/Create',
  '/F',
  '/SC', 'ONLOGON',
  '/RL', 'LIMITED',
  '/TN', $TaskName,
  '/TR', $taskCommand
)

$runArgs = @(
  '/Run',
  '/TN', $TaskName
)

& schtasks.exe @createArgs | Out-Host
if (Test-Path -LiteralPath $hardener -PathType Leaf) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hardener | Out-Null
}
& schtasks.exe @runArgs | Out-Host

Write-Output "Scheduled task registrada e iniciada: $TaskName"
