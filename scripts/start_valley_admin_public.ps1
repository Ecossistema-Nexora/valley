param(
    [string]$BindHost = '127.0.0.1',
    [int]$AdminPort = 8080,
    [string]$ReservedDomain = '',
    [string]$NgrokAuthtoken = '',
    [string]$NgrokApiHost = '127.0.0.1',
    [int]$NgrokApiPort = 4040
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$RuntimePortSuffix = $AdminPort.ToString()
$ServeStdoutLog = Join-Path $RuntimeDir ("valley-admin-http.{0}.out.log" -f $RuntimePortSuffix)
$ServeStderrLog = Join-Path $RuntimeDir ("valley-admin-http.{0}.err.log" -f $RuntimePortSuffix)
$NgrokStdoutLog = Join-Path $RuntimeDir ("valley-admin-ngrok.{0}.out.log" -f $RuntimePortSuffix)
$NgrokStderrLog = Join-Path $RuntimeDir ("valley-admin-ngrok.{0}.err.log" -f $RuntimePortSuffix)
$NgrokConfigPath = Join-Path $RuntimeDir ("valley-admin-ngrok.{0}.runtime.yml" -f $RuntimePortSuffix)
$RuntimeManifest = Join-Path $RuntimeDir 'valley-admin-public-runtime.json'
$ServeScript = Join-Path $RepoRoot 'scripts\serve_valley_admin.py'
$AdminRoot = Join-Path $RepoRoot 'admin'
$AdminData = Join-Path $AdminRoot 'valley_admin_data.json'
$EnvExamplePath = Join-Path $RepoRoot '.env.example'
$ReleaseEnvExamplePath = Join-Path $RepoRoot 'config\VALLEY_RELEASE_ENV.example'
$EnvPath = Join-Path $RepoRoot '.env'
$NgrokGlobalConfig = Join-Path $env:LOCALAPPDATA 'ngrok\ngrok.yml'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Output ("[thor] {0}" -f $Message)
}

function Parse-EnvFile {
    param(
        [string]$Path
    )

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
        [string[]]$Paths
    )

    $LoadedSources = @{}

    foreach ($Path in $Paths) {
        foreach ($Entry in (Parse-EnvFile -Path $Path).GetEnumerator()) {
            $CurrentValue = [Environment]::GetEnvironmentVariable($Entry.Key, 'Process')
            $CanOverride = $LoadedSources.ContainsKey($Entry.Key)

            if ([string]::IsNullOrWhiteSpace($CurrentValue) -or $CanOverride) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
                $LoadedSources[$Entry.Key] = Split-Path -Leaf $Path
            }
        }
    }

    return $LoadedSources
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

    throw "Python nao encontrado no PATH. Instale Python 3.11+ antes de publicar o Valley Admin."
}

function Resolve-CommandSource {
    param(
        [string]$Name,
        [string]$InstallHint
    )

    $Command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $Command) {
        throw ("{0} nao encontrado no PATH.`n{1}" -f $Name, $InstallHint)
    }

    return $Command.Source
}

function Test-JsonEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = 3
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

function Get-FileTail {
    param(
        [string]$Path,
        [int]$Lines = 20
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return '[log inexistente]'
    }

    return ((Get-Content -LiteralPath $Path -Tail $Lines) -join [Environment]::NewLine)
}

function Get-ListeningPidsForPort {
    param(
        [int]$Port
    )

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
    param(
        [int]$ProcessId
    )

    try {
        $Process = Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $ProcessId)
        if ($Process) {
            return ("PID={0} CMD={1}" -f $Process.ProcessId, $Process.CommandLine)
        }
    } catch {
    }

    return ("PID={0}" -f $ProcessId)
}

