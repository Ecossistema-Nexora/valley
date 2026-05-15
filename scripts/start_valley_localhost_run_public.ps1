# PROPOSITO: Automatizar start valley localhost run public no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_valley_localhost_run_public.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
    [int]$ApiPort = 8085,
    [switch]$InstallTask,
    [switch]$ReplaceStale
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$AdminRuntimeManifest = Join-Path $RuntimeDir 'valley-admin-public-runtime.json'
$ProductRuntimeManifest = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$ProductPublicationManifest = Join-Path $RuntimeDir 'valley-product-web-publication.json'
$StartupStatusPath = Join-Path $RuntimeDir 'valley-localhost-run-status.json'
$ApiOutLog = Join-Path $RuntimeDir 'valley-product-api.win.out.log'
$ApiErrLog = Join-Path $RuntimeDir 'valley-product-api.win.err.log'
$TunnelOutLog = Join-Path $RuntimeDir 'valley-localhost-run.out.log'
$TunnelErrLog = Join-Path $RuntimeDir 'valley-localhost-run.err.log'
$ServeScript = Join-Path $RepoRoot 'scripts\serve_valley_admin.py'
$TaskName = 'ValleyLocalhostRunPublicRuntime'
$StartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'ValleyLocalhostRunPublicRuntime.vbs'
$HiddenProcessScript = Join-Path $PSScriptRoot 'valley_hidden_process.ps1'
$HiddenTaskRunner = Join-Path $PSScriptRoot 'valley_hidden_task_runner.vbs'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

if (Test-Path -LiteralPath $HiddenProcessScript -PathType Leaf) {
    . $HiddenProcessScript
} else {
    throw "Launcher oculto nao encontrado: $HiddenProcessScript"
}

function Write-Step {
    param([string]$Message)
    Write-Host ("[valley-localhost-run] {0}" -f $Message)
}

function Resolve-CommandPath {
    param(
        [string]$Name,
        [string[]]$Candidates = @()
    )

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }

    $Command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        return $Command.Source
    }

    throw ("Comando nao encontrado: {0}" -f $Name)
}

function Test-ValleyApi {
    param([string]$BaseUrl)

    try {
        $Health = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Uri ("{0}/healthz" -f $BaseUrl.TrimEnd('/'))
        if ($Health.StatusCode -ne 200 -or -not $Health.Content.Contains('"service": "valley-admin"')) {
            return $false
        }
        $Shell = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri ("{0}/api/product-shell" -f $BaseUrl.TrimEnd('/'))
        return $Shell.StatusCode -eq 200 -and $Shell.Content.Contains('"service": "valley-product"')
    } catch {
        return $false
    }
}

