param(
    [switch]$ForceCatalog,
    [switch]$SkipCatalog,
    [switch]$SkipCloudflare,
    [switch]$StartCloudflareAfterRepair,
    [switch]$SkipValidation,
    [switch]$SkipPlanosUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Net.Http

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$ConfigPath = Join-Path $RepoRoot 'config\valley_mvp_autonomous_closure.json'
$StatusPath = Join-Path $RuntimeDir 'valley-mvp-autonomous-closure.json'
$CatalogStatusPath = Join-Path $RuntimeDir 'valley-stock-catalog-10k-cycle.json'
$StockRuntimePath = Join-Path $RuntimeDir 'valley-stock-real-catalog.json'
$CloudflareRepairStatusPath = Join-Path $RuntimeDir 'valley-cloudflare-named-tunnel-repair.json'
$AdminPublicRuntimePath = Join-Path $RuntimeDir 'valley-admin-public-runtime.json'
$ProductPublicRuntimePath = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$EnvPath = Join-Path $RepoRoot '.env'
$CodexCloudEnvPath = Join-Path $RuntimeDir 'codex-cloud-secrets.env'
$TunnelTokenEnvPath = Join-Path $RuntimeDir 'valley-cloudflare-named-tunnel.env'

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Get-UtcIso {
    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Load-JsonObject {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][object]$Fallback
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $Fallback
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        return $Fallback
    }
}

function Save-JsonObject {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][object]$Payload
    )
    [System.IO.File]::WriteAllText(
        $Path,
        ($Payload | ConvertTo-Json -Depth 12),
        [System.Text.UTF8Encoding]::new($false)
    )
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
            if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Entry.Key, 'Process'))) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
            }
        }
    }
}

function Test-AnyEnv {
    param([string[]]$Names)
    foreach ($Name in $Names) {
        if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name, 'Process'))) {
            return $true
        }
    }
    return $false
}

function Get-StatusTimestamp {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    $Payload = Load-JsonObject -Path $Path -Fallback @{}
    foreach ($Key in @('generated_at_utc', 'generated_at', 'completed_at', 'finished_at_utc')) {
        if ($Payload.PSObject.Properties.Name -contains $Key) {
            $Raw = [string]$Payload.$Key
            if (-not [string]::IsNullOrWhiteSpace($Raw)) {
                try {
                    return [DateTimeOffset]::Parse($Raw).UtcDateTime
                } catch {
                    continue
                }
            }
        }
    }
    return $null
}

function Test-StepDue {
    param(
        [string]$StatusFile,
        [double]$MinIntervalHours
    )
    $Timestamp = Get-StatusTimestamp -Path $StatusFile
    if ($null -eq $Timestamp) {
        return $true
    }
    $AgeHours = ((Get-Date).ToUniversalTime() - $Timestamp).TotalHours
    return ($AgeHours -ge $MinIntervalHours)
}

function Invoke-ValleyProcess {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 7200
    )

    $StartedAt = Get-UtcIso
    $OutPath = Join-Path $RuntimeDir ("$Name.out.log")
    $ErrPath = Join-Path $RuntimeDir ("$Name.err.log")
    $Params = @{
        FilePath = $FilePath
        WorkingDirectory = $RepoRoot
        WindowStyle = 'Hidden'
        PassThru = $true
        RedirectStandardOutput = $OutPath
        RedirectStandardError = $ErrPath
    }
    if ($Arguments.Count -gt 0) {
        $Params.ArgumentList = $Arguments
    }

    $Process = Start-Process @Params
    $TimedOut = $false
    try {
        Wait-Process -Id $Process.Id -Timeout $TimeoutSeconds -ErrorAction Stop
    } catch {
        $TimedOut = $true
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
    $Process.Refresh()
    $ExitCode = $null
    if ($TimedOut) {
        $ExitCode = -1
    } else {
        try {
            $Process.WaitForExit()
            $ExitCode = $Process.ExitCode
        } catch {
            $ExitCode = $null
        }
        if ($null -eq $ExitCode) {
            $StillRunning = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
            $ExitCode = $(if ($null -eq $StillRunning) { 0 } else { -1 })
        }
    }
    return [ordered]@{
        name = $Name
        status = $(if ($ExitCode -eq 0) { 'ok' } else { 'failed' })
        exit_code = $ExitCode
        timed_out = $TimedOut
        timeout_seconds = $TimeoutSeconds
        started_at_utc = $StartedAt
        finished_at_utc = Get-UtcIso
        stdout_log = $OutPath
        stderr_log = $ErrPath
    }
}

