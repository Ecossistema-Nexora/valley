# PROPOSITO: Automatizar publish valley product web no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/publish_valley_product_web.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [string]$BaseHref = '/product/',
    [string]$FlutterProject = '',
    [string]$OutputDir = '',
    [string]$ApiBaseUrl = 'https://admin.brasildesconto.com.br',
    [switch]$EndUserBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $FlutterProject) {
    $FlutterProject = Join-Path $RepoRoot 'frontend\flutter'
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot 'admin\product'
}

$FlutterProjectPath = (Resolve-Path -LiteralPath $FlutterProject).Path
$OutputDirPath = [System.IO.Path]::GetFullPath($OutputDir)
$RepoRootPath = (Resolve-Path -LiteralPath $RepoRoot).Path

if (-not $FlutterProjectPath.StartsWith($RepoRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Projeto Flutter fora do workspace: $FlutterProjectPath"
}

if (-not $OutputDirPath.StartsWith($RepoRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Diretorio de saida fora do workspace: $OutputDirPath"
}

$FlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $FlutterCommand) {
    throw 'Flutter nao encontrado no PATH.'
}

Write-Output "[valley-product-web] Buildando Flutter web com base href $BaseHref"
Push-Location $FlutterProjectPath
try {
    $BuildArgs = @('build', 'web', '--release', '--base-href', $BaseHref)
    if ($EndUserBuild) {
        $BuildArgs += '--dart-define=VALLEY_END_USER_BUILD=true'
        $BuildArgs += "--dart-define=VALLEY_PRODUCT_API_BASE_URL=$ApiBaseUrl"
    }
    & $FlutterCommand.Source @BuildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build web falhou com codigo $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$BuildOutput = Join-Path $FlutterProjectPath 'build\web'
if (-not (Test-Path -LiteralPath $BuildOutput -PathType Container)) {
    throw "Saida do build web nao encontrada: $BuildOutput"
}

New-Item -ItemType Directory -Path $OutputDirPath -Force | Out-Null
Write-Output "[valley-product-web] Sincronizando $BuildOutput -> $OutputDirPath"
& robocopy $BuildOutput $OutputDirPath /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NP /XF '.DS_Store'
$RobocopyExitCode = $LASTEXITCODE
if ($RobocopyExitCode -gt 7) {
    throw "robocopy falhou com codigo $RobocopyExitCode"
}

Write-Output "[valley-product-web] Publicacao web atualizada em $OutputDirPath"
