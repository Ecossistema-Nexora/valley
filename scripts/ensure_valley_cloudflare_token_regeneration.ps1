<#
PROPOSITO: Regenerar e aplicar automaticamente o token do Cloudflare named tunnel Valley.

CONTEXTO: O release Android/Web depende do dominio fixo admin.brasildesconto.com.br.
Quando o token de replica do cloudflared expira ou e revogado, este script tenta
obter um novo token pela API Cloudflare ou pelo certificado local do cloudflared.

REGRAS: Nao imprime segredos, nao usa ngrok, grava token somente em tmp/runtime
e bloqueia o APK ate healthz, product e api/product-shell passarem pelo Cloudflare.
#>

param(
    [string]$AccountId = '',
    [string]$TunnelId = '80a75594-5129-469f-8cce-4a938ac48e06',
    [string]$TunnelName = 'valley-admin',
    [string]$PublicBaseUrl = 'https://admin.brasildesconto.com.br',
    [int]$AdminPort = 8085,
    [switch]$StartAfterRefresh,
    [switch]$PersistUserEnv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-cloudflare-token-regeneration-status.json'
$ReleaseBlockerPath = Join-Path $RuntimeDir 'valley-cloudflare-release-blocker.json'
$TokenEnvPath = Join-Path $RuntimeDir 'valley-cloudflare-named-tunnel.env'
$AdminPublicScript = Join-Path $RepoRoot 'scripts\start_valley_admin_public.ps1'
$ReleaseGatePath = Join-Path $RuntimeDir 'valley-release-runtime-gate.json'
$EnvPaths = @(
    (Join-Path $RepoRoot '.env.example'),
    (Join-Path $RepoRoot 'config\VALLEY_RELEASE_ENV.example'),
    (Join-Path $RepoRoot '.env'),
    (Join-Path $RuntimeDir 'codex-cloud-secrets.env'),
    $TokenEnvPath
)

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ("[valley-cloudflare-token] {0}" -f $Message)
}

function Parse-EnvFile {
    param([string]$Path)

    $Values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $Values
    }

    foreach ($RawLine in Get-Content -LiteralPath $Path) {
        $Line = $RawLine.Trim()
        if (-not $Line -or $Line.StartsWith('#') -or -not $Line.Contains('=')) {
            continue
        }

        $Key, $Value = $Line.Split('=', 2)
        $Key = $Key.Trim()
        $Value = $Value.Trim().Trim('"').Trim("'")
        if ($Key) {
            $Values[$Key] = $Value
        }
    }
    return $Values
}

function Import-ValleyEnv {
    foreach ($Path in $EnvPaths) {
        foreach ($Entry in (Parse-EnvFile -Path $Path).GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($Entry.Value)) {
                continue
            }

            $Current = [Environment]::GetEnvironmentVariable($Entry.Key, 'Process')
            $ShouldOverride = @(
                'CLOUDFLARED_TOKEN',
                'VALLEY_ADMIN_PUBLIC_URL',
                'VALLEY_CLOUDFLARE_PUBLIC_URL',
                'VALLEY_PRODUCT_PUBLIC_URL'
            ) -contains $Entry.Key
            if ([string]::IsNullOrWhiteSpace($Current) -or $ShouldOverride) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
            }
        }
    }
}

function Get-EnvAnyScope {
    param([string[]]$Keys)

    foreach ($Key in $Keys) {
        foreach ($Scope in @('Process', 'User', 'Machine')) {
            $Value = [Environment]::GetEnvironmentVariable($Key, $Scope)
            if (-not [string]::IsNullOrWhiteSpace($Value)) {
                return $Value
            }
        }
    }
    return ''
}

function New-SecretFingerprint {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [ordered]@{ present = $false; length = 0; sha256_prefix = '' }
    }
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $Hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($Bytes)
    return [ordered]@{
        present = $true
        length = $Value.Length
        sha256_prefix = ([System.BitConverter]::ToString($Hash).Replace('-', '').Substring(0, 12))
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        [hashtable]$Payload
    )

    $Payload.generated_at = (Get-Date).ToString('o')
    [System.IO.File]::WriteAllText(
        $Path,
        ($Payload | ConvertTo-Json -Depth 10),
        [System.Text.UTF8Encoding]::new($false)
    )
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

function Get-OriginCertPath {
    $EnvCert = Get-EnvAnyScope -Keys @('TUNNEL_ORIGIN_CERT')
    if (-not [string]::IsNullOrWhiteSpace($EnvCert) -and (Test-Path -LiteralPath $EnvCert -PathType Leaf)) {
        return $EnvCert
    }

    foreach ($Candidate in @(
        (Join-Path $HOME '.cloudflared\cert.pem'),
        (Join-Path $HOME '.cloudflare-warp\cert.pem'),
        (Join-Path $HOME 'cloudflare-warp\cert.pem')
    )) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return $Candidate
        }
    }
    return ''
}