function Test-HttpEndpoint {
    param(
        [string]$Name,
        [string]$BaseUrl,
        [string]$PathSuffix = '/healthz'
    )
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        return [ordered]@{
            name = $Name
            status = 'skipped'
            detail = 'base_url_empty'
        }
    }
    $Uri = $BaseUrl.TrimEnd('/') + $PathSuffix
    $Client = [System.Net.Http.HttpClient]::new()
    $Client.Timeout = [TimeSpan]::FromSeconds(45)
    try {
        $Response = $Client.GetAsync($Uri).GetAwaiter().GetResult()
        $Body = $Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $Response.IsSuccessStatusCode) {
            return [ordered]@{
                name = $Name
                status = 'blocked'
                url = $Uri
                http_status = [int]$Response.StatusCode
                body_preview = $Body.Substring(0, [Math]::Min(240, $Body.Length))
            }
        }
        return [ordered]@{
            name = $Name
            status = 'ok'
            url = $Uri
            http_status = [int]$Response.StatusCode
            body_preview = $Body.Substring(0, [Math]::Min(240, $Body.Length))
        }
    } catch {
        return [ordered]@{
            name = $Name
            status = 'blocked'
            url = $Uri
            error = $_.Exception.Message
        }
    } finally {
        $Client.Dispose()
    }
}

$ConfigFallback = [pscustomobject]@{
    safe_only = $true
    catalog = [pscustomobject]@{
        enabled = $true
        target_items = 10000
        min_interval_hours = 20
        max_categories = 200
        max_products_per_category = 100
        refresh_mercado = $false
    }
    cloudflare_named_tunnel = [pscustomobject]@{
        enabled = $true
        account_id = '474fc26bf9c6bcf5e1a84b7f63a516d8'
        tunnel_id = '80a75594-5129-469f-8cce-4a938ac48e06'
        tunnel_name = 'valley-admin'
        public_base_url = 'https://admin.brasildesconto.com.br'
        admin_port = 8085
        start_after_repair = $false
        accepted_token_env = @('CLOUDFLARE_API_TOKEN', 'CF_API_TOKEN')
    }
    validation = [pscustomobject]@{
        local_base_url = 'http://127.0.0.1:8085'
        tailscale_base_url = 'http://100.109.240.100:8085'
        fixed_domain = 'https://admin.brasildesconto.com.br'
    }
    planos = [pscustomobject]@{
        update_progress = $true
    }
}

$Config = Load-JsonObject -Path $ConfigPath -Fallback $ConfigFallback
$Steps = New-Object System.Collections.Generic.List[object]
$Blockers = New-Object System.Collections.Generic.List[object]
Import-ValleyEnv

