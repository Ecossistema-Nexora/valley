param(
    [int]$ApiPort = 8085,
    [string]$PublicUrl = 'https://admin.brasildesconto.com.br',
    [int]$ConsecutiveChecks = 3,
    [switch]$ReplaceStale,
    [switch]$InstallTask,
    [switch]$AllowNonCloudflareFallback,
    [switch]$AllowTemporaryCloudflare
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$ProductRuntimePath = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$AdminRuntimePath = Join-Path $RuntimeDir 'valley-admin-public-runtime.json'
$LocalhostRunStatusPath = Join-Path $RuntimeDir 'valley-localhost-run-status.json'
$ReleaseGateStatusPath = Join-Path $RuntimeDir 'valley-release-runtime-gate.json'
$EnsureProductPublicScript = Join-Path $PSScriptRoot 'ensure_valley_product_public.ps1'
$TaskName = 'ValleyReleaseRuntimeGate'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ("[valley-release-gate] {0}" -f $Message)
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Invoke-ValleyUrl {
    param([string]$Url)

    return Invoke-WebRequest `
        -UseBasicParsing `
        -Headers @{ 'ngrok-skip-browser-warning' = 'true' } `
        -Uri $Url `
        -TimeoutSec 30
}

function Test-ValleyUrl {
    param(
        [string]$Url,
        [string]$Needle
    )

    try {
        $Response = Invoke-ValleyUrl -Url $Url
        return $Response.StatusCode -eq 200 -and $Response.Content.Contains($Needle)
    } catch {
        return $false
    }
}

function Test-ValleyRuntime {
    param([string]$BaseUrl)

    $Base = $BaseUrl.TrimEnd('/')
    $Checks = [ordered]@{
        healthz = Test-ValleyUrl -Url "$Base/healthz" -Needle '"service": "valley-admin"'
        product = Test-ValleyUrl -Url "$Base/product" -Needle 'flutter_bootstrap.js'
        product_shell = Test-ValleyUrl -Url "$Base/api/product-shell" -Needle '"service": "valley-product"'
    }

    return [pscustomobject]@{
        ok = -not ($Checks.Values -contains $false)
        checks = $Checks
    }
}

function Get-BaseUrlFromProductRuntime {
    param($Runtime)

    $ApiUrl = [string]$Runtime.public_api_url
    if (-not [string]::IsNullOrWhiteSpace($ApiUrl) -and $ApiUrl.EndsWith('/api/product-shell')) {
        return $ApiUrl.Substring(0, $ApiUrl.Length - '/api/product-shell'.Length).TrimEnd('/')
    }

    $ProductUrl = [string]$Runtime.public_url
    if (-not [string]::IsNullOrWhiteSpace($ProductUrl) -and $ProductUrl.EndsWith('/product')) {
        return $ProductUrl.Substring(0, $ProductUrl.Length - '/product'.Length).TrimEnd('/')
    }

    return ''
}

function Write-ReleaseManifests {
    param(
        $ProductRuntime,
        [string]$BaseUrl
    )

    $Base = $BaseUrl.TrimEnd('/')
    $GeneratedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $Provider = [string]$ProductRuntime.provider
    $Temporary = [bool]$ProductRuntime.temporary
    $ProviderStatus = [string]$ProductRuntime.provider_status
    if ([string]::IsNullOrWhiteSpace($ProviderStatus)) {
        $ProviderStatus = 'healthy'
    }

    $AdminPayload = [ordered]@{
        status = 'ok'
        service = 'valley-admin-public'
        provider = $Provider
        public_url = $Base
        local_url = "http://127.0.0.1:$ApiPort"
        generated_at_utc = $GeneratedAt
        temporary = $Temporary
        permanence = if ($Temporary) { 'release_gate_validated_temporary' } else { 'release_gate_validated_persistent' }
        provider_status = $ProviderStatus
        smoke_endpoints = @{
            healthz = "$Base/healthz"
            admin_data = "$Base/api/admin-data"
        }
    }

    $StatusPayload = [ordered]@{
        status = 'ok'
        provider = $Provider
        public_url = $Base
        product_url = "$Base/product"
        api_url = "$Base/api/product-shell"
        local_url = "http://127.0.0.1:$ApiPort"
        generated_at = (Get-Date).ToString('o')
        task_name = $TaskName
        validated_by = 'scripts/ensure_valley_release_runtime.ps1'
    }

    $AdminPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $AdminRuntimePath -Encoding UTF8
    $StatusPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $LocalhostRunStatusPath -Encoding UTF8
}

function Write-GateStatus {
    param(
        [string]$Status,
        [string]$BaseUrl,
        [object]$Details
    )

    $Payload = [ordered]@{
        status = $Status
        public_url = $BaseUrl
        generated_at = (Get-Date).ToString('o')
        details = $Details
    }
    $Payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReleaseGateStatusPath -Encoding UTF8
    return $Payload
}

function Install-ReleaseGateTask {
    $Command = ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -ReplaceStale' -f $PSCommandPath)
    $Result = & schtasks.exe /Create /F /SC MINUTE /MO 5 /TN $TaskName /TR $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("Falha ao instalar tarefa agendada {0}: {1}" -f $TaskName, ($Result -join "`n"))
    }
    Write-Step ("Tarefa agendada instalada: {0}" -f $TaskName)
}

