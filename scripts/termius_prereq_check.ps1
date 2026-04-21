param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$envFile = Join-Path $root '.env'

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

function Test-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $pathEntries = [Environment]::GetEnvironmentVariable('Path', 'Process')
    if ([string]::IsNullOrWhiteSpace($pathEntries)) {
        $pathEntries = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    }
    if ([string]::IsNullOrWhiteSpace($pathEntries)) {
        $pathEntries = ''
    }

    $extensions = @('.exe', '.cmd', '.bat', '.ps1')
    $found = $false
    $resolvedPath = $null

    foreach ($segment in $pathEntries -split ';') {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            continue
        }
        foreach ($extension in $extensions) {
            $candidate = Join-Path $segment ($Name + $extension)
            if (Test-Path -LiteralPath $candidate) {
                $found = $true
                $resolvedPath = $candidate
                break
            }
        }
        if ($found) {
            break
        }
    }

    if (-not $found -and $Name -eq 'tailscale') {
        $candidates = @(
            'C:\Program Files\Tailscale\tailscale.exe',
            'C:\Program Files (x86)\Tailscale\tailscale.exe',
            "$env:LOCALAPPDATA\Tailscale\tailscale.exe"
        )
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                $found = $true
                $resolvedPath = $candidate
                break
            }
        }
    }

    if ($found) {
        [pscustomobject]@{
            Name   = $Name
            Status = 'ok'
            Path   = $resolvedPath
        }
    }
    else {
        [pscustomobject]@{
            Name   = $Name
            Status = 'missing'
            Path   = $null
        }
    }
}

function Test-Env {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, 'User')
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, 'Machine')
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        [pscustomobject]@{
            Name   = $Name
            Status = 'missing'
            Value  = $null
        }
    }
    else {
        $masked = if ($value.Length -gt 8) { "$($value.Substring(0, 4))...$($value.Substring($value.Length - 4))" } else { 'set' }
        [pscustomobject]@{
            Name   = $Name
            Status = 'ok'
            Value  = $masked
        }
    }
}

$commands = @(
    'ssh',
    'cloudflared',
    'tailscale',
    'zerotier-cli',
    'ngrok'
) | ForEach-Object { Test-Command -Name $_ }

$envVars = @(
    'VALLEY_NGROK_AUTHTOKEN',
    'VALLEY_NGROK_ADMIN_DOMAIN',
    'CLOUDFLARED_TOKEN',
    'TAILSCALE_AUTHKEY',
    'ZEROTIER_NETWORK_ID'
) | ForEach-Object { Test-Env -Name $_ }

$commandByName = @{}
foreach ($command in $commands) {
    $commandByName[$command.Name] = $command
}

$envByName = @{}
foreach ($envVar in $envVars) {
    $envByName[$envVar.Name] = $envVar
}

$ngrokConfig = Join-Path $env:USERPROFILE 'AppData\Local\ngrok\ngrok.yml'
$legacyNgrokConfig = Join-Path $env:USERPROFILE '.ngrok2\ngrok.yml'
$ngrokSavedToken = $false
foreach ($candidate in @($ngrokConfig, $legacyNgrokConfig)) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $ngrokSavedToken = $ngrokSavedToken -or (Select-String -Path $candidate -Pattern '^\s*authtoken\s*:' -Quiet)
    }
}

