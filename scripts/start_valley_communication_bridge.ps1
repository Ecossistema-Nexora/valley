# PROPOSITO: Automatizar start valley communication bridge no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_valley_communication_bridge.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
  [int]$IntervalSeconds = 30
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $root 'tmp/runtime'
$stdoutLogPath = Join-Path $runtimeDir 'communication-bridge.out.log'
$stderrLogPath = Join-Path $runtimeDir 'communication-bridge.err.log'
$pidPath = Join-Path $runtimeDir 'communication-bridge.pid'
$hiddenProcessScript = Join-Path $PSScriptRoot 'valley_hidden_process.ps1'

New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

if (Test-Path -LiteralPath $hiddenProcessScript -PathType Leaf) {
  . $hiddenProcessScript
} else {
  throw "Launcher oculto nao encontrado: $hiddenProcessScript"
}

$python = Get-Command python -ErrorAction Stop
$script = Join-Path $root 'scripts/valley_communication_bridge.py'

$existingBridge = Get-CimInstance Win32_Process |
  Where-Object {
    $_.CommandLine -like '*valley_communication_bridge.py*' -and
    $_.CommandLine -like '* watch*'
  } |
  Select-Object -First 1

if ($existingBridge) {
  $existingBridge.ProcessId | Set-Content -Path $pidPath -Encoding ASCII
  Write-Output "Bridge ja esta ativo. PID=$($existingBridge.ProcessId); stdout=$stdoutLogPath; stderr=$stderrLogPath"
  exit 0
}

$process = Start-ValleyHiddenProcess `
  -FilePath $python.Source `
  -ArgumentList @($script, 'watch', '--interval', [string]$IntervalSeconds) `
  -WorkingDirectory $root `
  -StdoutLog $stdoutLogPath `
  -StderrLog $stderrLogPath `
  -PassThru

$process.Id | Set-Content -Path $pidPath -Encoding ASCII
Write-Output "Bridge iniciado. PID=$($process.Id); stdout=$stdoutLogPath; stderr=$stderrLogPath"
