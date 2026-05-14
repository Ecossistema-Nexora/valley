param(
  [string]$Version = "v047",
  [string]$ApiBaseUrl = "https://admin.brasildesconto.com.br"
)

$ErrorActionPreference = "Stop"

function Write-Utf8File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function New-CleanDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$AllowedRoot
  )
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullRoot = [System.IO.Path]::GetFullPath($AllowedRoot)
  if (-not $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean outside release root: $fullPath"
  }
  if (Test-Path -LiteralPath $fullPath) {
    Remove-Item -LiteralPath $fullPath -Recurse -Force
  }
  New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

function Copy-RequiredItem {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  if (-not (Test-Path -LiteralPath $Source)) {
    throw "Required package source not found: $Source"
  }
  $parent = Split-Path -Parent $Destination
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  if ((Get-Item -LiteralPath $Source).PSIsContainer) {
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
  } else {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
  }
}

function Get-ArtifactInfo {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$PublicUrl,
    [Parameter(Mandatory = $true)][string]$Kind
  )
  $item = Get-Item -LiteralPath $Path
  $sha1 = (Get-FileHash -Algorithm SHA1 -LiteralPath $Path).Hash
  $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  Write-Utf8File -Path "$Path.sha1" -Content "$sha1  $($item.Name)`n"
  Write-Utf8File -Path "$Path.sha256" -Content "$sha256  $($item.Name)`n"
  [ordered]@{
    kind = $Kind
    name = $item.Name
    bytes = $item.Length
    sha1 = $sha1
    sha256 = $sha256
    public_url = $PublicUrl
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$flutterRoot = Join-Path $repoRoot "frontend/flutter"
$releaseRoot = Join-Path $repoRoot "admin/downloads/$Version"
$releaseRootFull = [System.IO.Path]::GetFullPath($releaseRoot)
New-Item -ItemType Directory -Path $releaseRootFull -Force | Out-Null

$windowsPackageName = "ValleyERP-Lojista-Windows-x64-$Version"
$windowsPackageRoot = Join-Path $releaseRootFull "windows/ValleyERP-Lojista-Windows-x64"
$windowsAppRoot = Join-Path $windowsPackageRoot "app"
New-CleanDirectory -Path $windowsPackageRoot -AllowedRoot $releaseRootFull

$windowsBuildRoot = Join-Path $flutterRoot "build/windows/x64"
$runnerExe = Join-Path $windowsBuildRoot "runner/Release/valley_super_app.exe"
$flutterDll = Join-Path $flutterRoot "windows/flutter/ephemeral/flutter_windows.dll"
$icuData = Join-Path $flutterRoot "windows/flutter/ephemeral/icudtl.dat"
$appSo = Join-Path $flutterRoot "build/windows/app.so"
$flutterAssets = Join-Path $flutterRoot "build/flutter_assets"
$nativeAssets = Join-Path $flutterRoot "build/native_assets/windows"

Copy-RequiredItem -Source $runnerExe -Destination (Join-Path $windowsAppRoot "ValleyERP-Lojista.exe")
Copy-RequiredItem -Source $flutterDll -Destination (Join-Path $windowsAppRoot "flutter_windows.dll")
Copy-RequiredItem -Source $icuData -Destination (Join-Path $windowsAppRoot "data/icudtl.dat")
Copy-RequiredItem -Source $appSo -Destination (Join-Path $windowsAppRoot "data/app.so")
Copy-RequiredItem -Source $flutterAssets -Destination (Join-Path $windowsAppRoot "data/flutter_assets")
if (Test-Path -LiteralPath $nativeAssets) {
  Copy-Item -LiteralPath (Join-Path $nativeAssets "*") -Destination $windowsAppRoot -Recurse -Force
}

$pluginDlls = @(
  "plugins/flutter_tts/Release/flutter_tts_plugin.dll",
  "plugins/jni/shared/Release/dartjni.dll",
  "plugins/share_plus/Release/share_plus_plugin.dll",
  "plugins/speech_to_text_windows/Release/speech_to_text_windows_plugin.dll",
  "plugins/url_launcher_windows/Release/url_launcher_windows_plugin.dll"
)
foreach ($relativeDll in $pluginDlls) {
  $source = Join-Path $windowsBuildRoot $relativeDll
  Copy-RequiredItem -Source $source -Destination (Join-Path $windowsAppRoot (Split-Path -Leaf $source))
}

$windowsInstall = @'
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
}

Write-Host "Valley ERP Lojista instalado em: $InstallDir"
'@
Write-Utf8File -Path (Join-Path $windowsPackageRoot "install-valley-erp-lojista-windows.ps1") -Content $windowsInstall

