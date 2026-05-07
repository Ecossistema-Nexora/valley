param(
    [int]$ApiPort = 8085,
    [string]$PublicUrl = 'https://grilled-uncurrently-shaunta.ngrok-free.dev',
    [int]$NgrokApiPort = 4040,
    [switch]$InstallTask,
    [switch]$Watch,
    [switch]$ReplaceStale
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$EnvPath = Join-Path $RepoRoot '.env'
$ApiOutLog = Join-Path $RuntimeDir 'valley-product-api.win.out.log'
$ApiErrLog = Join-Path $RuntimeDir 'valley-product-api.win.err.log'
$NgrokOutLog = Join-Path $RuntimeDir 'valley-product-ngrok.win.out.log'
$NgrokErrLog = Join-Path $RuntimeDir 'valley-product-ngrok.win.err.log'
$CloudflareOutLog = Join-Path $RuntimeDir 'valley-product-cloudflare.out.log'
$CloudflareErrLog = Join-Path $RuntimeDir 'valley-product-cloudflare.err.log'
$ManifestPath = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$PublicationPath = Join-Path $RuntimeDir 'valley-product-web-publication.json'
$TaskName = 'ValleyProductPublicRuntime'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Output ("[valley-public] {0}" -f $Message)
}

function Import-LocalEnv {
    if (-not (Test-Path -LiteralPath $EnvPath)) {
        return
    }

    foreach ($RawLine in Get-Content -LiteralPath $EnvPath) {
        $Line = $RawLine.Trim()
        if (-not $Line -or $Line.StartsWith('#') -or -not $Line.Contains('=')) {
            continue
        }

        $Key, $Value = $Line.Split('=', 2)
        $Key = $Key.Trim()
        $Value = $Value.Trim().Trim('"').Trim("'")
        if ($Key -and [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Key, 'Process'))) {
            [Environment]::SetEnvironmentVariable($Key, $Value, 'Process')
        }
    }
}

function Resolve-Executable {
    param(
        [string[]]$Candidates,
        [string]$CommandName
    )

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }

    $Command = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        return $Command.Source
    }

    throw "Executavel nao encontrado: $CommandName"
}

function Test-ProductApi {
    param([string]$Url)

    try {
        $HealthUrl = $Url -replace '/api/product-shell$', '/healthz'
        $Response = Invoke-WebRequest `
            -UseBasicParsing `
            -Headers @{ 'ngrok-skip-browser-warning' = 'true' } `
            -Uri $HealthUrl `
            -TimeoutSec 30

        if ($Response.StatusCode -ne 200) {
            return $false
        }

        return $Response.Content.Contains('"status": "ok"') -and
            $Response.Content.Contains('"service": "valley-admin"')
    } catch {
        return $false
    }
}

