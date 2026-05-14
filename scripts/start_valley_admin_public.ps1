# PROPOSITO: Automatizar start valley admin public no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_valley_admin_public.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [string]$BindHost = '127.0.0.1',
    [int]$AdminPort = 8085,
    [string]$CloudflaredToken = '',
    [string]$PublicBaseUrl = '',
    [string]$PublicProductUrl = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$RuntimeManifest = Join-Path $RuntimeDir 'valley-admin-public-runtime.json'
$HttpStartupManifest = Join-Path $RuntimeDir 'valley-admin-http-startup.json'
$ProductRuntimeManifest = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$ProductPublicationManifest = Join-Path $RuntimeDir 'valley-product-web-publication.json'
$ServeScript = Join-Path $RepoRoot 'scripts\serve_valley_admin.py'
$AdminRoot = Join-Path $RepoRoot 'admin'
$AdminData = Join-Path $AdminRoot 'valley_admin_data.json'
$EnvExamplePath = Join-Path $RepoRoot '.env.example'
$ReleaseEnvExamplePath = Join-Path $RepoRoot 'config\VALLEY_RELEASE_ENV.example'
$EnvPath = Join-Path $RepoRoot '.env'
$CodexCloudEnvPath = Join-Path $RuntimeDir 'codex-cloud-secrets.env'
$TunnelTokenEnvPath = Join-Path $RuntimeDir 'valley-cloudflare-named-tunnel.env'
$ServeStdoutLog = Join-Path $RuntimeDir 'valley-admin-http.live.out.log'
$ServeStderrLog = Join-Path $RuntimeDir 'valley-admin-http.live.err.log'
$CloudflareStdoutLog = Join-Path $RuntimeDir 'valley-admin-cloudflare.live.out.log'
$CloudflareStderrLog = Join-Path $RuntimeDir 'valley-admin-cloudflare.live.err.log'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ("[valley-admin-public] {0}" -f $Message)
}

function Prepare-LogPath {
    param([string]$Path)

    $Directory = Split-Path -Parent $Path
    if ($Directory) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    try {
        [System.IO.File]::WriteAllText($Path, '', [System.Text.UTF8Encoding]::new($false))
        return $Path
    } catch {
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $Extension = [System.IO.Path]::GetExtension($Path)
        $Suffix = Get-Date -Format 'yyyyMMdd-HHmmss'
        $FallbackPath = Join-Path $Directory ("{0}.{1}{2}" -f $BaseName, $Suffix, $Extension)
        [System.IO.File]::WriteAllText($FallbackPath, '', [System.Text.UTF8Encoding]::new($false))
        Write-Step ("Log bloqueado em {0}; usando {1}" -f $Path, $FallbackPath)
        return $FallbackPath
    }
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
        $Key = $Key.Trim()
        $Value = $Value.Trim().Trim('"').Trim("'")
        if ($Key) {
            $Values[$Key] = $Value
        }
    }

    return $Values
}

function Import-ValleyEnv {
    param(
        [string[]]$Paths,
        [string[]]$OverrideKeys = @()
    )

    foreach ($Path in $Paths) {
        foreach ($Entry in (Parse-EnvFile -Path $Path).GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($Entry.Value)) {
                continue
            }

            $CurrentValue = [Environment]::GetEnvironmentVariable($Entry.Key, 'Process')
            $ShouldOverride = $OverrideKeys -contains $Entry.Key
            if ([string]::IsNullOrWhiteSpace($CurrentValue) -or $ShouldOverride) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
            }
        }
    }
}

function Resolve-PythonLauncher {
    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($PythonCommand) {
        return @{
            FilePath = $PythonCommand.Source
            PrefixArgs = @()
        }
    }

    $PyLauncher = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($PyLauncher) {
        return @{
            FilePath = $PyLauncher.Source
            PrefixArgs = @('-3')
        }
    }

    throw 'Python nao encontrado no PATH.'
}

function Resolve-CommandSource {
    param(
        [string]$Name,
        [string]$InstallHint,
        [string[]]$Candidates = @()
    )

    $Command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        return $Command.Source
    }

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }

    if (-not $Command) {
        throw ("{0} nao encontrado no PATH.`n{1}" -f $Name, $InstallHint)
    }
}

function Test-JsonEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = 5
    )

    try {
        return Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
    } catch {
        return $null
    }
}

function Wait-JsonEndpoint {
    param(
        [string]$Url,
        [int]$Attempts = 20,
        [int]$DelayMs = 1000
    )

    for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
        $Payload = Test-JsonEndpoint -Url $Url
        if ($Payload) {
            return $Payload
        }

        Start-Sleep -Milliseconds $DelayMs
    }

    return $null
}