$windowsUninstall = @'
param(
  [string]$InstallDir = "$env:LOCALAPPDATA\Programs\ValleyERP-Lojista"
)

$ErrorActionPreference = "Stop"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Valley ERP Lojista.lnk"
$startShortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "Valley\Valley ERP Lojista.lnk"
if (Test-Path -LiteralPath $desktopShortcut) { Remove-Item -LiteralPath $desktopShortcut -Force }
if (Test-Path -LiteralPath $startShortcut) { Remove-Item -LiteralPath $startShortcut -Force }
if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
Write-Host "Valley ERP Lojista removido."
'@
Write-Utf8File -Path (Join-Path $windowsPackageRoot "uninstall-valley-erp-lojista-windows.ps1") -Content $windowsUninstall

$windowsReadme = @"
PROPOSITO: Instalar o Valley ERP Lojista no Windows.
CONTEXTO: Pacote desktop $Version gerado a partir do Flutter Desktop com login inicial do lojista e menu por botoes.
REGRAS: Use o instalador local sem permissao administrativa; os modulos nao exibem cabecalho global de links.

# Valley ERP Lojista - Windows x64

## Instalar

Abra PowerShell dentro desta pasta e execute:

````powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install-valley-erp-lojista-windows.ps1
````

## Executar sem instalar

````powershell
.\app\ValleyERP-Lojista.exe
````

## Remover

````powershell
.\uninstall-valley-erp-lojista-windows.ps1
````

API base embarcada: `$ApiBaseUrl
"@
Write-Utf8File -Path (Join-Path $windowsPackageRoot "README_WINDOWS.md") -Content $windowsReadme

$windowsZip = Join-Path $releaseRootFull "$windowsPackageName.zip"
if (Test-Path -LiteralPath $windowsZip) { Remove-Item -LiteralPath $windowsZip -Force }
Compress-Archive -LiteralPath $windowsPackageRoot -DestinationPath $windowsZip -Force

$linuxPackageName = "ValleyERP-Lojista-Linux-x64-$Version"
$linuxPackageRoot = Join-Path $releaseRootFull "linux/ValleyERP-Lojista-Linux-x64"
New-CleanDirectory -Path $linuxPackageRoot -AllowedRoot $releaseRootFull
New-Item -ItemType Directory -Path (Join-Path $linuxPackageRoot "app") -Force | Out-Null

$linuxInstall = @'
#!/usr/bin/env bash
set -euo pipefail

APP_ID="valley-erp-lojista"
APP_NAME="Valley ERP Lojista"
API_BASE_URL="${VALLEY_PRODUCT_API_BASE_URL:-__API_BASE_URL__}"
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/$APP_ID}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/.local/share/applications}"
SOURCE_ROOT="${SOURCE_ROOT:-}"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

if [ -x "$PACKAGE_DIR/app/valley_erp_lojista" ] || [ -x "$PACKAGE_DIR/app/valley_super_app" ]; then
  cp -R "$PACKAGE_DIR/app/." "$INSTALL_DIR/"
elif [ -n "$SOURCE_ROOT" ] && [ -d "$SOURCE_ROOT/frontend/flutter" ]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Flutter nao encontrado. Instale Flutter Linux Desktop ou forneca app/ precompilado." >&2
    exit 2
  fi
  (
    cd "$SOURCE_ROOT/frontend/flutter"
    flutter config --enable-linux-desktop
    flutter pub get
    flutter build linux --release --target lib/merchant_erp_desktop_main.dart --dart-define=VALLEY_PRODUCT_API_BASE_URL="$API_BASE_URL"
  )
  rm -rf "$INSTALL_DIR"/*
  cp -R "$SOURCE_ROOT/frontend/flutter/build/linux/x64/release/bundle/." "$INSTALL_DIR/"
else
  echo "Binario Linux nao incluido neste pacote Windows-hosted." >&2
  echo "Execute com SOURCE_ROOT=/caminho/para/VALLEY para compilar no Linux." >&2
  exit 2
fi

EXECUTABLE="$INSTALL_DIR/valley_erp_lojista"
if [ ! -x "$EXECUTABLE" ] && [ -x "$INSTALL_DIR/valley_super_app" ]; then
  EXECUTABLE="$INSTALL_DIR/valley_super_app"
fi
if [ ! -x "$EXECUTABLE" ]; then
  echo "Executavel nao encontrado em $INSTALL_DIR." >&2
  exit 3
fi

cat > "$BIN_DIR/$APP_ID" <<EOF
#!/usr/bin/env bash
export VALLEY_PRODUCT_API_BASE_URL="$API_BASE_URL"
cd "$INSTALL_DIR"
exec "$EXECUTABLE" "\$@"
EOF
chmod +x "$BIN_DIR/$APP_ID"

cat > "$DESKTOP_DIR/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=ERP Lojista Valley
Exec=$BIN_DIR/$APP_ID
Terminal=false
Categories=Office;Finance;
EOF

echo "$APP_NAME instalado em: $INSTALL_DIR"
echo "Comando: $BIN_DIR/$APP_ID"
'@
$linuxInstall = $linuxInstall.Replace("__API_BASE_URL__", $ApiBaseUrl)
Write-Utf8File -Path (Join-Path $linuxPackageRoot "install-valley-erp-lojista-linux.sh") -Content $linuxInstall

$linuxBuild = @'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
export VALLEY_PRODUCT_API_BASE_URL="${VALLEY_PRODUCT_API_BASE_URL:-__API_BASE_URL__}"

cd "$REPO_ROOT/frontend/flutter"
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release --target lib/merchant_erp_desktop_main.dart --dart-define=VALLEY_PRODUCT_API_BASE_URL="$VALLEY_PRODUCT_API_BASE_URL"

echo "Bundle gerado em: $REPO_ROOT/frontend/flutter/build/linux/x64/release/bundle"
'@
$linuxBuild = $linuxBuild.Replace("__API_BASE_URL__", $ApiBaseUrl)
Write-Utf8File -Path (Join-Path $linuxPackageRoot "build-linux-from-source.sh") -Content $linuxBuild

$linuxReadme = @"
PROPOSITO: Instalar o Valley ERP Lojista no Linux.
CONTEXTO: Pacote desktop $Version com script de instalacao e caminho de build a partir do repo.
REGRAS: O binario Linux deve ser compilado em host Linux com Flutter Desktop habilitado quando nao estiver precompilado no pacote.

# Valley ERP Lojista - Linux x64

## Instalar com binario precompilado

````bash
bash install-valley-erp-lojista-linux.sh
````

## Compilar e instalar a partir do repositório

````bash
SOURCE_ROOT=/caminho/para/VALLEY bash install-valley-erp-lojista-linux.sh
````

## Gerar bundle Linux manualmente

````bash
bash build-linux-from-source.sh /caminho/para/VALLEY
````

API base usada por padrao: `$ApiBaseUrl
"@
Write-Utf8File -Path (Join-Path $linuxPackageRoot "README_LINUX.md") -Content $linuxReadme
Write-Utf8File -Path (Join-Path $linuxPackageRoot "app/README_NO_BINARY.txt") -Content "Binario Linux nao foi embutido no host Windows. Use SOURCE_ROOT para compilar em Linux com Flutter Desktop.`n"

