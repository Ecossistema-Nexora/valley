param(
    [string]$ZoneId = 'ec42e46c3012a03fa30b04e96abc553c',
    [string]$AccountId = '474fc26bf9c6bcf5e1a84b7f63a516d8',
    [string]$TunnelId = '80a75594-5129-469f-8cce-4a938ac48e06',
    [string]$PublicHost = 'brasildesconto.com.br',
    [string]$AdminHost = 'admin.brasildesconto.com.br',
    [string]$OriginUrl = 'http://192.168.1.2:8085',
    [bool]$ForceIpv4 = $true,
    [bool]$ReplaceConflictingRecords = $true,
    [switch]$PlanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-public-domains-automation.json'
$ManifestPath = Join-Path $RepoRoot 'output\deployment\valley-module-subdomains.json'
$Planner = Join-Path $RepoRoot 'scripts\plan_valley_module_subdomains.py'
$EnvPath = Join-Path $RepoRoot '.env'
$CodexCloudEnvPath = Join-Path $RuntimeDir 'codex-cloud-secrets.env'

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ("[valley-public-domains] {0}" -f $Message)
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
        if ($Key.Trim()) {
            $Values[$Key.Trim()] = $Value.Trim().Trim('"').Trim("'")
        }
    }
    return $Values
}

function Import-ValleyEnv {
    foreach ($Path in @($EnvPath, $CodexCloudEnvPath)) {
        foreach ($Entry in (Parse-EnvFile -Path $Path).GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Entry.Key, 'Process'))) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
            }
        }
    }
}

function Resolve-Python {
    $Python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Python) {
        return @{
            FilePath = $Python.Source
            Prefix = @()
        }
    }
    $Py = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Py) {
        return @{
            FilePath = $Py.Source
            Prefix = @('-3')
        }
    }
    throw 'Python nao encontrado no PATH.'
}

function Get-PublicIp {
    param([string]$Family)
    try {
        $Flag = if ($Family -eq 'ipv6') { '-6' } else { '-4' }
        $Url = if ($Family -eq 'ipv6') { 'https://api64.ipify.org' } else { 'https://api.ipify.org' }
        return (& curl.exe $Flag -s --max-time 10 $Url).Trim()
    } catch {
        return ''
    }
}

function Save-Status {
    param([hashtable]$Payload)
    $Payload.generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    [System.IO.File]::WriteAllText(
        $StatusPath,
        ($Payload | ConvertTo-Json -Depth 10),
        [System.Text.UTF8Encoding]::new($false)
    )
}

Import-ValleyEnv

if ([string]::IsNullOrWhiteSpace($env:CLOUDFLARE_ZONE_ID)) {
    $env:CLOUDFLARE_ZONE_ID = $ZoneId
}
if ([string]::IsNullOrWhiteSpace($env:CLOUDFLARE_ACCOUNT_ID)) {
    $env:CLOUDFLARE_ACCOUNT_ID = $AccountId
}
$env:CLOUDFLARE_TUNNEL_ID = $TunnelId
$env:VALLEY_PUBLIC_SITE_HOST = $PublicHost
$env:VALLEY_ADMIN_SITE_HOST = $AdminHost
$env:VALLEY_MODULE_DNS_ZONE_HOST = $AdminHost
$env:VALLEY_MODULE_DNS_TARGET_HOST = $AdminHost
$env:VALLEY_ADMIN_TUNNEL_ORIGIN = $OriginUrl
$env:VALLEY_PRODUCT_PUBLIC_URL = "https://$PublicHost"

$TokenPresent = -not [string]::IsNullOrWhiteSpace($env:CLOUDFLARE_API_TOKEN)
if (-not $TokenPresent) {
    $TokenPresent = -not [string]::IsNullOrWhiteSpace($env:CF_API_TOKEN)
}

$Python = Resolve-Python
$Args = @()
$Args += $Python.Prefix
$Args += @(
    $Planner,
    '--public-host', $PublicHost,
    '--admin-host', $AdminHost,
    '--zone-host', $AdminHost,
    '--target-host', $AdminHost,
    '--tunnel-id', $TunnelId,
    '--account-id', $AccountId,
    '--origin-url', $OriginUrl,
    '--output', $ManifestPath
)

if (-not $PlanOnly) {
    $Args += @('--apply', '--apply-tunnel-config')
}
if ($ForceIpv4) {
    $Args += '--force-ipv4'
}
if ($ReplaceConflictingRecords) {
    $Args += '--replace-conflicting-records'
}

Write-Step ("Gerando manifesto para {0}, {1} e workspaces *.admin" -f $PublicHost, $AdminHost)
& $Python.FilePath @Args
$ExitCode = $LASTEXITCODE

$Manifest = $null
if (Test-Path -LiteralPath $ManifestPath) {
    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    } catch {
        $Manifest = $null
    }
}

$Status = if ($PlanOnly) {
    'planned'
} elseif ($ExitCode -eq 0) {
    'applied'
} else {
    'blocked'
}

Save-Status @{
    status = $Status
    exit_code = $ExitCode
    token_present = $TokenPresent
    public_ipv4 = Get-PublicIp -Family 'ipv4'
    public_ipv6 = Get-PublicIp -Family 'ipv6'
    public_host = $PublicHost
    admin_host = $AdminHost
    tunnel_id = $TunnelId
    tunnel_target_host = "$TunnelId.cfargotunnel.com"
    origin_url = $OriginUrl
    manifest_path = $ManifestPath
    manifest_apply_status = if ($Manifest) { $Manifest.apply_status } else { '' }
    manifest_tunnel_apply_status = if ($Manifest) { $Manifest.tunnel_apply_status } else { '' }
    records_total = if ($Manifest) { $Manifest.records_total } else { 0 }
    blocked_reason = if ($ExitCode -eq 0 -or $PlanOnly) { '' } else { 'Cloudflare API recusou token, permissao, IP filter ou rate limit. Veja apply_error no manifesto sanitizado.' }
}

if ($ExitCode -ne 0 -and -not $PlanOnly) {
    Write-Step ("Bloqueado. Status sanitizado salvo em {0}" -f $StatusPath)
    exit $ExitCode
}

Write-Step ("Concluido. Status salvo em {0}" -f $StatusPath)
exit 0
