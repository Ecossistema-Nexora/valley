param(
  [int]$IntervalMinutes = 5
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script = Join-Path $repoRoot "scripts\start_valley_senior_status_webhook.ps1"
$taskName = "ValleySeniorStatusWebhook"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument (
  "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -IntervalSeconds " +
  ($IntervalMinutes * 60)
)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
  -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
  -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
[pscustomobject]@{
  task_name = $taskName
  interval_minutes = $IntervalMinutes
  script = $script
  status = "registered"
} | ConvertTo-Json
