param(
  [string]$InstallDir = "$env:LOCALAPPDATA\Programs\ValleyERP-Lojista",
  [switch]$NoShortcuts
)

$ErrorActionPreference = "Stop"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceApp = Join-Path $packageRoot "app"
if (-not (Test-Path -LiteralPath $sourceApp)) {
  throw "Pasta app nao encontrada no pacote: $sourceApp"
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceApp "*") -Destination $InstallDir -Recurse -Force

$exe = Join-Path $InstallDir "ValleyERP-Lojista.exe"
if (-not (Test-Path -LiteralPath $exe)) {
  throw "Executavel nao encontrado apos instalacao: $exe"
}

if (-not $NoShortcuts) {
  $shell = New-Object -ComObject WScript.Shell
  $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Valley ERP Lojista.lnk"
  $shortcut = $shell.CreateShortcut($desktopShortcut)
  $shortcut.TargetPath = $exe
  $shortcut.WorkingDirectory = $InstallDir
  $shortcut.Description = "Valley ERP Lojista"
  $shortcut.Save()

  $startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "Valley"
  New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
  $startShortcut = Join-Path $startMenuDir "Valley ERP Lojista.lnk"
  $shortcut = $shell.CreateShortcut($startShortcut)
  $shortcut.TargetPath = $exe
  $shortcut.WorkingDirectory = $InstallDir
  $shortcut.Description = "Valley ERP Lojista"
  $shortcut.Save()

  $startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "Valley ERP Lojista.lnk"
  $shortcut = $shell.CreateShortcut($startupShortcut)
  $shortcut.TargetPath = $exe
  $shortcut.WorkingDirectory = $InstallDir
  $shortcut.Description = "Valley ERP Lojista"
  $shortcut.Save()
}

New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Valley ERP Lojista" -Value "`"$exe`"" -PropertyType String -Force | Out-Null
Write-Host "Valley ERP Lojista instalado em: $InstallDir"