$ngrokSecretReady = $envByName['VALLEY_NGROK_AUTHTOKEN'].Status -eq 'ok' -or $ngrokSavedToken
$ngrokLog = Join-Path $root 'tmp\runtime\termius-ngrok-tcp.log'
$ngrokTcpBlocked = (Test-Path -LiteralPath $ngrokLog -PathType Leaf) -and (Select-String -Path $ngrokLog -Pattern 'ERR_NGROK_8013' -Quiet)
$quickTunnelEndpoint = Join-Path $root 'tmp\runtime\termius-cloudflare-endpoint.txt'
$cloudflaredRunning = @(Get-Process cloudflared -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*cloudflared*' }).Count -gt 0
$quickTunnelReady = $cloudflaredRunning -and (Test-Path -LiteralPath $quickTunnelEndpoint -PathType Leaf)
$tailscaleIpReady = $false
if ($commandByName['tailscale'].Status -eq 'ok') {
    try {
        $tailIp = & $commandByName['tailscale'].Path ip -4 2>$null | Select-Object -First 1
        $tailscaleIpReady = -not [string]::IsNullOrWhiteSpace($tailIp)
    }
    catch {
        $tailscaleIpReady = $false
    }
}

$routes = @(
    [pscustomobject]@{
        Route       = 'cloudflare-quick-ssh'
        Command     = 'cloudflared'
        Secret      = 'none'
        Status      = if ($quickTunnelReady) { 'ready' } elseif ($commandByName['cloudflared'].Status -eq 'ok') { 'available' } else { 'unavailable' }
        Description = 'Tunnel SSH temporario sem token para validacao'
    },
    [pscustomobject]@{
        Route       = 'cloudflare-tunnel'
        Command     = 'cloudflared'
        Secret      = 'CLOUDFLARED_TOKEN'
        Status      = if ($commandByName['cloudflared'].Status -eq 'ok' -and $envByName['CLOUDFLARED_TOKEN'].Status -eq 'ok') { 'ready' } elseif ($commandByName['cloudflared'].Status -eq 'ok') { 'needs_secret' } else { 'unavailable' }
        Description = 'Preferencial para Termius externo sem expor 22/tcp'
    },
    [pscustomobject]@{
        Route       = 'tailscale'
        Command     = 'tailscale'
        Secret      = 'TAILSCALE_AUTHKEY'
        Status      = if ($tailscaleIpReady) { 'ready' } elseif ($commandByName['tailscale'].Status -eq 'ok' -and $envByName['TAILSCALE_AUTHKEY'].Status -eq 'ok') { 'ready' } elseif ($commandByName['tailscale'].Status -eq 'ok') { 'needs_secret' } else { 'unavailable' }
        Description = 'Malha privada para Termius como rede interna'
    },
    [pscustomobject]@{
        Route       = 'zerotier'
        Command     = 'zerotier-cli'
        Secret      = 'ZEROTIER_NETWORK_ID'
        Status      = if ($commandByName['zerotier-cli'].Status -eq 'ok' -and $envByName['ZEROTIER_NETWORK_ID'].Status -eq 'ok') { 'ready' } elseif ($commandByName['zerotier-cli'].Status -eq 'ok') { 'needs_secret' } else { 'unavailable' }
        Description = 'Malha privada alternativa'
    },
    [pscustomobject]@{
        Route       = 'ngrok-tcp'
        Command     = 'ngrok'
        Secret      = 'VALLEY_NGROK_AUTHTOKEN'
        Status      = if ($ngrokTcpBlocked) { 'blocked_account_verification' } elseif ($commandByName['ngrok'].Status -eq 'ok' -and $ngrokSecretReady) { 'ready' } elseif ($commandByName['ngrok'].Status -eq 'ok') { 'needs_secret' } else { 'unavailable' }
        Description = 'Ponte temporaria, nao permanente'
    }
)

Write-Host 'Termius prerequisite diagnostic' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Commands:'
$commands | Format-Table -AutoSize | Out-String | Write-Host
Write-Host 'Environment:'
$envVars | Format-Table -AutoSize | Out-String | Write-Host
Write-Host 'External route readiness:'
$routes | Format-Table -AutoSize | Out-String | Write-Host

$sshReady = $commandByName['ssh'].Status -eq 'ok'
$readyRoutes = @($routes | Where-Object { $_.Status -eq 'ready' })
$partialRoutes = @($routes | Where-Object { $_.Status -eq 'needs_secret' })

if (-not $sshReady) {
    Write-Host 'Next steps:' -ForegroundColor Yellow
    Write-Host '- Install or expose OpenSSH client: ssh'
    exit 1
}

if ($readyRoutes.Count -gt 0) {
    Write-Host ('Ready route(s): ' + (($readyRoutes | Select-Object -ExpandProperty Route) -join ', ')) -ForegroundColor Green
    exit 0
}

if ($partialRoutes.Count -gt 0) {
    Write-Host 'At least one external route is installed, but secrets are still local prerequisites.' -ForegroundColor Yellow
    Write-Host ('Set locally, outside the repo: ' + (($partialRoutes | Select-Object -ExpandProperty Secret -Unique) -join ', '))
    exit 2
}

Write-Host 'No external route command is installed. Install cloudflared, tailscale, zerotier-cli, or ngrok.' -ForegroundColor Yellow
exit 1
