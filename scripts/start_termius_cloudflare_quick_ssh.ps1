# PROPOSITO: Automatizar start termius cloudflare quick ssh no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_termius_cloudflare_quick_ssh.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [int]$LocalPort = 22,
    [int]$WaitSeconds = 45
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtime = Join-Path $root 'tmp\runtime'
$log = Join-Path $runtime 'termius-cloudflared-quick.log'
$endpointPath = Join-Path $runtime 'termius-cloudflare-endpoint.txt'
$sshConfigPath = Join-Path $runtime 'termius-cloudflare-ssh-config'
$hiddenProcessScript = Join-Path $PSScriptRoot 'valley_hidden_process.ps1'

if (-not (Test-Path -LiteralPath $runtime)) {
    New-Item -ItemType Directory -Path $runtime | Out-Null
}

if (Test-Path -LiteralPath $hiddenProcessScript -PathType Leaf) {
    . $hiddenProcessScript
} else {
    throw "Launcher oculto nao encontrado: $hiddenProcessScript"
}

function Get-QuickTunnelHost {
    if (-not (Test-Path -LiteralPath $log)) {
        return $null
    }
    $content = Get-Content -LiteralPath $log -Raw
    $match = [regex]::Match($content, 'https://([a-z0-9-]+\.trycloudflare\.com)')
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

$hostName = Get-QuickTunnelHost
$cloudflaredRunning = @(Get-Process cloudflared -ErrorAction SilentlyContinue).Count -gt 0

if (-not $hostName -or -not $cloudflaredRunning) {
    $cloudflared = Get-Command cloudflared -ErrorAction Stop
    Start-ValleyHiddenProcess `
        -FilePath $cloudflared.Source `
        -ArgumentList @('tunnel', '--url', "ssh://localhost:$LocalPort", '--no-autoupdate', '--loglevel', 'info', '--logfile', $log) `
        -WorkingDirectory $root | Out-Null

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        Start-Sleep -Seconds 2
        $hostName = Get-QuickTunnelHost
    } while (-not $hostName -and (Get-Date) -lt $deadline)
}

if (-not $hostName) {
    throw "Cloudflare quick tunnel nao retornou hostname em $WaitSeconds segundos. Verifique $log"
}

$user = if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { 'user' } else { $env:USERNAME }
$endpointLines = @(
    "route=cloudflare-quick-ssh",
    "hostname=$hostName",
    "local_port=$LocalPort",
    "proxy_command=cloudflared access ssh --hostname $hostName"
)
Set-Content -LiteralPath $endpointPath -Value $endpointLines -Encoding UTF8

$sshConfig = @(
    'Host valley-termius-cloudflare',
    '  HostName localhost',
    "  User $user",
    '  Port 22',
    "  ProxyCommand cloudflared access ssh --hostname $hostName",
    '  StrictHostKeyChecking accept-new'
)
Set-Content -LiteralPath $sshConfigPath -Value $sshConfig -Encoding UTF8

Write-Host "Cloudflare quick SSH tunnel ativo: $hostName"
Write-Host "Endpoint: $endpointPath"
Write-Host "SSH config: $sshConfigPath"
