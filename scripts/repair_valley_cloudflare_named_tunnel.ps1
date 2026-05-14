# PROPOSITO: Automatizar repair valley cloudflare named tunnel no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/repair_valley_cloudflare_named_tunnel.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [string]$AccountId = '',
    [string]$TunnelId = '80a75594-5129-469f-8cce-4a938ac48e06',
    [string]$TunnelName = 'valley-admin',
    [string]$PublicBaseUrl = 'https://admin.brasildesconto.com.br',
    [int]$AdminPort = 8085,
    [switch]$StartAfterRepair
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$EnvPath = Join-Path $RepoRoot '.env'
$CodexCloudEnvPath = Join-Path $RuntimeDir 'codex-cloud-secrets.env'
$TunnelTokenEnvPath = Join-Path $RuntimeDir 'valley-cloudflare-named-tunnel.env'
$RepairStatusPath = Join-Path $RuntimeDir 'valley-cloudflare-named-tunnel-repair.json'
$AdminPublicScript = Join-Path $RepoRoot 'scripts\start_valley_admin_public.ps1'

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ("[valley-cloudflare-repair] {0}" -f $Message)
}

function Parse-EnvFile {
    param([string]$Path)
    $Values = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $Values
    }
    foreach ($RawLine in Get-Content -LiteralPath $Path) {
        $Line = $RawLine.Trim()
        if (-not $Line -or $Line.StartsWith('#') -or -not $Line.Contains('=')) {
            continue
        }
        $Key, $Value = $Line.Split('=', 2)
        $Values[$Key.Trim()] = $Value.Trim().Trim('"').Trim("'")
    }
    return $Values
}

function Import-ValleyEnv {
    foreach ($Path in @($EnvPath, $CodexCloudEnvPath, $TunnelTokenEnvPath)) {
        foreach ($Entry in (Parse-EnvFile -Path $Path).GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($Entry.Value)) {
                continue
            }

            $CurrentValue = [Environment]::GetEnvironmentVariable($Entry.Key, 'Process')
            $ShouldOverride = @(
                'CLOUDFLARED_TOKEN',
                'VALLEY_ADMIN_PUBLIC_URL',
                'VALLEY_CLOUDFLARE_PUBLIC_URL',
                'VALLEY_PRODUCT_PUBLIC_URL'
            ) -contains $Entry.Key
            if ([string]::IsNullOrWhiteSpace($CurrentValue) -or $ShouldOverride) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
            }
        }
    }
}

function Save-RepairStatus {
    param([hashtable]$Payload)
    $Payload.generated_at = (Get-Date).ToString('o')
    [System.IO.File]::WriteAllText(
        $RepairStatusPath,
        ($Payload | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-CloudflareApi {
    param(
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,
        [object]$Body = $null
    )

    $ApiToken = $env:CLOUDFLARE_API_TOKEN
    if ([string]::IsNullOrWhiteSpace($ApiToken)) {
        $ApiToken = $env:CF_API_TOKEN
    }
    if ([string]::IsNullOrWhiteSpace($ApiToken)) {
        throw 'CLOUDFLARE_API_TOKEN/CF_API_TOKEN ausente. E necessario token com Cloudflare Tunnel Write ou Cloudflare One Connector Write.'
    }

    $Headers = @{
        Authorization = "Bearer $ApiToken"
        'Content-Type' = 'application/json'
    }
    $Uri = "https://api.cloudflare.com/client/v4$Path"
    $Params = @{
        Method = $Method
        Uri = $Uri
        Headers = $Headers
        TimeoutSec = 45
    }
    if ($null -ne $Body) {
        $Params.Body = ($Body | ConvertTo-Json -Depth 8)
    }
    return Invoke-RestMethod @Params
}

function Resolve-Cloudflared {
    foreach ($Candidate in @(
        'C:\Program Files (x86)\cloudflared\cloudflared.exe',
        'C:\Program Files\cloudflared\cloudflared.exe',
        'C:\Windows\System32\cloudflared.exe'
    )) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }
    $Command = Get-Command cloudflared -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        return $Command.Source
    }
    throw 'cloudflared nao encontrado.'
}

Import-ValleyEnv

if ([string]::IsNullOrWhiteSpace($AccountId)) {
    $AccountId = $env:CLOUDFLARE_ACCOUNT_ID
    if ([string]::IsNullOrWhiteSpace($AccountId)) {
        $AccountId = $env:CF_ACCOUNT_ID
    }
}
if ([string]::IsNullOrWhiteSpace($AccountId)) {
    $AccountId = '474fc26bf9c6bcf5e1a84b7f63a516d8'
}

try {
    Write-Step ("Consultando tunnel {0} ({1})" -f $TunnelName, $TunnelId)
    $Tunnel = Invoke-CloudflareApi -Method GET -Path "/accounts/$AccountId/cfd_tunnel/$TunnelId"
    Write-Step ("Tunnel atual: {0}" -f $Tunnel.result.status)

    Write-Step 'Obtendo token remoto do named tunnel'
    $TokenResponse = Invoke-CloudflareApi -Method GET -Path "/accounts/$AccountId/cfd_tunnel/$TunnelId/token"
    $TunnelToken = [string]$TokenResponse.result
    if ([string]::IsNullOrWhiteSpace($TunnelToken) -or $TunnelToken.Length -lt 40) {
        throw 'Cloudflare retornou token vazio ou invalido.'
    }

    @(
        '# Gerado localmente. Nao versionar.',
        "CLOUDFLARED_TOKEN=$TunnelToken",
        "VALLEY_ADMIN_PUBLIC_URL=$PublicBaseUrl"
    ) | Set-Content -LiteralPath $TunnelTokenEnvPath -Encoding ASCII

    Save-RepairStatus @{
        status = 'token_refreshed'
        account_id = $AccountId
        tunnel_id = $TunnelId
        tunnel_name = $TunnelName
        public_url = $PublicBaseUrl
        token_env_path = $TunnelTokenEnvPath
        token_length = $TunnelToken.Length
    }

    Write-Step ("Token renovado e gravado fora do Git: {0}" -f $TunnelTokenEnvPath)

    if ($StartAfterRepair) {
        $env:CLOUDFLARED_TOKEN = $TunnelToken
        $env:VALLEY_ADMIN_PUBLIC_URL = $PublicBaseUrl
        $Cloudflared = Resolve-Cloudflared
        Write-Step ("cloudflared: {0}" -f $Cloudflared)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AdminPublicScript -BindHost 127.0.0.1 -AdminPort $AdminPort -PublicBaseUrl $PublicBaseUrl
    }
} catch {
    Save-RepairStatus @{
        status = 'blocked'
        account_id = $AccountId
        tunnel_id = $TunnelId
        tunnel_name = $TunnelName
        public_url = $PublicBaseUrl
        error = $_.Exception.Message
        required_permission = 'Cloudflare Tunnel Write ou Cloudflare One Connector Write'
        dashboard_path = 'Zero Trust > Networks > Tunnels > valley-admin > Add a replica > copy token'
    }
    throw
}
