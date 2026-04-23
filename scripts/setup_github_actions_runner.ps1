param(
  [string]$RunnerRoot = "C:\actions-runner",
  [string]$RepoUrl = "https://github.com/Ecossistema-Nexora/valley",
  [string]$RunnerVersion = "2.333.1",
  [string]$RunnerArch = "x64",
  [string]$RunnerName = $env:COMPUTERNAME,
  [string]$RunnerLabels = "self-hosted,windows,valley",
  [switch]$Configure,
  [switch]$InstallService,
  [switch]$StartRunner,
  [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"

function Write-Step($message) {
  Write-Host "[valley-runner] $message" -ForegroundColor Cyan
}

function Get-RunnerToken {
  if ([string]::IsNullOrWhiteSpace($env:GITHUB_RUNNER_TOKEN)) {
    throw "GITHUB_RUNNER_TOKEN ausente. Defina a variavel no ambiente antes de configurar o runner."
  }
  return $env:GITHUB_RUNNER_TOKEN
}

$runnerFile = "actions-runner-win-$RunnerArch-$RunnerVersion.zip"
$downloadUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/$runnerFile"
$zipPath = Join-Path $RunnerRoot $runnerFile

Write-Step "Preparando diretório $RunnerRoot"
New-Item -ItemType Directory -Path $RunnerRoot -Force | Out-Null

if ($ForceDownload -or -not (Test-Path -LiteralPath $zipPath)) {
  Write-Step "Baixando runner $RunnerVersion ($RunnerArch)"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
} else {
  Write-Step "Pacote já existe em $zipPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $RunnerRoot "config.cmd"))) {
  Write-Step "Extraindo pacote do runner"
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $RunnerRoot, $true)
} else {
  Write-Step "Runner já extraído"
}

if ($Configure) {
  $token = Get-RunnerToken
  Write-Step "Configurando runner para $RepoUrl"
  Push-Location $RunnerRoot
  try {
    & .\config.cmd `
      --unattended `
      --url $RepoUrl `
      --token $token `
      --name $RunnerName `
      --labels $RunnerLabels `
      --work "_work" `
      --replace
  } finally {
    Pop-Location
  }
}

if ($InstallService) {
  Write-Step "Instalando serviço do runner"
  Push-Location $RunnerRoot
  try {
    & .\svc.cmd install
  } finally {
    Pop-Location
  }
}

if ($StartRunner) {
  Push-Location $RunnerRoot
  try {
    if ($InstallService) {
      Write-Step "Iniciando serviço do runner"
      & .\svc.cmd start
    } else {
      Write-Step "Iniciando runner em foreground"
      & .\run.cmd
    }
  } finally {
    Pop-Location
  }
}

Write-Step "Concluído"
