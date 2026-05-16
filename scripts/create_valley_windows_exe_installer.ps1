param(
    [string]$ReleaseDir = "frontend\flutter\build\windows\x64\runner\Release",
    [string]$OutputDir = "output\releases",
    [string]$VersionLabel = "v060_20260516_0200_brt"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path "."
$releasePath = Resolve-Path $ReleaseDir
$outputPath = New-Item -ItemType Directory -Force -Path $OutputDir
$stagingPath = Join-Path $outputPath.FullName "valley_windows_exe_installer_staging"
$installerScript = Resolve-Path "scripts\install_valley_windows_bundle.ps1"
$csharpInstaller = Resolve-Path "scripts\ValleyWindowsInstaller.cs"
$bundleZip = Join-Path $stagingPath "valley_super_app_windows_bundle.zip"
$targetExe = Join-Path $outputPath.FullName "ValleySuperAppSetup_$VersionLabel.exe"
$sedPath = Join-Path $stagingPath "valley_super_app_iexpress.sed"

$required = @(
    "valley_super_app.exe",
    "flutter_windows.dll",
    "data"
)
foreach ($item in $required) {
    $candidate = Join-Path $releasePath $item
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Item obrigatorio ausente no build Windows: $candidate"
    }
}

if (Test-Path -LiteralPath $stagingPath) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagingPath | Out-Null

Copy-Item -LiteralPath $installerScript -Destination (Join-Path $stagingPath "install_valley_super_app.ps1") -Force
if (Test-Path -LiteralPath $bundleZip) {
    Remove-Item -LiteralPath $bundleZip -Force
}
Compress-Archive -Path (Join-Path $releasePath "*") -DestinationPath $bundleZip -CompressionLevel Optimal

if (Test-Path -LiteralPath $targetExe) {
    Remove-Item -LiteralPath $targetExe -Force
}

$cscCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) {
    throw "Compilador C# .NET Framework nao encontrado."
}

$compilerArgs = @(
    "/nologo",
    "/target:winexe",
    "/optimize+",
    "/platform:anycpu",
    "/out:$targetExe",
    "/resource:$bundleZip,ValleyBundle.zip",
    "/r:System.IO.Compression.dll",
    "/r:System.IO.Compression.FileSystem.dll",
    "/r:Microsoft.CSharp.dll",
    $csharpInstaller.Path
)

& $csc @compilerArgs
if ($LASTEXITCODE -ne 0) {
    throw "Compilacao do instalador EXE falhou com codigo $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $targetExe)) {
    throw "EXE nao foi gerado: $targetExe"
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $targetExe
$exe = Get-Item -LiteralPath $targetExe
$bundle = Get-Item -LiteralPath $bundleZip
$result = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    installer_exe = $exe.FullName
    installer_bytes = $exe.Length
    installer_sha256 = $hash.Hash
    bundled_zip = $bundle.FullName
    bundled_zip_bytes = $bundle.Length
    release_dir = $releasePath.Path
    builder = "csc_embedded_zip_installer"
    policies = @(
        "install_to_local_app_data",
        "start_menu_shortcut",
        "startup_autostart_shortcut",
        "taskbar_shortcut_and_shell_pin_attempt",
        "launch_after_install"
    )
}

$resultPath = Join-Path $outputPath.FullName "ValleySuperAppSetup_$VersionLabel.json"
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
$result | ConvertTo-Json -Depth 5