$linuxTar = Join-Path $releaseRootFull "$linuxPackageName.tar.gz"
if (Test-Path -LiteralPath $linuxTar) { Remove-Item -LiteralPath $linuxTar -Force }
$tarExe = (Get-Command tar.exe -ErrorAction Stop).Source
& $tarExe -czf $linuxTar -C (Join-Path $releaseRootFull "linux") "ValleyERP-Lojista-Linux-x64"

$publicBase = "https://admin.brasildesconto.com.br/downloads/$Version"
$artifacts = @()
$artifacts += Get-ArtifactInfo -Path $windowsZip -PublicUrl "$publicBase/$windowsPackageName.zip" -Kind "windows_x64_zip"
$artifacts += Get-ArtifactInfo -Path $linuxTar -PublicUrl "$publicBase/$linuxPackageName.tar.gz" -Kind "linux_x64_tar_gz"

$manifest = [ordered]@{
  product = "Valley ERP Lojista"
  version = $Version
  generated_at = (Get-Date).ToString("o")
  api_base_url = $ApiBaseUrl
  flutter_entrypoint = "frontend/flutter/lib/merchant_erp_desktop_main.dart"
  release_root = "admin/downloads/$Version"
  windows_install = "PowerShell: .\\install-valley-erp-lojista-windows.ps1"
  linux_install = "bash install-valley-erp-lojista-linux.sh"
  artifacts = $artifacts
}
$manifestPath = Join-Path $releaseRootFull "VALLEY_ERP_LOJISTA_DESKTOP_INSTALLERS_V047.json"
Write-Utf8File -Path $manifestPath -Content (($manifest | ConvertTo-Json -Depth 8) + "`n")
Get-ArtifactInfo -Path $manifestPath -PublicUrl "$publicBase/VALLEY_ERP_LOJISTA_DESKTOP_INSTALLERS_V047.json" -Kind "manifest" | Out-Null

Write-Host "Desktop installers packaged in $releaseRootFull"
Write-Host "Windows: $windowsZip"
Write-Host "Linux: $linuxTar"
Write-Host "Manifest: $manifestPath"
