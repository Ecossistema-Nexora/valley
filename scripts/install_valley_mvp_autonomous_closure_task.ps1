param(
    [string]$TaskName = 'ValleyMvpAutonomousClosure',
    [string]$TaskFolder = '\',
    [int]$IntervalHours = 6,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$StatusPath = Join-Path $RuntimeDir 'valley-mvp-autonomous-closure-task.json'
$ClosureScript = Join-Path $RepoRoot 'scripts\run_valley_mvp_autonomous_closure.ps1'

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Save-TaskStatus {
    param([hashtable]$Payload)
    $Payload.generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    [System.IO.File]::WriteAllText(
        $StatusPath,
        ($Payload | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false)
    )
    $Payload | ConvertTo-Json -Depth 8
}

if (-not (Test-Path -LiteralPath $ClosureScript -PathType Leaf)) {
    Save-TaskStatus @{
        status = 'failed'
        reason = 'closure_script_missing'
        closure_script = $ClosureScript
    }
    exit 1
}

$NormalizedFolder = $TaskFolder.Trim()
if ([string]::IsNullOrWhiteSpace($NormalizedFolder) -or $NormalizedFolder -eq '\') {
    $TaskPath = '\' + $TaskName
} else {
    $TaskPath = ($NormalizedFolder.TrimEnd('\') + '\' + $TaskName)
}
$TaskCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $ClosureScript

try {
    $Existed = $false
    try {
        & schtasks.exe /Query /TN $TaskPath /FO LIST *> $null
        $Existed = ($LASTEXITCODE -eq 0)
    } catch {
        $Existed = $false
    }

    & schtasks.exe /Create /TN $TaskPath /TR $TaskCommand /SC HOURLY /MO $IntervalHours /F | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "schtasks create failed with exit code $LASTEXITCODE"
    }

    if ($RunNow) {
        & schtasks.exe /Run /TN $TaskPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "schtasks run failed with exit code $LASTEXITCODE"
        }
    }

    Save-TaskStatus @{
        status = 'ok'
        task_path = $TaskPath
        existed_before = $Existed
        interval_hours = $IntervalHours
        closure_script = $ClosureScript
        command = $TaskCommand
        run_now = [bool]$RunNow
    }
} catch {
    Save-TaskStatus @{
        status = 'failed'
        task_path = $TaskPath
        interval_hours = $IntervalHours
        closure_script = $ClosureScript
        error = $_.Exception.Message
    }
    exit 1
}
