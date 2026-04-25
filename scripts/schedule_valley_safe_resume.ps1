param(
    [int]$TotalTokenBudget = 258000,
    [int]$UsedTokens = 171000,
    [string]$TaskName = 'ValleySafeAutonomousResume'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$BudgetPath = Join-Path $RuntimeDir 'codex-token-budget-report.json'
$Wrapper = Join-Path $PSScriptRoot 'run_valley_safe_autonomous_cycle.cmd'
$ManifestPath = Join-Path $RuntimeDir 'valley-safe-resume-schedule.json'

if (-not (Test-Path -LiteralPath $Wrapper -PathType Leaf)) {
    throw "Wrapper de ciclo seguro nao encontrado: $Wrapper"
}

if (Test-Path -LiteralPath $BudgetPath -PathType Leaf) {
    $Budget = Get-Content -Raw -LiteralPath $BudgetPath | ConvertFrom-Json
    $ResumeAtUtc = [DateTimeOffset]::Parse([string]$Budget.estimated_resume_at_utc)
} else {
    $ResumeAtUtc = [DateTimeOffset]::UtcNow.AddHours(1)
}

$LocalResume = $ResumeAtUtc.ToLocalTime().DateTime
if ($LocalResume -le (Get-Date).AddMinutes(1)) {
    $LocalResume = (Get-Date).AddMinutes(5)
}

$Action = '"' + $Wrapper + '" -TotalTokenBudget ' + $TotalTokenBudget + ' -UsedTokens ' + $UsedTokens
$TimeArg = $LocalResume.ToString('HH:mm')
$DateArg = $LocalResume.ToString('dd/MM/yyyy')

$PreviousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $Result = & schtasks.exe /Create /F /SC ONCE /TN $TaskName /TR $Action /ST $TimeArg /SD $DateArg 2>&1
    $ExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
}

$Manifest = [ordered]@{
    status = if ($ExitCode -eq 0) { 'scheduled' } else { 'fallback_only' }
    task_name = $TaskName
    resume_at_utc = $ResumeAtUtc.ToString('o')
    resume_at_local = $LocalResume.ToString('o')
    action = $Action
    schtasks_exit_code = $ExitCode
    schtasks_output = [string]($Result -join "`n")
    generated_at = (Get-Date).ToString('o')
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

if ($ExitCode -ne 0) {
    $StartupDir = [Environment]::GetFolderPath('Startup')
    $StartupCommand = Join-Path $StartupDir 'ValleySafeAutonomousResume.cmd'
    Set-Content -LiteralPath $StartupCommand -Value ("@echo off`r`ncall {0}`r`n" -f $Action) -Encoding ASCII
}

Write-Output ($Manifest | ConvertTo-Json -Depth 5)
