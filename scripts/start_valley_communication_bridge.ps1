param(
  [int]$IntervalSeconds = 300
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $root 'tmp/runtime'
$logPath = Join-Path $runtimeDir 'communication-bridge.log'
$pidPath = Join-Path $runtimeDir 'communication-bridge.pid'

New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

$python = Get-Command python -ErrorAction Stop
$script = Join-Path $root 'scripts/valley_communication_bridge.py'

$process = Start-Process `
  -FilePath $python.Source `
  -ArgumentList @($script, 'watch', '--interval', [string]$IntervalSeconds) `
  -WorkingDirectory $root `
  -RedirectStandardOutput $logPath `
  -RedirectStandardError $logPath `
  -PassThru `
  -WindowStyle Hidden

$process.Id | Set-Content -Path $pidPath -Encoding ASCII
Write-Output "Bridge iniciado. PID=$($process.Id); log=$logPath"
