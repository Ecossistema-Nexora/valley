param(
    [Parameter(Mandatory = $true)]
    [string]$ActivityName,

    [ValidateSet('validate', 'checkpoint', 'admin', 'release', 'sync', 'sql', 'packages')]
    [string]$Mode = 'checkpoint'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PolicyPath = Join-Path $RepoRoot 'config\automation\valley_module_activity_policy.json'
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-module-activity-automation-status.json'
$LedgerPath = Join-Path $RuntimeDir 'valley-module-activity-automation-ledger.jsonl'
$EnginePath = Join-Path $RepoRoot 'scripts\valley_module_automation.py'

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null

function Get-PythonCommand {
    $Command = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        return $Command.Source
    }
    $Command = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        return $Command.Source
    }
    throw 'Python nao encontrado para acionar o Valley Module Automation Engine.'
}

function Get-ModeCommands {
    param([string]$SelectedMode)

    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
        return @('validate')
    }

    $Policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $Commands = $Policy.mode_commands.$SelectedMode
    if ($null -eq $Commands) {
        return @('validate')
    }
    return @($Commands)
}

function New-Tail {
    param(
        [string]$Text,
        [int]$MaxChars = 3000
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }
    if ($Text.Length -le $MaxChars) {
        return $Text.Trim()
    }
    return $Text.Substring($Text.Length - $MaxChars).Trim()
}

if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
    throw "Valley Module Automation Engine nao encontrado: $EnginePath"
}

$Python = Get-PythonCommand
$StartedAt = (Get-Date).ToString('o')
$Results = @()
$OverallStatus = 'success'

foreach ($Command in (Get-ModeCommands -SelectedMode $Mode)) {
    $CommandStartedAt = (Get-Date).ToString('o')
    $OutputFile = Join-Path $RuntimeDir ("valley-module-automation-{0}-{1}.out.log" -f $Command, ([guid]::NewGuid().ToString('N')))
    $ErrorFile = Join-Path $RuntimeDir ("valley-module-automation-{0}-{1}.err.log" -f $Command, ([guid]::NewGuid().ToString('N')))

    $Process = Start-Process `
        -FilePath $Python `
        -ArgumentList @($EnginePath, $Command) `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $OutputFile `
        -RedirectStandardError $ErrorFile `
        -NoNewWindow `
        -PassThru `
        -Wait

    $Stdout = if (Test-Path -LiteralPath $OutputFile) { Get-Content -Raw -LiteralPath $OutputFile } else { '' }
    $Stderr = if (Test-Path -LiteralPath $ErrorFile) { Get-Content -Raw -LiteralPath $ErrorFile } else { '' }
    $CommandStatus = if ($Process.ExitCode -eq 0) { 'success' } else { 'failed' }
    if ($CommandStatus -ne 'success') {
        $OverallStatus = 'failed'
    }

    $Result = [ordered]@{
        command = $Command
        status = $CommandStatus
        exit_code = $Process.ExitCode
        started_at = $CommandStartedAt
        finished_at = (Get-Date).ToString('o')
        stdout_tail = New-Tail -Text $Stdout
        stderr_tail = New-Tail -Text $Stderr
        stdout_log = $OutputFile
        stderr_log = $ErrorFile
    }
    $Results += [pscustomobject]$Result

    if ($Process.ExitCode -ne 0) {
        break
    }
}

$FinishedAt = (Get-Date).ToString('o')
$Payload = [ordered]@{
    status = $OverallStatus
    activity_name = $ActivityName
    mode = $Mode
    mandatory = $true
    engine = $EnginePath
    policy = $PolicyPath
    started_at = $StartedAt
    finished_at = $FinishedAt
    results = @($Results)
}

$Json = $Payload | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $StatusPath -Value $Json -Encoding UTF8
Add-Content -LiteralPath $LedgerPath -Value (($Payload | ConvertTo-Json -Depth 8 -Compress)) -Encoding UTF8
Write-Output $Json

if ($OverallStatus -ne 'success') {
    exit 1
}
