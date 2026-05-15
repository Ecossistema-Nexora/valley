<#
PROPOSITO: Gerar entregas de arquivo unico para o Valley ERP Lojista.

CONTEXTO: O usuario exigiu um executavel unico por plataforma, por exemplo
Valley-ERP.exe para Windows, sem depender de ZIP/TAR como artefato principal.

REGRAS: Reutilizar o pacote desktop duravel, embutir o ZIP Windows em um
launcher autoextraivel, gerar um .run Linux unico e publicar hashes/manifest.
#>

param(
  [string]$Version = 'v050',
  [string]$ApiBaseUrl = 'https://admin.brasildesconto.com.br'
)

$ErrorActionPreference = 'Stop'

function Write-Utf8File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-ValleyFileHash {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('SHA1', 'SHA256')][string]$Algorithm,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
  $stream = [System.IO.File]::OpenRead($resolvedPath)
  try {
    if ($Algorithm -eq 'SHA1') {
      $hasher = [System.Security.Cryptography.SHA1]::Create()
    }
    else {
      $hasher = [System.Security.Cryptography.SHA256]::Create()
    }
    try {
      $hashBytes = $hasher.ComputeHash($stream)
    }
    finally {
      $hasher.Dispose()
    }
  }
  finally {
    $stream.Dispose()
  }
  return (($hashBytes | ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant()
}

function Get-ArtifactInfo {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$PublicUrl,
    [Parameter(Mandatory = $true)][string]$Kind
  )
  $item = Get-Item -LiteralPath $Path
  $sha1 = Get-ValleyFileHash -Algorithm SHA1 -Path $Path
  $sha256 = Get-ValleyFileHash -Algorithm SHA256 -Path $Path
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

function Convert-FileToBase64Lines {
  param([Parameter(Mandatory = $true)][string]$Path)
  $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
  $lines = [System.Collections.Generic.List[string]]::new()
  for ($i = 0; $i -lt $base64.Length; $i += 76) {
    $length = [Math]::Min(76, $base64.Length - $i)
    $lines.Add($base64.Substring($i, $length))
  }
  return ($lines -join "`n")
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ReleaseRoot = Join-Path $RepoRoot "admin\downloads\$Version"
$PublicBase = "$ApiBaseUrl/downloads/$Version"
$ManifestName = "VALLEY_ERP_SINGLE_EXECUTABLES_$($Version.ToUpperInvariant()).json"
$ManifestPath = Join-Path $ReleaseRoot $ManifestName
$WindowsZip = Join-Path $ReleaseRoot "ValleyERP-Lojista-Windows-x64-$Version.zip"
$LinuxTar = Join-Path $ReleaseRoot "ValleyERP-Lojista-Linux-x64-$Version.tar.gz"
$WindowsSingle = Join-Path $ReleaseRoot 'Valley-ERP.exe'
$LinuxSingle = Join-Path $ReleaseRoot 'Valley-ERP-Linux.run'
$WindowsProject = Join-Path $RepoRoot 'tools\valley_erp_single_windows'
$PayloadPath = Join-Path $WindowsProject 'payload.zip'

New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\package_merchant_erp_desktop.ps1') -Version $Version -ApiBaseUrl $ApiBaseUrl

if (-not (Test-Path -LiteralPath $WindowsZip -PathType Leaf)) {
  throw "Pacote Windows base nao encontrado: $WindowsZip"
}
if (-not (Test-Path -LiteralPath $LinuxTar -PathType Leaf)) {
  throw "Pacote Linux base nao encontrado: $LinuxTar"
}

Copy-Item -LiteralPath $WindowsZip -Destination $PayloadPath -Force
$PublishDir = Join-Path $WindowsProject "bin\Release\net10.0\win-x64\publish"
if (Test-Path -LiteralPath $PublishDir) {
  Remove-Item -LiteralPath $PublishDir -Recurse -Force
}
dotnet publish $WindowsProject -c Release -r win-x64 --self-contained true `
  /p:PublishSingleFile=true /p:DebugType=None /p:DebugSymbols=false | Out-Host
$PublishedExe = Join-Path $PublishDir 'Valley-ERP.exe'
if (-not (Test-Path -LiteralPath $PublishedExe -PathType Leaf)) {
  throw "dotnet publish nao gerou $PublishedExe"
}
Copy-Item -LiteralPath $PublishedExe -Destination $WindowsSingle -Force
$WindowsCheckOutput = & $WindowsSingle --check 2>&1
if ($LASTEXITCODE -ne 0) {
  $WindowsCheckText = ($WindowsCheckOutput | Out-String).Trim()
  throw "Valley-ERP.exe falhou na validacao interna --check. $WindowsCheckText"
}
Remove-Item -LiteralPath $PayloadPath -Force

$LinuxPayload = Convert-FileToBase64Lines -Path $LinuxTar
$LinuxRunner = @"
#!/usr/bin/env bash
set -euo pipefail

APP_ID="valley-erp-lojista"
APP_NAME="Valley ERP Lojista"
API_BASE_URL="${ApiBaseUrl}"
PAYLOAD_LINE=`$(awk '/^__VALLEY_PAYLOAD_BELOW__/ {print NR + 1; exit 0;}' "`$0")
if [ -z "`$PAYLOAD_LINE" ]; then
  echo "Payload nao encontrado no executavel." >&2
  exit 1
fi

WORKDIR=`$(mktemp -d)
trap 'rm -rf "`$WORKDIR"' EXIT
tail -n +"`$PAYLOAD_LINE" "`$0" | base64 -d > "`$WORKDIR/payload.tar.gz"
tar -xzf "`$WORKDIR/payload.tar.gz" -C "`$WORKDIR"
PACKAGE_DIR="`$WORKDIR/ValleyERP-Lojista-Linux-x64"

if [ ! -d "`$PACKAGE_DIR" ]; then
  echo "Pacote Linux interno nao encontrado." >&2
  exit 1
fi

if SOURCE_ROOT="`${SOURCE_ROOT:-}" bash "`$PACKAGE_DIR/install-valley-erp-lojista-linux.sh"; then
  if command -v valley-erp-lojista >/dev/null 2>&1; then
    exec valley-erp-lojista
  fi
  if [ -x "`$HOME/.local/bin/valley-erp-lojista" ]; then
    exec "`$HOME/.local/bin/valley-erp-lojista"
  fi
  exit 0
fi

mkdir -p "`$HOME/.local/bin" "`$HOME/.local/share/applications"
LAUNCHER="`$HOME/.local/bin/valley-erp-lojista"
cat > "`$LAUNCHER" <<'LAUNCHER_EOF'
#!/usr/bin/env bash
set -euo pipefail
URL="${ApiBaseUrl}"
if command -v xdg-open >/dev/null 2>&1; then exec xdg-open "`$URL"; fi
if command -v sensible-browser >/dev/null 2>&1; then exec sensible-browser "`$URL"; fi
echo "Abra: `$URL"
LAUNCHER_EOF
chmod +x "`$LAUNCHER"
cat > "`$HOME/.local/share/applications/valley-erp-lojista.desktop" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=`$APP_NAME
Comment=ERP Lojista Valley
Exec=`$LAUNCHER
Terminal=false
Categories=Office;Finance;
DESKTOP_EOF
echo "`$APP_NAME instalado como launcher unico. Comando: `$LAUNCHER"
exec "`$LAUNCHER"

__VALLEY_PAYLOAD_BELOW__
$LinuxPayload
"@
Write-Utf8File -Path $LinuxSingle -Content $LinuxRunner

$BlueprintMd = Join-Path $ReleaseRoot "VALLEY_ERP_SINGLE_EXECUTABLES_$($Version.ToUpperInvariant()).md"
Write-Utf8File -Path $BlueprintMd -Content @"
PROPOSITO: Documentar os executaveis unicos do Valley ERP Lojista $($Version.ToUpperInvariant()).
CONTEXTO: Esta release troca a entrega principal ZIP/TAR por um arquivo executavel por plataforma.
REGRAS: Usar os links publicos abaixo apenas depois de health HTTP 200 no dominio fixo Cloudflare.

# Valley ERP Lojista - Executaveis Unicos $($Version.ToUpperInvariant())

## Links

- Windows: $PublicBase/Valley-ERP.exe
- Linux: $PublicBase/Valley-ERP-Linux.run
- Manifesto: $PublicBase/$ManifestName

## Observacoes

- O Windows `Valley-ERP.exe` e o instalador nativo principal: embute o pacote desktop, valida o payload com `--check`, instala em `%LOCALAPPDATA%\Programs\ValleyERP-Lojista` e registra inicializacao automatica do ERP no Windows via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
- Comandos nativos do Windows: `Valley-ERP.exe --check`, `Valley-ERP.exe --install-only`, `Valley-ERP.exe --startup-only`, `Valley-ERP.exe --no-startup` e `Valley-ERP.exe --uninstall`.
- O Linux `Valley-ERP-Linux.run` embute o pacote Linux e tenta instalar/executar o app; quando o host Linux nao tem bundle nativo compilado, cria launcher unico para o runtime publico validado.
- API base: $ApiBaseUrl
"@

$Artifacts = @()
$Artifacts += Get-ArtifactInfo -Path $WindowsSingle -PublicUrl "$PublicBase/Valley-ERP.exe" -Kind 'windows_single_exe'
$Artifacts += Get-ArtifactInfo -Path $LinuxSingle -PublicUrl "$PublicBase/Valley-ERP-Linux.run" -Kind 'linux_single_run'
$Artifacts += Get-ArtifactInfo -Path $WindowsZip -PublicUrl "$PublicBase/ValleyERP-Lojista-Windows-x64-$Version.zip" -Kind 'windows_support_zip'
$Artifacts += Get-ArtifactInfo -Path $LinuxTar -PublicUrl "$PublicBase/ValleyERP-Lojista-Linux-x64-$Version.tar.gz" -Kind 'linux_support_tar_gz'
$Artifacts += Get-ArtifactInfo -Path $BlueprintMd -PublicUrl "$PublicBase/VALLEY_ERP_SINGLE_EXECUTABLES_$($Version.ToUpperInvariant()).md" -Kind 'single_executables_markdown'

$Manifest = [ordered]@{
  product = 'Valley ERP Lojista'
  version = $Version
  generated_at = (Get-Date).ToString('o')
  api_base_url = $ApiBaseUrl
  release_root = "admin/downloads/$Version"
  primary_artifacts = @('Valley-ERP.exe', 'Valley-ERP-Linux.run')
  cloudflare_public_health = "$ApiBaseUrl/healthz"
  artifacts = $Artifacts
}
Write-Utf8File -Path $ManifestPath -Content (($Manifest | ConvertTo-Json -Depth 8) + "`n")
Get-ArtifactInfo -Path $ManifestPath -PublicUrl "$PublicBase/$ManifestName" -Kind 'single_executables_manifest' | Out-Null

Write-Host "Single executables generated:"
Write-Host $WindowsSingle
Write-Host $LinuxSingle
Write-Host $ManifestPath
