<#
PROPOSITO: Executar o loop persistente de refatoracao Gemini/Codex em ciclos seguros.

CONTEXTO: Este watchdog e chamado manualmente ou pelo Agendador de Tarefas para
revarrer o repositório, aceitar por evidencia as alteracoes do Gemini e liberar
novo lote somente quando houver sinal de conclusao da tarefa anterior.

REGRAS: O lote maximo e sempre cinco arquivos. O watchdog nao apaga, nao faz
reset, nao publica deploy e nao acessa segredos. Exit code 2 do Python significa
pendencias restantes e e tratado como estado normal de continuidade.
#>

param(
    [ValidateSet('scan', 'next-task', 'loop')]
    [string]$Command = 'loop',

    [ValidateRange(1, 5)]
    [int]$BatchSize = 5,

    [ValidateRange(1, 200)]
    [int]$MaxCycles = 1,

    [ValidateRange(1, 3600)]
    [int]$SleepSeconds = 60,

    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 180,

    [ValidateSet('checkpoint', 'admin', 'release', 'sync')]
    [string]$EngineMode = 'checkpoint'
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $Root 'tmp\runtime'
$LogPath = Join-Path $RuntimeDir 'valley-gemini-refactor-watchdog.log'
$PythonScript = Join-Path $Root 'scripts\run_valley_gemini_refactor_loop.py'

if (-not (Test-Path $RuntimeDir)) {
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
}

function Write-WatchdogLog {
    param([string]$Message)
    $Timestamp = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    Add-Content -LiteralPath $LogPath -Value "[$Timestamp] $Message" -Encoding UTF8
}

Write-WatchdogLog "start command=$Command batch=$BatchSize cycles=$MaxCycles engine=$EngineMode timeout=$TimeoutSeconds"

$ArgsList = @(
    $PythonScript,
    $Command,
    '--batch-size', [string]$BatchSize,
    '--max-cycles', [string]$MaxCycles,
    '--sleep-seconds', [string]$SleepSeconds,
    '--engine-mode', $EngineMode
)

$Job = Start-Job -Name 'ValleyGeminiRefactorLoopCycle' -ScriptBlock {
    param(
        [string]$WorkingDirectory,
        [string[]]$PythonArgs
    )

    Set-Location -LiteralPath $WorkingDirectory
    $Output = & python @PythonArgs 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = @($Output)
    }
} -ArgumentList $Root, $ArgsList

$Completed = Wait-Job -Job $Job -Timeout $TimeoutSeconds
if (-not $Completed) {
    Stop-Job -Job $Job -Force | Out-Null
    Remove-Job -Job $Job -Force | Out-Null
    Write-WatchdogLog "timeout seconds=$TimeoutSeconds; next scheduled cycle will retry"
    exit 0
}

$Result = Receive-Job -Job $Job
Remove-Job -Job $Job -Force | Out-Null
foreach ($Line in @($Result.output)) {
    Write-Output $Line
    Write-WatchdogLog $Line
}

$ExitCode = [int]$Result.exit_code
Write-WatchdogLog "finish exit_code=$ExitCode"

if ($ExitCode -eq 0 -or $ExitCode -eq 2) {
    exit 0
}

exit $ExitCode