try {
    if (-not $SkipCatalog -and [bool]$Config.catalog.enabled) {
        $TargetItems = [int]$Config.catalog.target_items
        $MinIntervalHours = [double]$Config.catalog.min_interval_hours
        $CatalogDue = $ForceCatalog -or (Test-StepDue -StatusFile $CatalogStatusPath -MinIntervalHours $MinIntervalHours)
        if ($CatalogDue) {
            $CatalogArgs = @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', 'scripts\run_stock_catalog_10k_cycle.ps1',
                '-TargetItems', [string]$TargetItems,
                '-MaxCategories', [string]([int]$Config.catalog.max_categories),
                '-MaxProductsPerCategory', [string]([int]$Config.catalog.max_products_per_category)
            )
            if ([bool]$Config.catalog.refresh_mercado) {
                $CatalogArgs += '-RefreshMercado'
            }
            $Steps.Add((Invoke-ValleyProcess -Name 'mvp_catalog_10k_cycle' -FilePath 'powershell.exe' -Arguments $CatalogArgs -TimeoutSeconds 7200))
        } else {
            $Steps.Add([ordered]@{
                name = 'mvp_catalog_10k_cycle'
                status = 'skipped'
                reason = 'min_interval_not_elapsed'
                status_path = $CatalogStatusPath
            })
        }
    } else {
        $Steps.Add([ordered]@{
            name = 'mvp_catalog_10k_cycle'
            status = 'skipped'
            reason = 'disabled_or_skipped'
        })
    }

    if (-not $SkipCloudflare -and [bool]$Config.cloudflare_named_tunnel.enabled) {
        $TokenEnvNames = @($Config.cloudflare_named_tunnel.accepted_token_env)
        $HasApiToken = Test-AnyEnv -Names $TokenEnvNames
        if ($HasApiToken) {
            $RepairArgs = @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', 'scripts\repair_valley_cloudflare_named_tunnel.ps1',
                '-AccountId', [string]$Config.cloudflare_named_tunnel.account_id,
                '-TunnelId', [string]$Config.cloudflare_named_tunnel.tunnel_id,
                '-TunnelName', [string]$Config.cloudflare_named_tunnel.tunnel_name,
                '-PublicBaseUrl', [string]$Config.cloudflare_named_tunnel.public_base_url,
                '-AdminPort', [string]([int]$Config.cloudflare_named_tunnel.admin_port)
            )
            if ($StartCloudflareAfterRepair -or [bool]$Config.cloudflare_named_tunnel.start_after_repair) {
                $RepairArgs += '-StartAfterRepair'
            }
            $Steps.Add((Invoke-ValleyProcess -Name 'mvp_cloudflare_named_tunnel_repair' -FilePath 'powershell.exe' -Arguments $RepairArgs -TimeoutSeconds 300))
        } else {
            $HasConnectorToken = Test-AnyEnv -Names @('CLOUDFLARED_TOKEN')
            $Blocker = [ordered]@{
                name = 'mvp_cloudflare_named_tunnel_repair'
                status = 'blocked'
                reason = 'missing_cloudflare_api_token'
                required_env = $TokenEnvNames
                connector_token_present = $HasConnectorToken
                repair_status_path = $CloudflareRepairStatusPath
                dashboard_path = 'Zero Trust > Networks > Tunnels > valley-admin > Add a replica > copy token'
            }
            $Steps.Add($Blocker)
            $Blockers.Add($Blocker)
        }
    } else {
        $Steps.Add([ordered]@{
            name = 'mvp_cloudflare_named_tunnel_repair'
            status = 'skipped'
            reason = 'disabled_or_skipped'
        })
    }

    if (-not $SkipValidation) {
        $Steps.Add((Test-HttpEndpoint -Name 'local_runtime_health' -BaseUrl ([string]$Config.validation.local_base_url)))
        $Steps.Add((Test-HttpEndpoint -Name 'local_product_shell' -BaseUrl ([string]$Config.validation.local_base_url) -PathSuffix '/api/product-shell'))
        $Steps.Add((Test-HttpEndpoint -Name 'tailscale_runtime_health' -BaseUrl ([string]$Config.validation.tailscale_base_url)))
        $Steps.Add((Test-HttpEndpoint -Name 'tailscale_product_shell' -BaseUrl ([string]$Config.validation.tailscale_base_url) -PathSuffix '/api/product-shell'))
        $AdminPublicManifest = Load-JsonObject -Path $AdminPublicRuntimePath -Fallback @{}
        $ProductPublicManifest = Load-JsonObject -Path $ProductPublicRuntimePath -Fallback @{}
        $AdminProvider = ''
        $AdminPublicUrl = ''
        $ProductPublicUrl = ''
        $RequiresTailscale = $false
        if ($AdminPublicManifest.PSObject.Properties.Name -contains 'provider') {
            $AdminProvider = [string]$AdminPublicManifest.provider
        }
        if ($AdminPublicManifest.PSObject.Properties.Name -contains 'public_url') {
            $AdminPublicUrl = [string]$AdminPublicManifest.public_url
        }
        if ($ProductPublicManifest.PSObject.Properties.Name -contains 'public_url') {
            $ProductPublicUrl = [string]$ProductPublicManifest.public_url
        }
        if ($AdminPublicManifest.PSObject.Properties.Name -contains 'requires_tailscale') {
            $RequiresTailscale = [bool]$AdminPublicManifest.requires_tailscale
        }
        $Steps.Add([ordered]@{
            name = 'persistent_public_fallback'
            status = if (
                ($AdminPublicManifest.PSObject.Properties.Name -contains 'provider_status') -and
                ($ProductPublicManifest.PSObject.Properties.Name -contains 'provider_status') -and
                [string]$AdminPublicManifest.provider_status -eq 'healthy' -and
                [string]$ProductPublicManifest.provider_status -eq 'healthy'
            ) { 'ok' } else { 'blocked' }
            provider = $AdminProvider
            admin_url = $AdminPublicUrl
            product_url = $ProductPublicUrl
            requires_tailscale = $RequiresTailscale
        })
        $FixedDomainStep = Test-HttpEndpoint -Name 'fixed_domain_health' -BaseUrl ([string]$Config.validation.fixed_domain)
        $Steps.Add($FixedDomainStep)
        if ($FixedDomainStep.status -ne 'ok') {
            $FixedDomainError = ''
            if ($FixedDomainStep.Contains('error')) {
                $FixedDomainError = [string]$FixedDomainStep.error
            } elseif ($FixedDomainStep.Contains('body_preview')) {
                $FixedDomainError = [string]$FixedDomainStep.body_preview
            }
            $Blockers.Add([ordered]@{
                name = 'fixed_domain_health'
                status = 'blocked'
                reason = 'fixed_domain_not_demonstrable'
                url = $FixedDomainStep.url
                error = $FixedDomainError
            })
        }
    }

    if (-not $SkipPlanosUpdate -and [bool]$Config.planos.update_progress) {
        $Steps.Add((Invoke-ValleyProcess -Name 'planos_progress_update' -FilePath 'python' -Arguments @('scripts\update_planos_progress.py') -TimeoutSeconds 120))
    }
} catch {
    $Steps.Add([ordered]@{
        name = 'mvp_autonomous_closure'
        status = 'failed'
        error = $_.Exception.Message
    })
}