function Stop-StaleValleyApi {
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

function Stop-StaleLocalhostRun {
    Get-CimInstance Win32_Process |
        Where-Object {
            ($_.Name -in @('ssh.exe', 'ssh')) -and
            $_.CommandLine -like '*localhost.run*' -and
            (
                $_.CommandLine -like "*localhost:$ApiPort*" -or
                $_.CommandLine -like "*127.0.0.1:$ApiPort*"
            )
        } |
        ForEach-Object {
            Write-Step ("Encerrando localhost.run antigo PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Ensure-LocalApi {
    param([string]$Python)

    $LocalBaseUrl = "http://127.0.0.1:$ApiPort"
    if (Test-ValleyApi -BaseUrl $LocalBaseUrl) {
        Write-Step ("API local saudavel: {0}" -f $LocalBaseUrl)
        return
    }

    if ($ReplaceStale) {
        Stop-StaleValleyApi
    }

    Write-Step ("Subindo API local em {0}" -f $LocalBaseUrl)
    Set-Content -LiteralPath $ApiOutLog -Value '' -Encoding UTF8
    Set-Content -LiteralPath $ApiErrLog -Value '' -Encoding UTF8
    Start-ValleyHiddenProcess `
        -FilePath $Python `
        -ArgumentList @('-u', $ServeScript, '--host', '127.0.0.1', '--port', $ApiPort.ToString()) `
        -WorkingDirectory $RepoRoot `
        -StdoutLog $ApiOutLog `
        -StderrLog $ApiErrLog | Out-Null

    $Deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 1
        if (Test-ValleyApi -BaseUrl $LocalBaseUrl) {
            return
        }
    } while ((Get-Date) -lt $Deadline)

    throw ("API local nao ficou saudavel em {0}. Consulte {1}" -f $LocalBaseUrl, $ApiErrLog)
}

function Get-LocalhostRunUrl {
    foreach ($Path in @($TunnelOutLog, $TunnelErrLog)) {
        if (-not (Test-Path -LiteralPath $Path)) {
            continue
        }
        $Matches = Select-String -LiteralPath $Path -Pattern 'https://[a-zA-Z0-9.-]+\.(localhost\.run|lhr\.life)' -AllMatches
        if ($Matches) {
            $Line = ($Matches | Select-Object -Last 1).Line
            $Match = [regex]::Match($Line, 'https://[a-zA-Z0-9.-]+\.(localhost\.run|lhr\.life)')
            if ($Match.Success) {
                return $Match.Value.TrimEnd('/')
            }
        }
    }
    return ''
}

function Write-ValleyPublicManifests {
    param([string]$PublicBaseUrl)

    $BaseUrl = $PublicBaseUrl.TrimEnd('/')
    $ProductBaseUrl = "$BaseUrl/product"
    $ProductApiUrl = "$BaseUrl/api/product-shell"
    $LocalBaseUrl = "http://127.0.0.1:$ApiPort"
    $LocalApiUrl = "$LocalBaseUrl/api/product-shell"
    $GeneratedAt = (Get-Date).ToString('o')

    $AdminPayload = [ordered]@{
        status = 'ok'
        service = 'valley-admin-public'
        provider = 'localhost_run'
        public_url = $BaseUrl
        local_url = $LocalBaseUrl
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        temporary = $true
        permanence = 'persistent_localhost_run_watchdog'
        provider_status = 'healthy'
        smoke_endpoints = @{
            healthz = "$BaseUrl/healthz"
            admin_data = "$BaseUrl/api/admin-data"
        }
        logs = @{
            api_stdout = $ApiOutLog
            api_stderr = $ApiErrLog
            tunnel_stdout = $TunnelOutLog
            tunnel_stderr = $TunnelErrLog
        }
    }

    $RuntimePayload = [ordered]@{
        status = 'ok'
        service = 'valley-product-public'
        provider = 'localhost_run'
        public_url = $ProductBaseUrl
        public_api_url = $ProductApiUrl
        local_api_url = $LocalApiUrl
        generated_at = $GeneratedAt
        temporary = $true
        provider_status = 'healthy'
        persistence = 'Windows Scheduled Task watchdog via localhost.run'
        logs = @{
            api_stdout = $ApiOutLog
            api_stderr = $ApiErrLog
            tunnel_stdout = $TunnelOutLog
            tunnel_stderr = $TunnelErrLog
        }
    }

    $PublicationPayload = [ordered]@{
        status = 'published'
        provider = 'localhost_run'
        public_url = $ProductBaseUrl
        api_url = $ProductApiUrl
        generated_at = $GeneratedAt
        temporary = $true
        provider_status = 'healthy'
        persistence = 'Windows Scheduled Task watchdog via localhost.run'
    }

    $StatusPayload = [ordered]@{
        status = 'ok'
        provider = 'localhost_run'
        public_url = $BaseUrl
        product_url = $ProductBaseUrl
        api_url = $ProductApiUrl
        local_url = $LocalBaseUrl
        generated_at = $GeneratedAt
        task_name = $TaskName
        startup_shortcut = $StartupShortcut
    }

    $AdminPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $AdminRuntimeManifest -Encoding UTF8
    $RuntimePayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ProductRuntimeManifest -Encoding UTF8
    $PublicationPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ProductPublicationManifest -Encoding UTF8
    $StatusPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StartupStatusPath -Encoding UTF8
}

function Start-LocalhostRunTunnel {
    param([string]$Ssh)

    if ($ReplaceStale) {
        Stop-StaleLocalhostRun
    }

    $ExistingUrl = Get-LocalhostRunUrl
    if ($ExistingUrl -and (Test-ValleyApi -BaseUrl $ExistingUrl)) {
        Write-Step ("localhost.run ja saudavel: {0}" -f $ExistingUrl)
        Write-ValleyPublicManifests -PublicBaseUrl $ExistingUrl
        return $ExistingUrl
    }

    Set-Content -LiteralPath $TunnelOutLog -Value '' -Encoding UTF8
    Set-Content -LiteralPath $TunnelErrLog -Value '' -Encoding UTF8
    Write-Step ("Subindo localhost.run -> localhost:{0}" -f $ApiPort)
    Start-ValleyHiddenProcess `
        -FilePath $Ssh `
        -ArgumentList @(
            '-o', 'ServerAliveInterval=30',
            '-o', 'ServerAliveCountMax=3',
            '-o', 'StrictHostKeyChecking=accept-new',
            '-R', ("80:127.0.0.1:{0}" -f $ApiPort),
            'nokey@localhost.run'
        ) `
        -WorkingDirectory $RepoRoot `
        -StdoutLog $TunnelOutLog `
        -StderrLog $TunnelErrLog | Out-Null

    $Deadline = (Get-Date).AddSeconds(75)
    do {
        Start-Sleep -Seconds 2
        $PublicUrl = Get-LocalhostRunUrl
        if ($PublicUrl -and (Test-ValleyApi -BaseUrl $PublicUrl)) {
            Write-Step ("Runtime publico ativo via localhost.run: {0}" -f $PublicUrl)
            Write-ValleyPublicManifests -PublicBaseUrl $PublicUrl
            return $PublicUrl
        }
    } while ((Get-Date) -lt $Deadline)

    throw ("localhost.run nao ficou saudavel. Consulte {0} e {1}" -f $TunnelOutLog, $TunnelErrLog)
}

function Install-RuntimeTask {
    try {
        $CommandLine = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '" -ReplaceStale'
        $Execute = if (Test-Path -LiteralPath $HiddenTaskRunner -PathType Leaf) { Join-Path $env:WINDIR 'System32\wscript.exe' } else { 'powershell.exe' }
        $Arguments = if (Test-Path -LiteralPath $HiddenTaskRunner -PathType Leaf) {
            '"' + $HiddenTaskRunner + '" "' + $RepoRoot + '" "' + $CommandLine + '"'
        } else {
            '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '" -ReplaceStale'
        }
        $Action = New-ScheduledTaskAction `
            -Execute $Execute `
            -Argument $Arguments
        $Trigger = New-ScheduledTaskTrigger -AtLogOn
        $Settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -RestartCount 999 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -Hidden
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Action `
            -Trigger $Trigger `
            -Settings $Settings `
            -Description 'Mantem o runtime publico Valley via localhost.run sem ngrok.' `
            -Force | Out-Null
        Write-Step ("Scheduled Task persistente instalado: {0}" -f $TaskName)
        return
    } catch {
        Write-Step ("Scheduled Task indisponivel neste usuario: {0}" -f $_.Exception.Message)
    }

    $StartupCommand = 'CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $PSCommandPath.Replace('"', '""') + '"" -ReplaceStale", 0, False' + [Environment]::NewLine
    Set-Content -LiteralPath $StartupShortcut -Value $StartupCommand -Encoding ASCII
    Write-Step ("Fallback persistente instalado no Startup: {0}" -f $StartupShortcut)
}

$Python = Resolve-CommandPath -Name 'python'
$Ssh = Resolve-CommandPath -Name 'ssh' -Candidates @('C:\Windows\System32\OpenSSH\ssh.exe')

Ensure-LocalApi -Python $Python
$Url = Start-LocalhostRunTunnel -Ssh $Ssh
if ($InstallTask) {
    Install-RuntimeTask
}

Write-Step ("URL publica Valley: {0}/product" -f $Url.TrimEnd('/'))
