# PROPOSITO: Criar fallback de inicializacao oculto para a ponte de comunicacao Valley.
# CONTEXTO: Alguns Scheduled Tasks protegidos por ACL nao podem ser alterados sem elevacao no Windows.
# REGRAS: Nao abrir terminais visiveis; executar a ponte via wscript + valley_hidden_task_runner.vbs.

param(
  [int]$IntervalSeconds = 30,
  [string]$EntryName = 'ValleyCommunicationBridgeHidden.vbs'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $root 'scripts\valley_hidden_task_runner.vbs'
$launcher = Join-Path $root 'scripts\start_valley_communication_bridge.ps1'
$startupDir = [Environment]::GetFolderPath('Startup')
$entryPath = Join-Path $startupDir $EntryName
$statusPath = Join-Path $root 'tmp\runtime\communication-bridge-startup-fallback.json'
$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'

New-Item -ItemType Directory -Force -Path (Split-Path $statusPath -Parent) | Out-Null

if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
  throw "Runner oculto nao encontrado: $runner"
}
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
  throw "Launcher da ponte nao encontrado: $launcher"
}

function ConvertTo-VbsQuoted {
  param([string]$Value)
  return '"' + ($Value -replace '"', '""') + '"'
}

$commandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`" -HiddenRuntime -IntervalSeconds $IntervalSeconds"
$runnerCommand = @(
  (ConvertTo-VbsQuoted $wscript),
  (ConvertTo-VbsQuoted $runner),
  (ConvertTo-VbsQuoted $root),
  (ConvertTo-VbsQuoted $commandLine)
) -join ' '

$vbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "$($runnerCommand -replace '"', '""')", 0, False
"@

Set-Content -LiteralPath $entryPath -Value $vbs -Encoding ASCII

[ordered]@{
  status = 'ok'
  service = 'valley-communication-bridge-startup-fallback'
  generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  startup_entry = $entryPath
  launcher = $launcher
  runner = $runner
  policy = 'hidden_runtime_no_terminal_popup'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statusPath -Encoding UTF8

Write-Output "Fallback oculto criado: $entryPath"