if ($InstallTask) {
    Install-ReleaseGateTask
}

if (-not (Test-Path -LiteralPath $EnsureProductPublicScript -PathType Leaf)) {
    throw "Script de runtime publico nao encontrado: $EnsureProductPublicScript"
}

$Args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $EnsureProductPublicScript, '-ApiPort', $ApiPort.ToString(), '-PublicUrl', $PublicUrl)
if ($ReplaceStale) {
    $Args += '-ReplaceStale'
}

Write-Step 'Garantindo runtime publico antes do release.'
$Result = Start-Process -FilePath 'powershell.exe' -ArgumentList $Args -WorkingDirectory $RepoRoot -Wait -PassThru -WindowStyle Hidden
if ($Result.ExitCode -ne 0) {
    $Status = Write-GateStatus -Status 'blocked' -BaseUrl '' -Details @{ reason = 'ensure_public_runtime_failed'; exit_code = $Result.ExitCode }
    throw ("Runtime publico bloqueado. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 6))
}

$ProductRuntime = Read-JsonFile -Path $ProductRuntimePath
if (-not $ProductRuntime) {
    $Status = Write-GateStatus -Status 'blocked' -BaseUrl '' -Details @{ reason = 'missing_product_runtime_manifest' }
    throw ("Manifesto de produto ausente. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 6))
}

if ([string]$ProductRuntime.provider -like 'ngrok*') {
    $Status = Write-GateStatus -Status 'blocked' -BaseUrl '' -Details @{
        reason = 'ngrok_disabled_for_release'
        provider = [string]$ProductRuntime.provider
    }
    throw ("Runtime publico bloqueado: ngrok esta desabilitado para release. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 6))
}

if (-not $AllowNonCloudflareFallback -and [string]$ProductRuntime.provider -notlike 'cloudflare*') {
    $Status = Write-GateStatus -Status 'blocked' -BaseUrl '' -Details @{
        reason = 'cloudflare_required_for_release'
        provider = [string]$ProductRuntime.provider
    }
    throw ("Runtime publico bloqueado: release exige Cloudflare. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 6))
}

if (-not $AllowTemporaryCloudflare -and [bool]$ProductRuntime.temporary) {
    $Status = Write-GateStatus -Status 'blocked' -BaseUrl '' -Details @{
        reason = 'temporary_cloudflare_not_allowed_for_apk'
        provider = [string]$ProductRuntime.provider
        public_url = [string]$ProductRuntime.public_url
        required = 'cloudflare_named_tunnel on fixed domain'
    }
    throw ("Runtime publico bloqueado: APK exige Cloudflare fixo, nao tunnel temporario. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 6))
}

$BaseUrl = Get-BaseUrlFromProductRuntime -Runtime $ProductRuntime
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $Status = Write-GateStatus -Status 'blocked' -BaseUrl '' -Details @{ reason = 'invalid_product_runtime_manifest'; runtime = $ProductRuntime }
    throw ("Manifesto de produto invalido. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 6))
}

$Evidence = @()
for ($Attempt = 1; $Attempt -le $ConsecutiveChecks; $Attempt++) {
    $Probe = Test-ValleyRuntime -BaseUrl $BaseUrl
    $Evidence += [ordered]@{
        attempt = $Attempt
        ok = [bool]$Probe.ok
        checks = $Probe.checks
    }
    if (-not $Probe.ok) {
        $Status = Write-GateStatus -Status 'blocked' -BaseUrl $BaseUrl -Details @{ reason = 'runtime_probe_failed'; evidence = $Evidence }
        throw ("Runtime publico falhou no gate. Status: {0}" -f ($Status | ConvertTo-Json -Compress -Depth 8))
    }
    Start-Sleep -Seconds 2
}

Write-ReleaseManifests -ProductRuntime $ProductRuntime -BaseUrl $BaseUrl
$OkStatus = Write-GateStatus -Status 'ok' -BaseUrl $BaseUrl -Details @{ evidence = $Evidence; product_runtime = $ProductRuntime }
Write-Step ("Runtime liberado para release: {0}" -f $BaseUrl)
Write-Output ($OkStatus | ConvertTo-Json -Depth 10)
