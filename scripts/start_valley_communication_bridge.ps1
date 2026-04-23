param(
  [int]$IntervalSeconds = 30
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $root 'tmp/runtime'
$stdoutLogPath = Join-Path $runtimeDir 'communication-bridge.out.log'
$stderrLogPath = Join-Path $runtimeDir 'communication-bridge.err.log'
$pidPath = Join-Path $runtimeDir 'communication-bridge.pid'

New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

$python = Get-Command python -ErrorAction Stop
$script = Join-Path $root 'scripts/valley_communication_bridge.py'

$process = Start-Process `
  -FilePath $python.Source `
  -ArgumentList @($script, 'watch', '--interval', [string]$IntervalSeconds) `
  -WorkingDirectory $root `
  -RedirectStandardOutput $stdoutLogPath `
  -RedirectStandardError $stderrLogPath `
  -PassThru `
  -WindowStyle Hidden

$process.Id | Set-Content -Path $pidPath -Encoding ASCII
Write-Output "Bridge iniciado. PID=$($process.Id); stdout=$stdoutLogPath; stderr=$stderrLogPath"
