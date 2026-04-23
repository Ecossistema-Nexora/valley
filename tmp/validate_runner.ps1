$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('C:\Users\ereta\.codex\worktrees\VALLEY\scripts\setup_github_actions_runner.ps1', [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { $_.ToString() }
  exit 1
}
Write-Output 'PowerShell syntax OK'