function Test-AdminHealth {
    param([string]$BaseUrl)

    $Health = Test-JsonEndpoint -Url ("{0}/healthz" -f $BaseUrl.TrimEnd('/'))
    return $Health -and $Health.status -eq 'ok' -and $Health.service -eq 'valley-admin'
}

function Get-ListeningPidsForPort {
    param([int]$Port)

    $Pattern = '^\s*TCP\s+\S+:' + [regex]::Escape($Port.ToString()) + '\s+\S+\s+LISTENING\s+(\d+)\s*$'
    $Lines = netstat -ano -p TCP | Select-String -Pattern $Pattern
    $Pids = @()

    foreach ($Line in $Lines) {
        $Match = [regex]::Match($Line.Line, $Pattern)
        if ($Match.Success) {
            $Pids += [int]$Match.Groups[1].Value
        }
    }

    return @($Pids | Sort-Object -Unique)
}

function Get-ProcessSummary {
    param([int]$ProcessId)

    try {
        $Process = Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $ProcessId)
        if ($Process) {
            return ("PID={0} CMD={1}" -f $Process.ProcessId, $Process.CommandLine)
        }
    } catch {
    }

    return ("PID={0}" -f $ProcessId)
}

function Stop-StaleCloudflared {
    Get-CimInstance Win32_Process -Filter "name='cloudflared.exe'" |
        Where-Object {
            $_.CommandLine -like "*http://127.0.0.1:$AdminPort*" -or
            $_.CommandLine -like "*$CloudflaredToken*" -or
            $_.CommandLine -like "*tunnel run*"
        } |
        ForEach-Object {
            Write-Step ("Encerrando cloudflared antigo PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Get-CloudflareUrlFromLog {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $Matches = Select-String -LiteralPath $Path -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -AllMatches
    if (-not $Matches) {
        return $null
    }

    $LastLine = $Matches | Select-Object -Last 1
    $Match = [regex]::Match($LastLine.Line, 'https://[a-z0-9-]+\.trycloudflare\.com')
    if ($Match.Success) {
        return $Match.Value
    }

    return $null
}

function Write-RuntimeManifest {
    param(
        [string]$Provider,
        [string]$PublicUrl,
        [string]$LocalUrl,
        [bool]$Temporary,
        [string]$Permanence,
        [string]$ProviderStatus,
        [string]$Mode
    )

    $BaseUrl = $PublicUrl.TrimEnd('/')
    $Payload = [ordered]@{
        status = 'ok'
        service = 'valley-admin-public'
        provider = $Provider
        public_url = $BaseUrl
        local_url = $LocalUrl
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        temporary = $Temporary
        permanence = $Permanence
        provider_status = $ProviderStatus
        smoke_endpoints = @{
            healthz = "$BaseUrl/healthz"
            admin_data = "$BaseUrl/api/admin-data"
        }
        logs = @{
            http_stdout = $ServeStdoutLog
            http_stderr = $ServeStderrLog
            cloudflare_stdout = $CloudflareStdoutLog
            cloudflare_stderr = $CloudflareStderrLog
        }
        cloudflare = @{
            mode = $Mode
            token_present = -not [string]::IsNullOrWhiteSpace($CloudflaredToken)
        }
    }

    if ($Mode -eq 'named' -and $PublicBaseUrl) {
        $Payload.cloudflare['configured_public_url'] = $PublicBaseUrl.TrimEnd('/')
    }

    $Json = $Payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($RuntimeManifest, $Json, [System.Text.UTF8Encoding]::new($false))
}

function Write-ProductManifests {
    param(
        [string]$Provider,
        [string]$PublicUrl,
        [string]$LocalUrl,
        [bool]$Temporary,
        [string]$ProviderStatus
    )

    $BaseUrl = $PublicUrl.TrimEnd('/')
    $ProductBaseUrl = if (-not [string]::IsNullOrWhiteSpace($PublicProductUrl)) {
        $PublicProductUrl.TrimEnd('/')
    } elseif ($BaseUrl -match '^https://admin\.brasildesconto\.com\.br/?$') {
        'https://brasildesconto.com.br'
    } else {
        "$BaseUrl/product"
    }
    $ProductApiUrl = if ($ProductBaseUrl -match '^https://brasildesconto\.com\.br/?$') {
        "$ProductBaseUrl/api/product-shell"
    } else {
        "$BaseUrl/api/product-shell"
    }
    $LocalApiUrl = "$LocalUrl/api/product-shell"

    $RuntimePayload = [ordered]@{
        status = 'ok'
        service = 'valley-product-public'
        provider = $Provider
        public_url = $ProductBaseUrl
        public_api_url = $ProductApiUrl
        local_api_url = $LocalApiUrl
        generated_at = (Get-Date).ToString('o')
        temporary = $Temporary
        provider_status = $ProviderStatus
        logs = @{
            admin_http_stdout = $ServeStdoutLog
            admin_http_stderr = $ServeStderrLog
            cloudflare_stdout = $CloudflareStdoutLog
            cloudflare_stderr = $CloudflareStderrLog
        }
    }

    $PublicationPayload = [ordered]@{
        status = 'published'
        provider = $Provider
        public_url = $ProductBaseUrl
        api_url = $ProductApiUrl
        generated_at = (Get-Date).ToString('o')
        temporary = $Temporary
        provider_status = $ProviderStatus
    }

    [System.IO.File]::WriteAllText(
        $ProductRuntimeManifest,
        ($RuntimePayload | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $ProductPublicationManifest,
        ($PublicationPayload | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false)
    )
}

Import-ValleyEnv `
    -Paths @($EnvExamplePath, $ReleaseEnvExamplePath, $EnvPath, $CodexCloudEnvPath, $TunnelTokenEnvPath) `
    -OverrideKeys @(
        'CLOUDFLARED_TOKEN',
        'VALLEY_ADMIN_PUBLIC_URL',
        'VALLEY_CLOUDFLARE_PUBLIC_URL',
        'VALLEY_PRODUCT_PUBLIC_URL'
    )

if (-not $PSBoundParameters.ContainsKey('CloudflaredToken')) {
    $CloudflaredToken = $env:CLOUDFLARED_TOKEN
}

if (-not $PSBoundParameters.ContainsKey('PublicBaseUrl')) {
    if ($env:VALLEY_ADMIN_PUBLIC_URL) {
        $PublicBaseUrl = $env:VALLEY_ADMIN_PUBLIC_URL
    } elseif ($env:VALLEY_CLOUDFLARE_PUBLIC_URL) {
        $PublicBaseUrl = $env:VALLEY_CLOUDFLARE_PUBLIC_URL
    } elseif ($env:VALLEY_TERMIUS_CLOUDFLARE_HOST) {
        $PublicBaseUrl = 'https://{0}' -f $env:VALLEY_TERMIUS_CLOUDFLARE_HOST.Trim().Trim('/')
    }
}

if (-not $PSBoundParameters.ContainsKey('PublicProductUrl') -and $env:VALLEY_PRODUCT_PUBLIC_URL) {
    $PublicProductUrl = $env:VALLEY_PRODUCT_PUBLIC_URL
}

if (-not (Test-Path -LiteralPath $ServeScript)) {
    throw "Script do servidor nao encontrado: $ServeScript"
}

if (-not (Test-Path -LiteralPath $AdminRoot)) {
    throw "Diretorio admin nao encontrado: $AdminRoot"
}

$PythonLauncher = Resolve-PythonLauncher
$Cloudflared = Resolve-CommandSource `
    -Name 'cloudflared' `
    -InstallHint "Instale o cloudflared e mantenha a CLI no PATH." `
    -Candidates @(
        'C:\Program Files (x86)\cloudflared\cloudflared.exe',
        'C:\Program Files\cloudflared\cloudflared.exe',
        'C:\Windows\System32\cloudflared.exe'
    )
$LocalBaseUrl = 'http://{0}:{1}' -f $BindHost, $AdminPort
$LocalHealthUrl = '{0}/healthz' -f $LocalBaseUrl

Write-Step ("Python: {0}" -f $PythonLauncher.FilePath)
Write-Step ("cloudflared: {0}" -f $Cloudflared)

$HealthPayload = Test-JsonEndpoint -Url $LocalHealthUrl
if (-not ($HealthPayload -and $HealthPayload.service -eq 'valley-admin')) {
    $ExistingListeners = @(Get-ListeningPidsForPort -Port $AdminPort)
    if ($ExistingListeners.Count -gt 0) {
        $ListenerSummary = @($ExistingListeners | ForEach-Object { Get-ProcessSummary -ProcessId $_ }) -join [Environment]::NewLine
        throw "A porta $AdminPort ja esta ocupada por outro listener.`n$ListenerSummary"
    }

    Write-Step ("Subindo servidor HTTP local em {0}" -f $LocalBaseUrl)
    $ServeStdoutLog = Prepare-LogPath -Path $ServeStdoutLog
    $ServeStderrLog = Prepare-LogPath -Path $ServeStderrLog

    $ServeArgs = @()
    $ServeArgs += $PythonLauncher.PrefixArgs
    $ServeArgs += @(
        '-u',
        $ServeScript,
        '--host', $BindHost,
        '--port', $AdminPort.ToString(),
        '--root', $AdminRoot,
        '--data', $AdminData,
        '--startup-file', $HttpStartupManifest
    )

    Start-Process -FilePath $PythonLauncher.FilePath -ArgumentList $ServeArgs -WorkingDirectory $RepoRoot -RedirectStandardOutput $ServeStdoutLog -RedirectStandardError $ServeStderrLog -WindowStyle Hidden | Out-Null
    $HealthPayload = Wait-JsonEndpoint -Url $LocalHealthUrl -Attempts 30 -DelayMs 1000
    if (-not ($HealthPayload -and $HealthPayload.service -eq 'valley-admin')) {
        throw "Servidor local nao respondeu em $LocalHealthUrl"
    }
}

Stop-StaleCloudflared
$CloudflareStdoutLog = Prepare-LogPath -Path $CloudflareStdoutLog
$CloudflareStderrLog = Prepare-LogPath -Path $CloudflareStderrLog

if (-not [string]::IsNullOrWhiteSpace($CloudflaredToken) -and -not [string]::IsNullOrWhiteSpace($PublicBaseUrl)) {
    Write-Step ("Subindo Cloudflare named tunnel para {0}" -f $PublicBaseUrl)
    Start-Process `
        -FilePath $Cloudflared `
        -ArgumentList @('tunnel', 'run', '--token', $CloudflaredToken) `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $CloudflareStdoutLog `
        -RedirectStandardError $CloudflareStderrLog `
        -WindowStyle Hidden | Out-Null

    $Deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 2
        if (Test-AdminHealth -BaseUrl $PublicBaseUrl) {
            Write-RuntimeManifest -Provider 'cloudflare_named_tunnel' -PublicUrl $PublicBaseUrl -LocalUrl $LocalBaseUrl -Temporary $false -Permanence 'fixed_external' -ProviderStatus 'healthy' -Mode 'named'
            Write-ProductManifests -Provider 'cloudflare_named_tunnel' -PublicUrl $PublicBaseUrl -LocalUrl $LocalBaseUrl -Temporary $false -ProviderStatus 'healthy'
            Write-Step ("Admin publico ativo via Cloudflare named tunnel: {0}" -f $PublicBaseUrl)
            exit 0
        }
    } while ((Get-Date) -lt $Deadline)

    Write-Step ("Cloudflare named tunnel indisponivel em {0}; tentando Quick Tunnel." -f $PublicBaseUrl)
}

Write-Step ("Subindo Cloudflare Quick Tunnel -> {0}" -f $LocalBaseUrl)
Start-Process `
    -FilePath $Cloudflared `
    -ArgumentList @('tunnel', '--url', $LocalBaseUrl) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $CloudflareStdoutLog `
    -RedirectStandardError $CloudflareStderrLog `
    -WindowStyle Hidden | Out-Null

$QuickTunnelUrl = $null
$Deadline = (Get-Date).AddSeconds(60)
do {
    Start-Sleep -Seconds 2
    $QuickTunnelUrl = Get-CloudflareUrlFromLog -Path $CloudflareStderrLog
    if (-not $QuickTunnelUrl) {
        $QuickTunnelUrl = Get-CloudflareUrlFromLog -Path $CloudflareStdoutLog
    }

    if ($QuickTunnelUrl -and (Test-AdminHealth -BaseUrl $QuickTunnelUrl)) {
        Write-RuntimeManifest -Provider 'cloudflare_quick_tunnel' -PublicUrl $QuickTunnelUrl -LocalUrl $LocalBaseUrl -Temporary $true -Permanence 'ephemeral_external' -ProviderStatus 'healthy' -Mode 'quick'
        Write-ProductManifests -Provider 'cloudflare_quick_tunnel' -PublicUrl $QuickTunnelUrl -LocalUrl $LocalBaseUrl -Temporary $true -ProviderStatus 'healthy'
        Write-Step ("Admin publico ativo via Cloudflare Quick Tunnel: {0}" -f $QuickTunnelUrl)
        exit 0
    }
} while ((Get-Date) -lt $Deadline)

throw 'Cloudflare Quick Tunnel nao ficou saudavel dentro do tempo limite.'