$FailedCount = @($Steps | Where-Object { $_.status -eq 'failed' }).Count
$BlockedCount = @($Steps | Where-Object { $_.status -eq 'blocked' }).Count
$OverallStatus = if ($FailedCount -gt 0) {
    'failed'
} elseif ($BlockedCount -gt 0) {
    'blocked'
} else {
    'ok'
}

$StockPayload = Load-JsonObject -Path $StockRuntimePath -Fallback @{}
$CatalogItemsTotal = 0
if ($StockPayload.PSObject.Properties.Name -contains 'items_total') {
    $CatalogItemsTotal = [int]$StockPayload.items_total
}
$TargetItemsConfigured = [int]$Config.catalog.target_items
$ItemsRemainingToTarget = $TargetItemsConfigured - $CatalogItemsTotal
if ($ItemsRemainingToTarget -lt 0) {
    $ItemsRemainingToTarget = 0
}
$StatusPayload = New-Object 'System.Collections.Specialized.OrderedDictionary'
$StatusPayload['status'] = [string]$OverallStatus
$StatusPayload['service'] = 'valley-mvp-autonomous-closure'
$StatusPayload['generated_at_utc'] = (Get-UtcIso)
$StatusPayload['safe_only'] = [bool]$Config.safe_only
$StatusPayload['catalog_items_total'] = $CatalogItemsTotal
$StatusPayload['target_items'] = $TargetItemsConfigured
$StatusPayload['items_remaining_to_target'] = $ItemsRemainingToTarget
$StatusPayload['config_path'] = 'config/valley_mvp_autonomous_closure.json'
$StatusPayload['status_path'] = 'tmp/runtime/valley-mvp-autonomous-closure.json'
$StatusPayload['blockers'] = $Blockers.ToArray()
$StatusPayload['steps'] = $Steps.ToArray()

Save-JsonObject -Path $StatusPath -Payload $StatusPayload
$StatusPayload | ConvertTo-Json -Depth 12
