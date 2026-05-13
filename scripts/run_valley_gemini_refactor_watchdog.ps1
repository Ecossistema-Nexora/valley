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

Write-WatchdogLog "start command=$Command batch=$BatchSize cycles=$MaxCycles engine=$EngineMode"

$ArgsList = @(
    $PythonScript,
    $Command,
    '--batch-size', [string]$BatchSize,
    '--max-cycles', [string]$MaxCycles,
    '--sleep-seconds', [string]$SleepSeconds,
    '--engine-mode', $EngineMode
)

& python @ArgsList 2>&1 | ForEach-Object {
    Write-Output $_
    Write-WatchdogLog $_
}

$ExitCode = $LASTEXITCODE
Write-WatchdogLog "finish exit_code=$ExitCode"

if ($ExitCode -eq 0 -or $ExitCode -eq 2) {
    exit 0
}

exit $ExitCode
