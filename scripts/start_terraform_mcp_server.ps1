<#
PROPOSITO: Iniciar o Terraform MCP Server em transporte stdio para clientes MCP.

CONTEXTO: Este wrapper permite que VS Code, Codex e outros clientes usem o
Terraform MCP sem depender de PATH global fixo. Ele prioriza binario local
em tmp/runtime/tools e usa Docker apenas como fallback.

REGRAS: Nao escrever em stdout antes do servidor MCP, nao versionar tokens,
herdar TFE_TOKEN/TFE_ADDRESS apenas do ambiente local e manter
ENABLE_TF_OPERATIONS desativado salvo configuracao explicita do operador.
#>

param(
  [string]$Mode = 'stdio'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$LocalBinary = Join-Path $RepoRoot 'tmp\runtime\tools\terraform-mcp-server.exe'
$Command = Get-Command terraform-mcp-server -ErrorAction SilentlyContinue | Select-Object -First 1

if (Test-Path -LiteralPath $LocalBinary -PathType Leaf) {
  & $LocalBinary $Mode
  exit $LASTEXITCODE
}

if ($Command) {
  & $Command.Source $Mode
  exit $LASTEXITCODE
}

$Docker = Get-Command docker -ErrorAction SilentlyContinue | Select-Object -First 1
if ($Docker) {
  $DockerArgs = @('run', '-i', '--rm')
  foreach ($Name in @('TFE_ADDRESS', 'TFE_TOKEN', 'TFE_SKIP_TLS_VERIFY', 'ENABLE_TF_OPERATIONS')) {
    $Value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
      $DockerArgs += @('-e', $Name)
    }
  }
  $DockerArgs += 'hashicorp/terraform-mcp-server'
  & $Docker.Source @DockerArgs
  exit $LASTEXITCODE
}

[Console]::Error.WriteLine('Terraform MCP Server nao encontrado. Execute scripts/install_terraform_mcp_server.ps1 ou inicie Docker Desktop.')
exit 1
