param(
  [string]$TaskName = 'ValleyCommunicationBridge',
  [int]$IntervalSeconds = 30
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $root 'scripts\start_valley_communication_bridge.ps1'

if (-not (Test-Path -LiteralPath $launcher)) {
  throw "Launcher nao encontrado: $launcher"
}

$escapedLauncher = $launcher.Replace('"', '""')
$arguments = "-NoProfile -ExecutionPolicy Bypass -File ""$escapedLauncher"" -IntervalSeconds $IntervalSeconds"

$createArgs = @(
  '/Create',
  '/F',
  '/SC', 'ONLOGON',
  '/RL', 'LIMITED',
  '/TN', $TaskName,
  '/TR', ('powershell.exe ' + $arguments)
)

$runArgs = @(
  '/Run',
  '/TN', $TaskName
)

& schtasks.exe @createArgs | Out-Host
& schtasks.exe @runArgs | Out-Host

Write-Output "Scheduled task registrada e iniciada: $TaskName"