function Invoke-CloudflareApi {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $ApiToken = Get-EnvAnyScope -Keys @('CLOUDFLARE_API_TOKEN', 'CF_API_TOKEN')
    if ([string]::IsNullOrWhiteSpace($ApiToken)) {
        throw 'CLOUDFLARE_API_TOKEN/CF_API_TOKEN ausente.'
    }

    return Invoke-RestMethod `
        -Method $Method `
        -Uri "https://api.cloudflare.com/client/v4$Path" `
        -Headers @{ Authorization = "Bearer $ApiToken"; 'Content-Type' = 'application/json' } `
        -TimeoutSec 45
}

function Save-TunnelToken {
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Token) -or $Token.Length -lt 40) {
        throw 'Token Cloudflare vazio ou curto demais.'
    }

    @(
        '# Gerado localmente. Nao versionar.',
        '# Usado pelo release gate Valley Cloudflare.',
        "CLOUDFLARED_TOKEN=$Token",
        "VALLEY_ADMIN_PUBLIC_URL=$PublicBaseUrl",
        "VALLEY_CLOUDFLARE_PUBLIC_URL=$PublicBaseUrl"
    ) | Set-Content -LiteralPath $TokenEnvPath -Encoding ASCII

    [Environment]::SetEnvironmentVariable('CLOUDFLARED_TOKEN', $Token, 'Process')
    [Environment]::SetEnvironmentVariable('VALLEY_ADMIN_PUBLIC_URL', $PublicBaseUrl, 'Process')
    if ($PersistUserEnv) {
        [Environment]::SetEnvironmentVariable('CLOUDFLARED_TOKEN', $Token, 'User')
        [Environment]::SetEnvironmentVariable('VALLEY_ADMIN_PUBLIC_URL', $PublicBaseUrl, 'User')
    }

    Write-JsonFile -Path $StatusPath -Payload @{
        status = 'token_refreshed'
        source = $Source
        account_id = $AccountId
        tunnel_id = $TunnelId
        tunnel_name = $TunnelName
        public_url = $PublicBaseUrl
        token_env_path = $TokenEnvPath
        token = New-SecretFingerprint -Value $Token
        persisted_user_env = [bool]$PersistUserEnv
    }
}

function Get-TokenFromApi {
    Write-Step 'Consultando Cloudflare API para token do named tunnel.'
    $Tunnel = Invoke-CloudflareApi -Method GET -Path "/accounts/$AccountId/cfd_tunnel/$TunnelId"
    if (-not $Tunnel.success) {
        throw 'Cloudflare API recusou consulta do tunnel.'
    }

    $TokenResponse = Invoke-CloudflareApi -Method GET -Path "/accounts/$AccountId/cfd_tunnel/$TunnelId/token"
    $Token = [string]$TokenResponse.result
    if ([string]::IsNullOrWhiteSpace($Token)) {
        throw 'Cloudflare API retornou token vazio.'
    }
    return $Token
}

function Get-TokenFromOriginCert {
    param([string]$Cloudflared)

    $OriginCert = Get-OriginCertPath
    if ([string]::IsNullOrWhiteSpace($OriginCert)) {
        return ''
    }

    Write-Step 'Tentando emitir token com certificado local cloudflared.'
    $Output = & $Cloudflared tunnel token $TunnelName --origincert $OriginCert 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("cloudflared tunnel token falhou: {0}" -f (($Output | Select-Object -First 1) -join ' '))
    }

    foreach ($Line in @($Output)) {
        $Candidate = ([string]$Line).Trim()
        if ($Candidate.Length -gt 40 -and $Candidate -notmatch '\s') {
            return $Candidate
        }
    }
    return ''
}

function Test-ReleaseUrls {
    $Base = $PublicBaseUrl.TrimEnd('/')
    $Checks = [ordered]@{}
    foreach ($Item in @(
        @{ name = 'healthz'; url = "$Base/healthz"; needle = '"service": "valley-admin"' },
        @{ name = 'product'; url = "$Base/product"; needle = 'flutter_bootstrap.js' },
        @{ name = 'product_shell'; url = "$Base/api/product-shell"; needle = '"service": "valley-product"' }
    )) {
        try {
            $Response = Invoke-WebRequest -UseBasicParsing -Uri $Item.url -TimeoutSec 25
            $Checks[$Item.name] = ($Response.StatusCode -eq 200 -and $Response.Content.Contains($Item.needle))
        } catch {
            $Checks[$Item.name] = $false
        }
    }
    return [pscustomobject]@{
        ok = -not ($Checks.Values -contains $false)
        checks = $Checks
    }
}