function Stop-ProductApiIfNeeded {
    Get-CimInstance Win32_Process -Filter "name='python.exe'" |
        Where-Object {
            $_.CommandLine -like '*serve_valley_admin.py*' -and
            $_.CommandLine -like "*$ApiPort*"
        } |
        ForEach-Object {
            Write-Step ("Encerrando API antiga PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Stop-NgrokIfNeeded {
    param([string]$Domain)

    Get-CimInstance Win32_Process -Filter "name='ngrok.exe'" |
        Where-Object {
            $_.CommandLine -like "*$Domain*" -or
            $_.CommandLine -like "*:$ApiPort*"
        } |
        ForEach-Object {
            Write-Step ("Encerrando ngrok antigo PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Stop-CloudflareIfNeeded {
    Get-CimInstance Win32_Process -Filter "name='cloudflared.exe'" |
        Where-Object {
            $_.CommandLine -like "*127.0.0.1:$ApiPort*" -or
            $_.CommandLine -like "*http://127.0.0.1:$ApiPort*"
        } |
        ForEach-Object {
            Write-Step ("Encerrando cloudflared antigo PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Write-PublicationManifest {
    param(
        [string]$Provider,
        [string]$BaseUrl,
        [string]$ApiUrl,
        [bool]$Temporary,
        [string]$ProviderStatus
    )

    $Payload = [ordered]@{
        status = 'published'
        provider = $Provider
        public_url = $BaseUrl
        api_url = $ApiUrl
        generated_at = (Get-Date).ToString('o')
        temporary = $Temporary
        provider_status = $ProviderStatus
    }

    $Payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $PublicationPath -Encoding UTF8
}

function Write-RuntimeManifest {
    param(
        [string]$Provider,
        [string]$BaseUrl,
        [string]$PublicApiUrl,
        [string]$LocalUrl,
        [bool]$Temporary,
        [string]$ProviderStatus
    )

    $Manifest = [ordered]@{
        status = 'ok'
        service = 'valley-product-public'
        provider = $Provider
        public_url = $BaseUrl
        public_api_url = $PublicApiUrl
        local_api_url = $LocalUrl
        generated_at = (Get-Date).ToString('o')
        temporary = $Temporary
        provider_status = $ProviderStatus
        logs = @{
            api_stdout = $ApiOutLog
            api_stderr = $ApiErrLog
            ngrok_stdout = $NgrokOutLog
            ngrok_stderr = $NgrokErrLog
            cloudflare_stdout = $CloudflareOutLog
            cloudflare_stderr = $CloudflareErrLog
        }
    }

    $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
    Write-PublicationManifest `
        -Provider $Provider `
        -BaseUrl $BaseUrl `
        -ApiUrl $PublicApiUrl `
        -Temporary $Temporary `
        -ProviderStatus $ProviderStatus
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

function Ensure-LocalApi {
    param([string]$LocalUrl)

    if (Test-ProductApi -Url $LocalUrl) {
        Write-Step ("API local ja esta saudavel: {0}" -f $LocalUrl)
        return
    }

    if ($ReplaceStale) {
        Stop-ProductApiIfNeeded
    }

    Write-Step ("Subindo API em http://127.0.0.1:{0}" -f $ApiPort)
    Start-Process `
        -FilePath $script:Python `
        -ArgumentList @('scripts\serve_valley_admin.py', '--host', '127.0.0.1', '--port', $ApiPort.ToString()) `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $ApiOutLog `
        -RedirectStandardError $ApiErrLog `
        -WindowStyle Hidden

    $Deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Seconds 1
        if (Test-ProductApi -Url $LocalUrl) {
            return
        }
    } while ((Get-Date) -lt $Deadline)

    throw "API local indisponivel em $LocalUrl. Consulte $ApiErrLog"
}

function Try-StartNgrok {
    param(
        [string]$LocalUrl,
        [string]$PublicApiUrl
    )

    if (Test-ProductApi -Url $PublicApiUrl) {
        Write-Step ("API publica ngrok ja esta saudavel: {0}" -f $PublicApiUrl)
        Write-RuntimeManifest `
            -Provider 'ngrok_reserved_domain' `
            -BaseUrl $PublicUrl `
            -PublicApiUrl $PublicApiUrl `
            -LocalUrl $LocalUrl `
            -Temporary $false `
            -ProviderStatus 'healthy'
        return $true
    }

    if ($ReplaceStale) {
        Stop-NgrokIfNeeded -Domain $script:NgrokDomain
    }

    Write-Step ("Subindo ngrok {0} -> 127.0.0.1:{1}" -f $PublicUrl, $ApiPort)
    Start-Process `
        -FilePath $script:Ngrok `
        -ArgumentList @('http', '--url', $PublicUrl, "127.0.0.1:$ApiPort") `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $NgrokOutLog `
        -RedirectStandardError $NgrokErrLog `
        -WindowStyle Hidden

    $Deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Seconds 2
        if (Test-ProductApi -Url $PublicApiUrl) {
            Write-RuntimeManifest `
                -Provider 'ngrok_reserved_domain' `
                -BaseUrl $PublicUrl `
                -PublicApiUrl $PublicApiUrl `
                -LocalUrl $LocalUrl `
                -Temporary $false `
                -ProviderStatus 'healthy'
            Write-Step ("Runtime publico ativo via ngrok: {0}" -f $PublicApiUrl)
            return $true
        }
    } while ((Get-Date) -lt $Deadline)

    return $false
}

function Try-StartCloudflareQuickTunnel {
    param([string]$LocalUrl)

    if ($ReplaceStale) {
        Stop-CloudflareIfNeeded
    }

    $ExistingUrl = Get-CloudflareUrlFromLog -Path $CloudflareErrLog
    if ($ExistingUrl) {
        $ExistingApiUrl = "$ExistingUrl/api/product-shell"
        if (Test-ProductApi -Url $ExistingApiUrl) {
            Write-Step ("Quick tunnel Cloudflare ja esta saudavel: {0}" -f $ExistingApiUrl)
            Write-RuntimeManifest `
                -Provider 'cloudflare_quick_tunnel' `
                -BaseUrl $ExistingUrl `
                -PublicApiUrl $ExistingApiUrl `
                -LocalUrl $LocalUrl `
                -Temporary $true `
                -ProviderStatus 'healthy'
            return $true
        }
    }

    Write-Step ("Subindo Cloudflare Quick Tunnel -> 127.0.0.1:{0}" -f $ApiPort)
    Start-Process `
        -FilePath $script:Cloudflared `
        -ArgumentList @('tunnel', '--url', "http://127.0.0.1:$ApiPort") `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $CloudflareOutLog `
        -RedirectStandardError $CloudflareErrLog `
        -WindowStyle Hidden

    $Deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 2
        $BaseUrl = Get-CloudflareUrlFromLog -Path $CloudflareErrLog
        if (-not $BaseUrl) {
            $BaseUrl = Get-CloudflareUrlFromLog -Path $CloudflareOutLog
        }

        if ($BaseUrl) {
            $PublicApiUrl = "$BaseUrl/api/product-shell"
            if (Test-ProductApi -Url $PublicApiUrl) {
                Write-RuntimeManifest `
                    -Provider 'cloudflare_quick_tunnel' `
                    -BaseUrl $BaseUrl `
                    -PublicApiUrl $PublicApiUrl `
                    -LocalUrl $LocalUrl `
                    -Temporary $true `
                    -ProviderStatus 'healthy'
                Write-Step ("Runtime publico ativo via Cloudflare: {0}" -f $PublicApiUrl)
                return $true
            }
        }
    } while ((Get-Date) -lt $Deadline)

    return $false
}

function Start-ProductRuntime {
    $LocalUrl = "http://127.0.0.1:$ApiPort/api/product-shell"

    Ensure-LocalApi -LocalUrl $LocalUrl

    if (Try-StartCloudflareQuickTunnel -LocalUrl $LocalUrl) {
        return
    }

    $LocalhostRunScript = Join-Path $PSScriptRoot 'start_valley_localhost_run_public.ps1'
    if (Test-Path -LiteralPath $LocalhostRunScript -PathType Leaf) {
        Write-Step "Cloudflare indisponivel; acionando fallback persistente localhost.run."
        & powershell -NoProfile -ExecutionPolicy Bypass -File $LocalhostRunScript
        return
    }

    throw "Nenhum runtime publico disponivel. Consulte $CloudflareErrLog"
}

function Install-RuntimeTask {
    $Wrapper = Join-Path $PSScriptRoot 'watch_valley_product_public.cmd'
    if (-not (Test-Path -LiteralPath $Wrapper -PathType Leaf)) {
        throw "Wrapper de inicializacao nao encontrado: $Wrapper"
    }

    $TaskCommand = '"' + $Wrapper + '"'

    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $Result = & schtasks.exe /Create /F /SC ONLOGON /TN $TaskName /TR $TaskCommand 2>&1
        $TaskExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($TaskExitCode -eq 0) {
        Write-Step ("Tarefa agendada instalada via schtasks: {0}" -f $TaskName)
        return
    }

    $StartupDir = [Environment]::GetFolderPath('Startup')
    $StartupCommand = Join-Path $StartupDir 'ValleyProductPublicRuntime.cmd'
    $StartupContent = "@echo off`r`ncall `"$Wrapper`"`r`n"
    Set-Content -LiteralPath $StartupCommand -Value $StartupContent -Encoding ASCII -NoNewline

    Write-Step ("Sem permissao para schtasks; fallback instalado em: {0}" -f $StartupCommand)
}

Import-LocalEnv
$script:Python = Resolve-Executable `
    -CommandName 'python' `
    -Candidates @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe')
    )
$script:Ngrok = Resolve-Executable `
    -CommandName 'ngrok' `
    -Candidates @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe')
    )
$script:Cloudflared = Resolve-Executable `
    -CommandName 'cloudflared' `
    -Candidates @(
        'C:\Program Files (x86)\cloudflared\cloudflared.exe',
        'C:\Program Files\cloudflared\cloudflared.exe'
    )
$script:NgrokDomain = ([Uri]$PublicUrl).Host

if ($InstallTask) {
    Install-RuntimeTask
}

if ($Watch) {
    while ($true) {
        try {
            $Publication = $null
            if (Test-Path -LiteralPath $PublicationPath) {
                $Publication = Get-Content -Raw -LiteralPath $PublicationPath | ConvertFrom-Json
            }

            $PublishedApiUrl = if ($Publication -and $Publication.api_url) {
                [string]$Publication.api_url
            } else {
                "$PublicUrl/api/product-shell"
            }

            if (-not (Test-ProductApi -Url $PublishedApiUrl)) {
                Start-ProductRuntime
            }
        } catch {
            Write-Step ("Falha no watchdog: {0}" -f $_.Exception.Message)
        }
        Start-Sleep -Seconds 60
    }
}

Start-ProductRuntime
