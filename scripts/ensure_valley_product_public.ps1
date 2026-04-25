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
$ApiOutLog = Join-Path $RuntimeDir 'valley-product-api.win.out.log'
$ApiErrLog = Join-Path $RuntimeDir 'valley-product-api.win.err.log'
$NgrokOutLog = Join-Path $RuntimeDir 'valley-product-ngrok.win.out.log'
$NgrokErrLog = Join-Path $RuntimeDir 'valley-product-ngrok.win.err.log'
$ManifestPath = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$TaskName = 'ValleyProductPublicRuntime'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Output ("[valley-public] {0}" -f $Message)
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

function Stop-StaleProductProcesses {
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

function Write-RuntimeManifest {
    param(
        [string]$LocalUrl,
        [string]$PublicApiUrl
    )

    $Manifest = [ordered]@{
        status = 'ok'
        service = 'valley-product-public'
        public_url = $PublicUrl
        public_api_url = $PublicApiUrl
        local_api_url = $LocalUrl
        generated_at = (Get-Date).ToString('o')
        logs = @{
            api_stdout = $ApiOutLog
            api_stderr = $ApiErrLog
            ngrok_stdout = $NgrokOutLog
            ngrok_stderr = $NgrokErrLog
        }
    }

    $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

function Start-ProductRuntime {
    $Python = Resolve-Executable `
        -CommandName 'python' `
        -Candidates @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe')
        )

    $Ngrok = Resolve-Executable `
        -CommandName 'ngrok' `
        -Candidates @(
            (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe')
        )

    $Domain = ([Uri]$PublicUrl).Host
    $LocalUrl = "http://127.0.0.1:$ApiPort/api/product-shell"
    $PublicApiUrl = "$PublicUrl/api/product-shell"

    if (Test-ProductApi -Url $LocalUrl) {
        Write-Step ("API local ja esta saudavel: {0}" -f $LocalUrl)
    } else {
        if ($ReplaceStale) {
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

        Write-Step ("Subindo API em http://127.0.0.1:{0}" -f $ApiPort)
        Start-Process `
            -FilePath $Python `
            -ArgumentList @('scripts\serve_valley_admin.py', '--host', '127.0.0.1', '--port', $ApiPort.ToString()) `
            -WorkingDirectory $RepoRoot `
            -RedirectStandardOutput $ApiOutLog `
            -RedirectStandardError $ApiErrLog `
            -WindowStyle Hidden

        $Deadline = (Get-Date).AddSeconds(30)
        do {
            Start-Sleep -Seconds 1
            if (Test-ProductApi -Url $LocalUrl) {
                break
            }
        } while ((Get-Date) -lt $Deadline)
    }

    if (-not (Test-ProductApi -Url $LocalUrl)) {
        throw "API local indisponivel em $LocalUrl. Consulte $ApiErrLog"
    }

    if (Test-ProductApi -Url $PublicApiUrl) {
        Write-Step ("API publica ja esta saudavel: {0}" -f $PublicApiUrl)
        Write-RuntimeManifest -LocalUrl $LocalUrl -PublicApiUrl $PublicApiUrl
        return
    }

    if ($ReplaceStale) {
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

    Write-Step ("Subindo ngrok {0} -> 127.0.0.1:{1}" -f $PublicUrl, $ApiPort)
    Start-Process `
        -FilePath $Ngrok `
        -ArgumentList @('http', '--url', $PublicUrl, "127.0.0.1:$ApiPort") `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $NgrokOutLog `
        -RedirectStandardError $NgrokErrLog `
        -WindowStyle Hidden

    $Deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 2
        if (Test-ProductApi -Url $PublicApiUrl) {
            break
        }
    } while ((Get-Date) -lt $Deadline)

    if (-not (Test-ProductApi -Url $PublicApiUrl)) {
        throw "API publica indisponivel em $PublicApiUrl. Consulte $NgrokErrLog"
    }

    Write-RuntimeManifest -LocalUrl $LocalUrl -PublicApiUrl $PublicApiUrl
    Write-Step ("Runtime publico ativo: {0}" -f $PublicApiUrl)
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

if ($InstallTask) {
    Install-RuntimeTask
}

if ($Watch) {
    while ($true) {
        try {
            if (-not (Test-ProductApi -Url "$PublicUrl/api/product-shell")) {
                Start-ProductRuntime
            }
        } catch {
            Write-Step ("Falha no watchdog: {0}" -f $_.Exception.Message)
        }
        Start-Sleep -Seconds 60
    }
}

Start-ProductRuntime
