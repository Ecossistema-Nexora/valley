param(
  [string]$InstallDir = "$env:LOCALAPPDATA\Programs\ValleyERP-Lojista"
)

$ErrorActionPreference = "Stop"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Valley ERP Lojista.lnk"
$startShortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "Valley\Valley ERP Lojista.lnk"
$startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "Valley ERP Lojista.lnk"
if (Test-Path -LiteralPath $desktopShortcut) { Remove-Item -LiteralPath $desktopShortcut -Force }
if (Test-Path -LiteralPath $startShortcut) { Remove-Item -LiteralPath $startShortcut -Force }
if (Test-Path -LiteralPath $startupShortcut) { Remove-Item -LiteralPath $startupShortcut -Force }
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Valley ERP Lojista" -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
Write-Host "Valley ERP Lojista removido."