function Stop-ProcessIfOwned {
    param(
        $ProcessObject
    )

    if (-not $ProcessObject) {
        return
    }

    try {
        if (-not $ProcessObject.HasExited) {
            Stop-Process -Id $ProcessObject.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
    }
}

function Get-TunnelForTarget {
    param(
        $Payload,
        [string]$TargetAddr
    )

    if (-not $Payload) {
        return $null
    }

    foreach ($Tunnel in @($Payload.tunnels)) {
        if ($Tunnel.config.addr -eq $TargetAddr) {
            return $Tunnel
        }
    }

    return $null
}

function Wait-NgrokTunnel {
    param(
        [string]$ApiUrl,
        [string]$TargetAddr,
        [int]$Attempts = 20,
        [int]$DelayMs = 1000
    )

    for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
        $Payload = Test-JsonEndpoint -Url $ApiUrl
        $Tunnel = Get-TunnelForTarget -Payload $Payload -TargetAddr $TargetAddr
        if ($Tunnel) {
            return @{
                Payload = $Payload
                Tunnel = $Tunnel
            }
        }

        Start-Sleep -Milliseconds $DelayMs
    }

    return $null
}

function Write-NgrokRuntimeConfig {
    param(
        [string]$Path,
        [string]$TargetAddr,
        [string]$ApiHost,
        [int]$ApiPort,
        [string]$ReservedDomain,
        [string]$Authtoken
    )

    $Lines = [System.Collections.Generic.List[string]]::new()
    $Lines.Add('version: "2"')

    if ($Authtoken) {
        $Lines.Add(("authtoken: {0}" -f $Authtoken))
    }

    $Lines.Add(("web_addr: {0}:{1}" -f $ApiHost, $ApiPort))
    $Lines.Add('tunnels:')
    $Lines.Add('  valley-admin:')
    $Lines.Add('    proto: http')
    $Lines.Add(("    addr: {0}" -f $TargetAddr))
    $Lines.Add('    inspect: true')

    if ($ReservedDomain) {
        $Lines.Add(("    domain: {0}" -f $ReservedDomain))
    }

    $Content = ($Lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-NgrokStartArgs {
    param(
        [string]$RuntimeConfigPath,
        [string]$GlobalConfigPath,
        [bool]$UseGlobalConfig
    )

    $Args = [System.Collections.Generic.List[string]]::new()
    $Args.Add('start')
    $Args.Add('valley-admin')

    if ($UseGlobalConfig) {
        $Args.Add('--config')
        $Args.Add($GlobalConfigPath)
    }

    $Args.Add('--config')
    $Args.Add($RuntimeConfigPath)
    $Args.Add('--log')
    $Args.Add('stdout')

    return @($Args)
}

function Write-RuntimeManifest {
    param(
        [hashtable]$Payload
    )

    $Json = $Payload | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($RuntimeManifest, $Json, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path -LiteralPath $ServeScript)) {
    throw "Script do servidor nao encontrado: $ServeScript"
}

if (-not (Test-Path -LiteralPath $AdminRoot)) {
    throw "Diretorio admin nao encontrado: $AdminRoot"
}

$EnvSources = Import-ValleyEnv -Paths @($EnvExamplePath, $ReleaseEnvExamplePath, $EnvPath)

if (-not $PSBoundParameters.ContainsKey('ReservedDomain') -and $env:VALLEY_NGROK_ADMIN_DOMAIN) {
    $ReservedDomain = $env:VALLEY_NGROK_ADMIN_DOMAIN
}

if (-not $PSBoundParameters.ContainsKey('NgrokAuthtoken')) {
    if ($env:VALLEY_NGROK_AUTHTOKEN) {
        $NgrokAuthtoken = $env:VALLEY_NGROK_AUTHTOKEN
    } elseif ($env:NGROK_AUTHTOKEN) {
        $NgrokAuthtoken = $env:NGROK_AUTHTOKEN
    }
}

$PythonLauncher = Resolve-PythonLauncher
$Ngrok = Resolve-CommandSource -Name 'ngrok' -InstallHint "Instale o ngrok e autentique a CLI. Exemplo: baixe em https://ngrok.com/download e rode 'ngrok config add-authtoken <TOKEN>'."
$LocalTarget = '{0}:{1}' -f $BindHost, $AdminPort
$LocalBaseUrl = 'http://{0}:{1}' -f $BindHost, $AdminPort
$LocalHealthUrl = '{0}/healthz' -f $LocalBaseUrl
$LocalDataUrl = '{0}/api/admin-data' -f $LocalBaseUrl
$NgrokVersion = (& $Ngrok version) 2>$null
$UseGlobalNgrokConfig = (-not $NgrokAuthtoken) -and (Test-Path -LiteralPath $NgrokGlobalConfig)
$NgrokAuthSource = 'missing'

if ($NgrokAuthtoken) {
    if ($env:VALLEY_NGROK_AUTHTOKEN -and $NgrokAuthtoken -eq $env:VALLEY_NGROK_AUTHTOKEN) {
        $NgrokAuthSource = if ($EnvSources.ContainsKey('VALLEY_NGROK_AUTHTOKEN')) { $EnvSources['VALLEY_NGROK_AUTHTOKEN'] } else { 'ambiente' }
    } elseif ($env:NGROK_AUTHTOKEN -and $NgrokAuthtoken -eq $env:NGROK_AUTHTOKEN) {
        $NgrokAuthSource = 'ambiente'
    } else {
        $NgrokAuthSource = 'parametro'
    }
} elseif ($UseGlobalNgrokConfig) {
    $NgrokAuthSource = 'ngrok global config'
}

Write-Step ("Python: {0}" -f $PythonLauncher.FilePath)
Write-Step ("ngrok: {0}" -f $NgrokVersion)
Write-Step ("Autenticacao ngrok: {0}" -f $NgrokAuthSource)

$HealthPayload = Test-JsonEndpoint -Url $LocalHealthUrl
$ServeProcess = $null
$ServeReused = $false

if ($HealthPayload -and $HealthPayload.service -eq 'valley-admin') {
    $ExistingListeners = @(Get-ListeningPidsForPort -Port $AdminPort)
    if ($HealthPayload.pid -and $ExistingListeners.Count -gt 1) {
        $UnexpectedListeners = @($ExistingListeners | Where-Object { $_ -ne [int]$HealthPayload.pid })
        if ($UnexpectedListeners.Count -gt 0) {
            $UnexpectedSummary = @($UnexpectedListeners | ForEach-Object { Get-ProcessSummary -ProcessId $_ }) -join [Environment]::NewLine
            throw "A porta $AdminPort ja responde como valley-admin, mas ha listeners concorrentes adicionais.`n$UnexpectedSummary"
        }
    }

    $ServeReused = $true
    Write-Step ("Servidor Valley Admin ja ativo em {0}; reutilizando instancia existente." -f $LocalBaseUrl)
} else {
    $ExistingListeners = @(Get-ListeningPidsForPort -Port $AdminPort)
    if ($ExistingListeners.Count -gt 0) {
        $ListenerSummary = @($ExistingListeners | ForEach-Object { Get-ProcessSummary -ProcessId $_ }) -join [Environment]::NewLine
        throw "A porta $AdminPort ja esta ocupada por outro listener e nao respondeu como valley-admin.`n$ListenerSummary`nEscolha outra porta ou encerre o processo conflitante."
    }

    Write-Step ("Subindo servidor HTTP local em {0}" -f $LocalBaseUrl)
    [System.IO.File]::WriteAllText($ServeStdoutLog, '', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($ServeStderrLog, '', [System.Text.UTF8Encoding]::new($false))

    $ServeArgs = @()
    $ServeArgs += $PythonLauncher.PrefixArgs
    $ServeArgs += @(
        '-u',
        $ServeScript,
        '--host', $BindHost,
        '--port', $AdminPort.ToString(),
        '--root', $AdminRoot,
        '--data', $AdminData,
        '--startup-file', $RuntimeManifest
    )

    $ServeProcess = Start-Process -FilePath $PythonLauncher.FilePath -ArgumentList $ServeArgs -WorkingDirectory $RepoRoot -RedirectStandardOutput $ServeStdoutLog -RedirectStandardError $ServeStderrLog -WindowStyle Hidden -PassThru

    $HealthPayload = Wait-JsonEndpoint -Url $LocalHealthUrl -Attempts 20 -DelayMs 1000
    if (-not $HealthPayload) {
        Stop-ProcessIfOwned -ProcessObject $ServeProcess
        $ServeStdoutTail = Get-FileTail -Path $ServeStdoutLog
        $ServeStderrTail = Get-FileTail -Path $ServeStderrLog
        throw "Servidor local nao respondeu em $LocalHealthUrl.`nSTDOUT:`n$ServeStdoutTail`nSTDERR:`n$ServeStderrTail"
    }

    if ($HealthPayload.service -ne 'valley-admin' -or -not $HealthPayload.pid -or [int]$HealthPayload.pid -ne [int]$ServeProcess.Id) {
        Stop-ProcessIfOwned -ProcessObject $ServeProcess
        throw "A porta $AdminPort respondeu, mas nao com o processo valley-admin recem-criado. PID esperado=$($ServeProcess.Id). Resposta recebida: $($HealthPayload | ConvertTo-Json -Depth 6 -Compress)"
    }
}

$ApiCandidates = @()
for ($Offset = 0; $Offset -le 10; $Offset++) {
    $ApiCandidates += ($NgrokApiPort + $Offset)
}

$SelectedApiPort = $null
$SelectedTunnel = $null
$NgrokProcess = $null
$NgrokReused = $false

foreach ($CandidatePort in $ApiCandidates) {
    $CandidateApiUrl = 'http://{0}:{1}/api/tunnels' -f $NgrokApiHost, $CandidatePort
    $Payload = Test-JsonEndpoint -Url $CandidateApiUrl
    $Tunnel = Get-TunnelForTarget -Payload $Payload -TargetAddr $LocalTarget
    if ($Tunnel) {
        $SelectedApiPort = $CandidatePort
        $SelectedTunnel = $Tunnel
        $NgrokReused = $true
        Write-Step ("Tunnel ngrok existente encontrado em {0}; reutilizando." -f $CandidateApiUrl)
        break
    }
}

if (-not $SelectedTunnel) {
    foreach ($CandidatePort in $ApiCandidates) {
        $CandidateApiUrl = 'http://{0}:{1}/api/tunnels' -f $NgrokApiHost, $CandidatePort
        $ExistingPayload = Test-JsonEndpoint -Url $CandidateApiUrl
        if ($ExistingPayload) {
            continue
        }

        [System.IO.File]::WriteAllText($NgrokStdoutLog, '', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($NgrokStderrLog, '', [System.Text.UTF8Encoding]::new($false))

        Write-NgrokRuntimeConfig -Path $NgrokConfigPath -TargetAddr $LocalTarget -ApiHost $NgrokApiHost -ApiPort $CandidatePort -ReservedDomain $ReservedDomain -Authtoken $NgrokAuthtoken
        $NgrokArgs = Get-NgrokStartArgs -RuntimeConfigPath $NgrokConfigPath -GlobalConfigPath $NgrokGlobalConfig -UseGlobalConfig $UseGlobalNgrokConfig

        Write-Step ("Subindo ngrok em API local {0}" -f $CandidateApiUrl)
        $NgrokProcess = Start-Process -FilePath $Ngrok -ArgumentList $NgrokArgs -WorkingDirectory $RepoRoot -RedirectStandardOutput $NgrokStdoutLog -RedirectStandardError $NgrokStderrLog -WindowStyle Hidden -PassThru

        $TunnelResult = Wait-NgrokTunnel -ApiUrl $CandidateApiUrl -TargetAddr $LocalTarget -Attempts 20 -DelayMs 1000
        if ($TunnelResult) {
            $SelectedApiPort = $CandidatePort
            $SelectedTunnel = $TunnelResult.Tunnel
            break
        }

        if ($NgrokProcess.HasExited) {
            Write-Step ("ngrok encerrou ao tentar usar API {0}; tentando proxima porta." -f $CandidateApiUrl)
        }
    }
}

if (-not $SelectedTunnel) {
    Stop-ProcessIfOwned -ProcessObject $NgrokProcess
    if (-not $ServeReused) {
        Stop-ProcessIfOwned -ProcessObject $ServeProcess
    }
    $NgrokStdoutTail = Get-FileTail -Path $NgrokStdoutLog
    $NgrokStderrTail = Get-FileTail -Path $NgrokStderrLog
    throw "Nao foi possivel obter um tunnel publico do ngrok para $LocalTarget.`nSTDOUT ngrok:`n$NgrokStdoutTail`nSTDERR ngrok:`n$NgrokStderrTail"
}

$SelectedApiUrl = 'http://{0}:{1}/api/tunnels' -f $NgrokApiHost, $SelectedApiPort
$Manifest = @{
    status = 'ready'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    local = @{
        host = $BindHost
        port = $AdminPort
        target = $LocalTarget
        base_url = $LocalBaseUrl
        health_url = $LocalHealthUrl
        data_url = $LocalDataUrl
    }
    ngrok = @{
        version = $NgrokVersion
        api_url = $SelectedApiUrl
        api_port = $SelectedApiPort
        reserved_domain = $(if ($ReservedDomain) { $ReservedDomain } else { $null })
        public_url = $SelectedTunnel.public_url
        inspect_url = $SelectedTunnel.inspect_url
        tunnel_name = $SelectedTunnel.name
        permanence = $(if ($ReservedDomain) { 'reserved-domain' } else { 'ephemeral' })
        auth_source = $NgrokAuthSource
    }
    files = @{
        runtime_manifest = $RuntimeManifest
        serve_log = $ServeStdoutLog
        serve_stdout_log = $ServeStdoutLog
        serve_stderr_log = $ServeStderrLog
        ngrok_log = $NgrokStdoutLog
        ngrok_stdout_log = $NgrokStdoutLog
        ngrok_stderr_log = $NgrokStderrLog
        ngrok_runtime_config = $NgrokConfigPath
        serve_script = $ServeScript
        admin_root = $AdminRoot
        admin_data = $AdminData
    }
    processes = @{
        serve = @{
            reused = $ServeReused
            pid = $(if ($ServeProcess) { $ServeProcess.Id } else { $null })
        }
        ngrok = @{
            reused = $NgrokReused
            pid = $(if ($NgrokProcess) { $NgrokProcess.Id } else { $null })
        }
    }
}

Write-RuntimeManifest -Payload $Manifest

Write-Output ("Valley Admin local: {0}" -f $LocalBaseUrl)
Write-Output ("Health local: {0}" -f $LocalHealthUrl)
Write-Output ("Payload local: {0}" -f $LocalDataUrl)
Write-Output ("ngrok publico: {0}" -f $SelectedTunnel.public_url)
Write-Output ("ngrok inspect: {0}" -f $SelectedTunnel.inspect_url)
Write-Output ("Manifesto runtime: {0}" -f $RuntimeManifest)
Write-Output ("Log HTTP stdout: {0}" -f $ServeStdoutLog)
Write-Output ("Log HTTP stderr: {0}" -f $ServeStderrLog)
Write-Output ("Log ngrok stdout: {0}" -f $NgrokStdoutLog)
Write-Output ("Log ngrok stderr: {0}" -f $NgrokStderrLog)
Write-Output "Use 'python scripts/show_valley_public_urls.py' para listar os endpoints publicos ativos."

if ($ReservedDomain) {
    Write-Output ("Dominio reservado confirmado: https://{0}" -f $ReservedDomain)
} else {
    Write-Output 'Sem dominio reservado. Defina VALLEY_NGROK_ADMIN_DOMAIN para obter URL publica permanente.'
}