Import-ValleyEnv

if ([string]::IsNullOrWhiteSpace($AccountId)) {
    $AccountId = Get-EnvAnyScope -Keys @('CLOUDFLARE_ACCOUNT_ID', 'CF_ACCOUNT_ID')
}
if ([string]::IsNullOrWhiteSpace($AccountId)) {
    $AccountId = '474fc26bf9c6bcf5e1a84b7f63a516d8'
}

$Cloudflared = Resolve-Cloudflared
$ExistingReplicaToken = Get-EnvAnyScope -Keys @('CLOUDFLARED_TOKEN')
$ApiToken = Get-EnvAnyScope -Keys @('CLOUDFLARE_API_TOKEN', 'CF_API_TOKEN')
$OriginCert = Get-OriginCertPath

try {
    $NewToken = ''
    $Source = ''

    if (-not [string]::IsNullOrWhiteSpace($ApiToken)) {
        $NewToken = Get-TokenFromApi
        $Source = 'cloudflare_api'
    } elseif (-not [string]::IsNullOrWhiteSpace($OriginCert)) {
        $NewToken = Get-TokenFromOriginCert -Cloudflared $Cloudflared
        $Source = 'cloudflared_origin_cert'
    } else {
        Write-JsonFile -Path $StatusPath -Payload @{
            status = 'blocked'
            reason = 'missing_cloudflare_api_token_or_origin_cert'
            account_id = $AccountId
            tunnel_id = $TunnelId
            tunnel_name = $TunnelName
            public_url = $PublicBaseUrl
            credentials = @{
                api_token = New-SecretFingerprint -Value $ApiToken
                existing_replica_token = New-SecretFingerprint -Value $ExistingReplicaToken
                origin_cert_present = $false
                cloudflared = $Cloudflared
            }
            required = 'CLOUDFLARE_API_TOKEN/CF_API_TOKEN com Cloudflare Tunnel Write ou ~/.cloudflared/cert.pem autenticado.'
            next_action = 'A rotina agendada continuara tentando e aplicara o token automaticamente quando a credencial existir.'
        }
        Write-JsonFile -Path $ReleaseBlockerPath -Payload @{
            status = 'blocked'
            provider = 'cloudflare_required'
            ngrok = 'disabled'
            public_url = $PublicBaseUrl
            reasons = @(
                'Cloudflare named tunnel recusou o token atual com Invalid tunnel secret.',
                'CLOUDFLARE_API_TOKEN/CF_API_TOKEN ausente para regenerar token via API.',
                'Certificado local cloudflared ausente para emitir token via CLI.'
            )
            must_not_build_apk_until = 'healthz, product e api/product-shell passarem pelo Cloudflare no navegador.'
        }
        throw 'Regeneracao bloqueada: falta Cloudflare API token ou certificado local autenticado.'
    }

    Save-TunnelToken -Token $NewToken -Source $Source
    Write-Step 'Token renovado e salvo em tmp/runtime.'

    if ($StartAfterRefresh) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AdminPublicScript -BindHost 127.0.0.1 -AdminPort $AdminPort -PublicBaseUrl $PublicBaseUrl
        $Probe = Test-ReleaseUrls
        if ($Probe.ok) {
            Write-JsonFile -Path $ReleaseGatePath -Payload @{
                status = 'ok'
                public_url = $PublicBaseUrl
                details = @{ validated_by = $PSCommandPath; checks = $Probe.checks }
            }
            Write-Step 'Cloudflare validado nos endpoints de release.'
        } else {
            Write-JsonFile -Path $ReleaseGatePath -Payload @{
                status = 'blocked'
                public_url = $PublicBaseUrl
                details = @{ reason = 'post_refresh_probe_failed'; checks = $Probe.checks }
            }
            throw 'Token renovado, mas a validacao publica ainda falhou.'
        }
    }
} catch {
    if (-not (Test-Path -LiteralPath $StatusPath -PathType Leaf)) {
        Write-JsonFile -Path $StatusPath -Payload @{
            status = 'blocked'
            reason = $_.Exception.Message
            account_id = $AccountId
            tunnel_id = $TunnelId
            tunnel_name = $TunnelName
            public_url = $PublicBaseUrl
            credentials = @{
                api_token = New-SecretFingerprint -Value $ApiToken
                existing_replica_token = New-SecretFingerprint -Value $ExistingReplicaToken
                origin_cert_present = -not [string]::IsNullOrWhiteSpace($OriginCert)
            }
        }
    }
    throw
}
