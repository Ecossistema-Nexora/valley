param(
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step {
    param([string]$Message)
    Write-Output ("[valley-compose-builder] {0}" -f $Message)
}

function Resolve-CommandSource {
    param([string]$Name)

    $Command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $Command) {
        throw ("{0} nao encontrado no PATH." -f $Name)
    }

    return $Command.Source
}

function Invoke-Step {
    param(
        [string]$Label,
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    Write-Step ("Iniciando {0}" -f $Label)
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} falhou com codigo {1}" -f $Label, $LASTEXITCODE)
    }
    Write-Step ("Concluido {0}" -f $Label)
}

$Python = Resolve-CommandSource -Name 'python'
$Docker = Resolve-CommandSource -Name 'docker'

Push-Location $RepoRoot
try {
    Invoke-Step `
        -Label 'apply-compose' `
        -FilePath $Python `
        -ArgumentList @('scripts/valley_db_orchestrator.py', 'apply-compose')

    if (-not $SkipBuild) {
        Invoke-Step `
            -Label 'builder' `
            -FilePath $Docker `
            -ArgumentList @('compose', '--profile', 'builder', 'run', '--rm', '--build', 'builder')
    } else {
        Write-Step 'Builder ignorado por --SkipBuild.'
    }
} finally {
    Pop-Location
}
