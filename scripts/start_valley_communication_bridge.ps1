# PROPOSITO: Automatizar start valley communication bridge no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_valley_communication_bridge.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
  [int]$IntervalSeconds = 30,
  [switch]$HiddenRuntime
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $root 'tmp/runtime'
$stdoutLogPath = Join-Path $runtimeDir 'communication-bridge.out.log'
$stderrLogPath = Join-Path $runtimeDir 'communication-bridge.err.log'
$pidPath = Join-Path $runtimeDir 'communication-bridge.pid'
$hiddenProcessScript = Join-Path $PSScriptRoot 'valley_hidden_process.ps1'

New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

if (-not $HiddenRuntime -and -not $env:VALLEY_ALLOW_VISIBLE_RUNTIME_TERMINAL) {
  try {
    Add-Type -Namespace ValleyRuntime -Name NativeWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@ -ErrorAction SilentlyContinue
    $consoleHandle = [ValleyRuntime.NativeWindow]::GetConsoleWindow()
    if ($consoleHandle -ne [IntPtr]::Zero) {
      [ValleyRuntime.NativeWindow]::ShowWindow($consoleHandle, 0) | Out-Null
    }
  } catch {
    # Best effort: the runner below still prevents long-lived visible terminals.
  }

  $runner = Join-Path $PSScriptRoot 'valley_hidden_task_runner.vbs'
  $wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
  if ((Test-Path -LiteralPath $runner -PathType Leaf) -and (Test-Path -LiteralPath $wscript -PathType Leaf)) {
    $hiddenCommandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -HiddenRuntime -IntervalSeconds $IntervalSeconds"
    $arguments = @(
      ('"{0}"' -f $runner),
      ('"{0}"' -f $root),
      ('"{0}"' -f $hiddenCommandLine)
    ) -join ' '
    Start-Process -FilePath $wscript -ArgumentList $arguments -WindowStyle Hidden | Out-Null
  }

  [ordered]@{
    status = 'delegated_to_hidden_runtime'
    service = 'valley-communication-bridge'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    detail = 'Execucao direta delegada para o runner oculto para evitar pop-up persistente de terminal no Windows.'
    hidden_runner = $runner
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runtimeDir 'communication-bridge-visible-launch-blocked.json') -Encoding UTF8
  Write-Output 'Execucao direta delegada para o runner oculto.'
  exit 0
}

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
