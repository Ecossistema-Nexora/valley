param(
  [string]$Activity = "Operacao persistente Valley",
  [string]$Description = "Heartbeat senior persistente para SSH, Tailscale, MCP e releases.",
  [string]$Step = "monitoramento_periodico",
  [int]$Difficulty = 3,
  [int]$Percent = 100,
  [string]$Eta = "continuo",
  [int]$Done = 1,
  [int]$Pending = 0,
  [int]$IntervalSeconds = 300,
  [switch]$Once
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bridge = Join-Path $repoRoot "scripts\valley_communication_bridge.py"

function Send-ValleySeniorStatus {
  $message = @"
======================================================================
[STATUS DE ATUALIZACAO SENIOR - ECOSSISTEMA VALLEY]
======================================================================
Nome da Atividade: $Activity
Descricao: $Description
Passo sendo executado: $Step
Grau de dificuldade: $Difficulty
% concluido: $Percent%
Tempo previsto para termino: $Eta

SUMARIO NUMERICO DE ETAPAS:
- Concluidas: $Done
- Pendentes: $Pending
======================================================================
"@
  & python $bridge send-telegram-message --message $message | Out-Host
}

do {
  Send-ValleySeniorStatus
  if ($Once) { break }
  Start-Sleep -Seconds $IntervalSeconds
} while ($true)
