# PROPOSITO: Automatizar run valley safe autonomous cycle no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/run_valley_safe_autonomous_cycle.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [int]$TotalTokenBudget = 258000,
    [int]$UsedTokens = 171000,
    [string]$ActivityName = 'Ciclo autonomo seguro Valley'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$LogPath = Join-Path $RuntimeDir 'valley-safe-autonomous-cycle.log'
$StatusPath = Join-Path $RuntimeDir 'valley-safe-autonomous-cycle-status.json'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
Set-Location -LiteralPath $RepoRoot

function Write-CycleLog {
    param([string]$Message)
    $Line = '[{0}] {1}' -f (Get-Date).ToString('o'), $Message
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
    Write-Output $Line
}

function Invoke-SafeStep {
    param(
        [string]$Name,
        [string[]]$Command
    )

    Write-CycleLog "START $Name"
    & $Command[0] @($Command | Select-Object -Skip 1)
    if ($LASTEXITCODE -ne 0) {
        throw "Falha em $Name com exit code $LASTEXITCODE"
    }
    Write-CycleLog "DONE $Name"
}

$StartedAt = Get-Date
$env:CODEX_TOTAL_TOKEN_BUDGET = [string]$TotalTokenBudget
$env:CODEX_USED_TOKENS = [string]$UsedTokens

try {
    Invoke-SafeStep 'module_validate' @('python', 'scripts/automacao_sincronizador_modulos.py', 'validate')
    Invoke-SafeStep 'module_sync' @('python', 'scripts/automacao_sincronizador_modulos.py', 'sync')
    Invoke-SafeStep 'module_sql' @('python', 'scripts/automacao_sincronizador_modulos.py', 'sql')
    Invoke-SafeStep 'module_admin' @('python', 'scripts/automacao_sincronizador_modulos.py', 'admin')
    Invoke-SafeStep 'db_check' @('python', 'scripts/valley_db_orchestrator.py', 'check')
    Invoke-SafeStep 'db_report' @('python', 'scripts/valley_db_orchestrator.py', 'report')
    Invoke-SafeStep 'manual_pdf' @('python', 'scripts/automacao_gerador_pdf.py')
    Invoke-SafeStep 'token_budget' @('python', 'scripts/valley_codex_token_budget.py')

    $CompletedAt = Get-Date
    $Payload = [ordered]@{
        status = 'ok'
        activity_name = $ActivityName
        started_at = $StartedAt.ToString('o')
        completed_at = $CompletedAt.ToString('o')
        total_token_budget = $TotalTokenBudget
        used_tokens = $UsedTokens
        log_path = $LogPath
    }
    $Payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatusPath -Encoding UTF8

    python scripts/valley_communication_bridge.py set-work-status `
        --activity-name $ActivityName `
        --activity-description 'Ciclo seguro autonomo executado por agendamento/retomada sem operacoes destrutivas.' `
        --complexity 3 `
        --eta '00:00:00' `
        --progress 100 `
        --next-steps 'Aguardar proxima janela de tokens e repetir apenas o ciclo seguro.'

    python scripts/valley_communication_bridge.py send-telegram-message `
        --message 'Valley: ciclo autonomo seguro concluido. Sem deploy, sem apply em banco real, sem push e sem operacoes destrutivas.'
} catch {
    $Payload = [ordered]@{
        status = 'failed'
        activity_name = $ActivityName
        started_at = $StartedAt.ToString('o')
        failed_at = (Get-Date).ToString('o')
        error = $_.Exception.Message
        log_path = $LogPath
    }
    $Payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatusPath -Encoding UTF8
    Write-CycleLog ("FAILED {0}" -f $_.Exception.Message)
    python scripts/valley_communication_bridge.py send-telegram-message `
        --message ("Valley: ciclo autonomo seguro falhou e parou com seguranca. Erro: {0}" -f $_.Exception.Message)
    exit 1
}
