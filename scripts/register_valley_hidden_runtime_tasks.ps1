# PROPOSITO: Regravar tarefas persistentes Valley para nao abrirem pop-ups de terminal no Windows.
# CONTEXTO: Scheduled Tasks que chamam powershell.exe/cmd.exe diretamente podem piscar ou abrir console.
# REGRAS: Usar wscript.exe + valley_hidden_task_runner.vbs, marcar Settings.Hidden=true e manter triggers existentes.

param(
    [switch]$WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-hidden-runtime-tasks.json'
$Runner = Join-Path $PSScriptRoot 'valley_hidden_task_runner.vbs'
$Wscript = Join-Path $env:WINDIR 'System32\wscript.exe'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $Runner -PathType Leaf)) {
    throw "Runner oculto nao encontrado: $Runner"
}
if (-not (Test-Path -LiteralPath $Wscript -PathType Leaf)) {
    throw "wscript.exe nao encontrado: $Wscript"
}

function ConvertTo-TaskQuotedArgument {
    param([AllowNull()][string]$Value)

    $Text = [string]$Value
    $Text = $Text -replace '\\+$', '$0$0'
    $Text = $Text -replace '"', '\"'
    return '"' + $Text + '"'
}

function New-HiddenRunnerArguments {
    param(
        [string]$WorkingDirectory,
        [string]$CommandLine
    )

    return @(
        (ConvertTo-TaskQuotedArgument $Runner),
        (ConvertTo-TaskQuotedArgument $WorkingDirectory),
        (ConvertTo-TaskQuotedArgument $CommandLine)
    ) -join ' '
}

function Get-TaskFolderAndName {
    param([string]$TaskPathOrName)

    $Normalized = $TaskPathOrName.Trim()
    if (-not $Normalized.StartsWith('\')) {
        $Normalized = '\' + $Normalized
    }
    $LastSlash = $Normalized.LastIndexOf('\')
    $FolderPath = if ($LastSlash -le 0) { '\' } else { $Normalized.Substring(0, $LastSlash) }
    $TaskName = $Normalized.Substring($LastSlash + 1)
    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        $FolderPath = '\'
    }
    return @{
        FolderPath = $FolderPath
        TaskName = $TaskName
    }
}

function Set-ValleyHiddenScheduledTask {
    param(
        [object]$ScheduleService,
        [string]$TaskPathOrName,
        [string]$WorkingDirectory,
        [string]$CommandLine
    )

    $Parts = Get-TaskFolderAndName -TaskPathOrName $TaskPathOrName
    $Folder = $ScheduleService.GetFolder($Parts.FolderPath)
    $Task = $Folder.GetTask($Parts.TaskName)
    $Definition = $Task.Definition

    $Definition.Settings.Hidden = $true
    $Definition.Settings.DisallowStartIfOnBatteries = $false
    $Definition.Settings.StopIfGoingOnBatteries = $false
    $Definition.Actions.Clear()

    $Action = $Definition.Actions.Create(0)
    $Action.Path = $Wscript
    $Action.Arguments = New-HiddenRunnerArguments -WorkingDirectory $WorkingDirectory -CommandLine $CommandLine
    $Action.WorkingDirectory = $WorkingDirectory

    if ($WhatIfOnly) {
        return @{
            task = $TaskPathOrName
            status = 'would_update'
            execute = $Action.Path
            arguments = $Action.Arguments
            working_directory = $WorkingDirectory
        }
    }

    $LogonType = $Definition.Principal.LogonType
    if (-not $LogonType) {
        $LogonType = 3
    }
    $Folder.RegisterTaskDefinition($Parts.TaskName, $Definition, 6, $null, $null, $LogonType, $null) | Out-Null
    return @{
        task = $TaskPathOrName
        status = 'updated'
        execute = $Action.Path
        arguments = $Action.Arguments
        hidden = $true
    }
}

$RepoRootText = [string]$RepoRoot
$CodexRoot = Split-Path -Parent $RepoRootText
$EnforceDockerScript = Join-Path $CodexRoot 'scripts\enforce_hyperv_wsl2_docker_at_logon.ps1'

$TaskSpecs = @(
    @{
        name = 'ValleyProductPublicRuntime'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\ensure_valley_product_public.ps1 -Watch -ReplaceStale"
    },
    @{
        name = 'ValleyReleaseRuntimeGate'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\ensure_valley_release_runtime.ps1 -ReplaceStale"
    },
    @{
        name = 'ValleyCommunicationBridge'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\start_valley_communication_bridge.ps1 -HiddenRuntime -IntervalSeconds 30"
    },
    @{
        name = 'ValleyGeminiRefactorLoop'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\run_valley_gemini_refactor_watchdog.ps1 -Command loop -BatchSize 5 -MaxCycles 1 -EngineMode checkpoint"
    },
    @{
        name = 'ValleyMvpAutonomousClosure'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\run_valley_mvp_autonomous_closure.ps1"
    },
    @{
        name = 'ValleyCloudflareTokenRegeneration'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\ensure_valley_cloudflare_token_regeneration.ps1 -StartAfterRefresh -PersistUserEnv"
    },
    @{
        name = 'ValleySafeAutonomousResume'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\run_valley_safe_autonomous_cycle.ps1 -TotalTokenBudget 258000 -UsedTokens 233500"
    },
    @{
        name = 'ValleyLocalhostRunPublicRuntime'
        workdir = $RepoRootText
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $RepoRootText\scripts\start_valley_localhost_run_public.ps1 -ReplaceStale"
    }
)

if (Test-Path -LiteralPath $EnforceDockerScript -PathType Leaf) {
    $TaskSpecs += @{
        name = 'Valley Enforce HyperV WSL2 Docker'
        workdir = Split-Path -Parent $EnforceDockerScript
        command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $EnforceDockerScript"
    }
}

$Service = New-Object -ComObject 'Schedule.Service'
$Service.Connect()

$Results = @()
foreach ($Spec in $TaskSpecs) {
    try {
        $Results += Set-ValleyHiddenScheduledTask `
            -ScheduleService $Service `
            -TaskPathOrName ([string]$Spec.name) `
            -WorkingDirectory ([string]$Spec.workdir) `
            -CommandLine ([string]$Spec.command)
    } catch {
        $Results += @{
            task = [string]$Spec.name
            status = 'skipped_or_failed'
            error = $_.Exception.Message
        }
    }
}

$Payload = [ordered]@{
    status = 'ok'
    service = 'valley-hidden-runtime-tasks'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    runner = $Runner
    wscript = $Wscript
    policy = 'no_terminal_popups_for_runtime_processes'
    what_if = [bool]$WhatIfOnly
    results = $Results
}

$Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatusPath -Encoding UTF8
$Payload | ConvertTo-Json -Depth 8
