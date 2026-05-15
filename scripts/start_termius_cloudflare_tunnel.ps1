# PROPOSITO: Automatizar start termius cloudflare tunnel no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_termius_cloudflare_tunnel.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtime = Join-Path $root 'tmp\runtime'
$outLog = Join-Path $runtime 'termius-cloudflared.out.log'
$errLog = Join-Path $runtime 'termius-cloudflared.err.log'
$envFile = Join-Path $root '.env'
$hiddenProcessScript = Join-Path $PSScriptRoot 'valley_hidden_process.ps1'

if (Test-Path -LiteralPath $hiddenProcessScript -PathType Leaf) {
    . $hiddenProcessScript
} else {
    throw "Launcher oculto nao encontrado: $hiddenProcessScript"
}

if (Test-Path -LiteralPath $envFile) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') {
            continue
        }
        $index = $line.IndexOf('=')
        $key = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim().Trim('"').Trim("'")
        if (-not [string]::IsNullOrWhiteSpace($key) -and [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($key, 'Process'))) {
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

if (-not (Test-Path -LiteralPath $runtime)) {
    New-Item -ItemType Directory -Path $runtime | Out-Null
}

if ([string]::IsNullOrWhiteSpace($env:CLOUDFLARED_TOKEN)) {
    throw 'CLOUDFLARED_TOKEN nao configurado. Defina no ambiente local ou .env operacional fora do Git.'
}

$cloudflared = Get-Command cloudflared -ErrorAction Stop

Start-ValleyHiddenProcess `
    -FilePath $cloudflared.Source `
    -ArgumentList @('tunnel', 'run', '--token', $env:CLOUDFLARED_TOKEN) `
    -WorkingDirectory $root `
    -StdoutLog $outLog `
    -StderrLog $errLog | Out-Null

Write-Host "Cloudflare Tunnel iniciado em background. Logs=$outLog $errLog"
