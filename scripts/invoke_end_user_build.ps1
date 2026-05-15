# PROPOSITO: Executar a diretriz END-USER-BUILD no workspace Valley.
# CONTEXTO: Este script valida ou executa builds finais para web, Android, Windows, Linux, PDF e Telegram.
# REGRAS: Usar modo release, nao expor segredos, preferir APIs finais e falhar se UI tecnica estiver ativa.

param(
  [ValidateSet('validate', 'build-web', 'build-apk', 'build-windows', 'build-desktop', 'update-pdf', 'send-telegram', 'release-final')]
  [string]$Mode = 'validate',
  [string]$Version = '',
  [string]$ApiBaseUrl = 'https://admin.brasildesconto.com.br',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$policyPath = Join-Path $repoRoot 'config\build\end-user-build.policy.json'
$flutterRoot = Join-Path $repoRoot 'frontend\flutter'
$runtimeStatusPath = Join-Path $repoRoot 'tmp\runtime\end-user-build-status.json'

function New-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail
  )

  [pscustomobject]@{
    name = $Name
    ok = $Ok
    detail = $Detail
  }
}

function Get-LatestPlanVersion {
  $indexPath = Join-Path $repoRoot 'PLANOS\INDEX.md'
  if (-not (Test-Path -LiteralPath $indexPath)) {
    return 'v000'
  }
  $versions = [System.Collections.Generic.List[int]]::new()
  foreach ($line in Get-Content -LiteralPath $indexPath) {
    if ($line -match '^\|\s+v(\d{3})\s+\|') {
      $versions.Add([int]$Matches[1]) | Out-Null
    }
  }
  if ($versions.Count -eq 0) {
    return 'v000'
  }
  $maxVersion = [int](($versions | Measure-Object -Maximum).Maximum)
  return ('v{0:D3}' -f $maxVersion)
}

function Get-ReleaseRoot {
  param([string]$ReleaseVersion)
  $path = Join-Path $repoRoot "admin\downloads\$ReleaseVersion"
  New-Item -ItemType Directory -Path $path -Force | Out-Null
  return $path
}

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

function Write-ArtifactHash {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return
  }
  $item = Get-Item -LiteralPath $Path
  $sha1 = Get-ValleyFileHash -Algorithm SHA1 -Path $Path
  $sha256 = Get-ValleyFileHash -Algorithm SHA256 -Path $Path
  Write-Utf8File -Path "$Path.sha1" -Content "$sha1  $($item.Name)`n"
  Write-Utf8File -Path "$Path.sha256" -Content "$sha256  $($item.Name)`n"
}

function Get-SourceFiles {
  $paths = @(
    (Join-Path $repoRoot 'frontend\flutter\lib'),
    (Join-Path $repoRoot 'admin\app.js'),
    (Join-Path $repoRoot 'admin\index.html')
  )

  $files = [System.Collections.Generic.List[object]]::new()
  foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path)) {
      continue
    }
    $item = Get-Item -LiteralPath $path
    if ($item.PSIsContainer) {
      Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
        Where-Object { $_.Extension -in @('.dart', '.js', '.html') } |
        ForEach-Object { $files.Add($_) | Out-Null }
    }
    else {
      $files.Add($item) | Out-Null
    }
  }
  return $files
}

function Find-PatternViolations {
  $patterns = @(
    @{ name = 'debug banner ativo'; regex = 'debugShowCheckedModeBanner\s*:\s*true' },
    @{ name = 'LogConsole exposto'; regex = '\bLogConsole\b' },
    @{ name = 'Inspector exposto'; regex = '\bInspector\b' },
    @{ name = 'FloatingActionButton de suporte tecnico'; regex = '\bFloatingActionButton\b' }
  )

  $violations = [System.Collections.Generic.List[object]]::new()
  foreach ($file in Get-SourceFiles) {
    $relativePath = $file.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
    $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    for ($index = 0; $index -lt $lines.Count; $index++) {
      $line = [string]$lines[$index]
      foreach ($pattern in $patterns) {
        if ($line -match $pattern.regex) {
          $violations.Add([pscustomobject]@{
              path = $relativePath
              line = $index + 1
              rule = $pattern.name
              text = $line.Trim()
            }) | Out-Null
        }
      }
    }
  }
  return $violations
}

function Invoke-FlutterBuild {
  param([string[]]$Arguments)

  Push-Location $flutterRoot
  try {
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "flutter $($Arguments -join ' ') falhou com exit code $LASTEXITCODE"
    }
  }
  finally {
    Pop-Location
  }
}

function Ensure-NugetCli {
  $existing = Get-Command nuget.exe -ErrorAction SilentlyContinue
  if ($existing) {
    return $existing.Source
  }

  $nugetRoot = Join-Path $repoRoot 'tmp\runtime\tools\nuget'
  $nugetPath = Join-Path $nugetRoot 'nuget.exe'
  if (-not (Test-Path -LiteralPath $nugetPath -PathType Leaf)) {
    New-Item -ItemType Directory -Path $nugetRoot -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetPath
  }

  if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $nugetRoot })) {
    $env:PATH = "$nugetRoot;$env:PATH"
  }
  return $nugetPath
}

function Invoke-RepoCommand {
  param([string[]]$Arguments)
  & $Arguments[0] @($Arguments | Select-Object -Skip 1)
  if ($LASTEXITCODE -ne 0) {
    throw "$($Arguments -join ' ') falhou com exit code $LASTEXITCODE"
  }
}

function Copy-AndroidArtifacts {
  param([string]$ReleaseVersion)

  $releaseRoot = Get-ReleaseRoot -ReleaseVersion $ReleaseVersion
  $apkRoot = Join-Path $flutterRoot 'build\app\outputs\flutter-apk'
  $apks = Get-ChildItem -LiteralPath $apkRoot -Filter 'app-*-release.apk' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'app-release.apk' -and $_.Name -notmatch 'debug' }
  foreach ($apk in $apks) {
    $destination = Join-Path $releaseRoot $apk.Name
    Copy-Item -LiteralPath $apk.FullName -Destination $destination -Force
    Write-ArtifactHash -Path $destination
  }
  return @($apks | ForEach-Object { Join-Path $releaseRoot $_.Name })
}

function Update-ReleasePdf {
  param([string]$ReleaseVersion)

  Invoke-RepoCommand -Arguments @('python', 'scripts\generate_valley_release_links_abnt_pdf.py') | Out-Null
  $sourcePdf = Join-Path $repoRoot 'output\pdf\VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf'
  if (-not (Test-Path -LiteralPath $sourcePdf -PathType Leaf)) {
    throw "PDF de release nao gerado: $sourcePdf"
  }
  $releaseRoot = Get-ReleaseRoot -ReleaseVersion $ReleaseVersion
  $destination = Join-Path $releaseRoot 'VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf'
  Copy-Item -LiteralPath $sourcePdf -Destination $destination -Force
  Write-ArtifactHash -Path $destination
  return $destination
}

function Send-TelegramMessage {
  param([string]$Message)

  $output = & python scripts\valley_communication_bridge.py send-telegram-message --message $Message
  if ($LASTEXITCODE -ne 0) {
    throw "Envio Telegram de mensagem falhou."
  }
  $payload = $output | ConvertFrom-Json
  if (-not $payload.ok) {
    throw "Telegram retornou ok=false para mensagem."
  }
}

function Send-TelegramArtifact {
  param(
    [string]$Path,
    [string]$Caption,
    [string]$PublicUrl = ''
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Artefato nao encontrado para Telegram: $Path"
  }
  $item = Get-Item -LiteralPath $Path
  $maxTelegramDocumentBytes = 49MB
  if ($item.Length -gt $maxTelegramDocumentBytes) {
    if (-not $PublicUrl) {
      throw "Artefato excede limite de upload Telegram e nao tem link publico: $Path"
    }
    $sha256 = Get-ValleyFileHash -Algorithm SHA256 -Path $Path
    Send-TelegramMessage -Message "$Caption`nArquivo maior que o limite seguro de upload do Telegram Bot.`nLink publico: $PublicUrl`nSHA256: $sha256"
    return [pscustomobject]@{
      path = $Path
      delivery = 'telegram_public_link'
      public_url = $PublicUrl
      bytes = $item.Length
    }
  }

  $output = & python scripts\valley_communication_bridge.py send-telegram-document --file $Path --caption $Caption
  if ($LASTEXITCODE -ne 0) {
    throw "Envio Telegram falhou para $Path"
  }
  $payload = $output | ConvertFrom-Json
  if (-not $payload.ok) {
    throw "Telegram retornou ok=false para $Path"
  }
  return [pscustomobject]@{
    path = $Path
    delivery = 'telegram_document'
    public_url = $PublicUrl
    bytes = $item.Length
  }
}

if (-not $Version) {
  $Version = Get-LatestPlanVersion
}
if (-not (Test-Path -LiteralPath $policyPath)) {
  throw "Politica END-USER-BUILD nao encontrada: $policyPath"
}

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add((New-Check -Name 'keyword' -Ok ($policy.keyword -eq 'END-USER-BUILD') -Detail $policy.keyword)) | Out-Null
$checks.Add((New-Check -Name 'mandatory' -Ok ([bool]$policy.mandatory) -Detail "mandatory=$($policy.mandatory)")) | Out-Null
$checks.Add((New-Check -Name 'flutter_root' -Ok (Test-Path -LiteralPath $flutterRoot) -Detail $flutterRoot)) | Out-Null

$repositoryPath = Join-Path $repoRoot 'frontend\flutter\lib\src\data\product_api_repository.dart'
$repositoryText = Get-Content -LiteralPath $repositoryPath -Raw
$checks.Add((New-Check -Name 'end_user_dart_define' -Ok ($repositoryText -match 'VALLEY_END_USER_BUILD') -Detail 'VALLEY_END_USER_BUILD deve controlar fonte primaria de dados')) | Out-Null
$checks.Add((New-Check -Name 'api_first_in_end_user_build' -Ok ($repositoryText -match 'return\s+!_endUserBuild;') -Detail 'END-USER-BUILD nao deve preferir bundle/mock como fonte primaria')) | Out-Null

$violations = @(Find-PatternViolations)
$checks.Add((New-Check -Name 'ui_dev_artifacts' -Ok ($violations.Count -eq 0) -Detail "$($violations.Count) violacoes")) | Out-Null

$releaseDefines = @(
  '--release',
  '--dart-define=VALLEY_END_USER_BUILD=true',
  "--dart-define=VALLEY_PRODUCT_API_BASE_URL=$ApiBaseUrl"
)

$ok = @($checks | Where-Object { -not $_.ok }).Count -eq 0
if (-not $ok) {
  $result = [pscustomobject]@{
    ok = $false
    keyword = 'END-USER-BUILD'
    mode = $Mode
    version = $Version
    command = 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode release-final'
    release_flags = $releaseDefines
    checks = $checks
    violations = $violations
  }
  $result | ConvertTo-Json -Depth 6
  exit 1
}

$generatedArtifacts = [System.Collections.Generic.List[string]]::new()

if ($Mode -in @('build-web', 'release-final')) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\publish_valley_product_web.ps1') -BaseHref '/product/' -ApiBaseUrl $ApiBaseUrl -EndUserBuild
  if ($LASTEXITCODE -ne 0) {
    throw 'Publicacao web END-USER-BUILD falhou.'
  }
}
if ($Mode -in @('build-apk', 'release-final')) {
  $apkArgs = @('build', 'apk', '--split-per-abi') + $releaseDefines
  Invoke-FlutterBuild -Arguments $apkArgs
  foreach ($artifact in Copy-AndroidArtifacts -ReleaseVersion $Version) {
    $generatedArtifacts.Add($artifact) | Out-Null
  }
}
if ($Mode -in @('build-windows', 'build-desktop', 'release-final')) {
  Ensure-NugetCli | Out-Null
  $windowsArgs = @('build', 'windows', '--target', 'lib\merchant_erp_desktop_main.dart') + $releaseDefines
  Invoke-FlutterBuild -Arguments $windowsArgs
}
if ($Mode -in @('build-desktop', 'release-final')) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\package_merchant_erp_single_executables.ps1') -Version $Version -ApiBaseUrl $ApiBaseUrl
  if ($LASTEXITCODE -ne 0) {
    throw 'Pacote Windows/Linux END-USER-BUILD falhou.'
  }
  $releaseRoot = Get-ReleaseRoot -ReleaseVersion $Version
  foreach ($name in @('Valley-ERP.exe', 'Valley-ERP-Linux.run')) {
    $path = Join-Path $releaseRoot $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $generatedArtifacts.Add($path) | Out-Null
    }
  }
}
if ($Mode -in @('update-pdf', 'release-final')) {
  $generatedArtifacts.Add((Update-ReleasePdf -ReleaseVersion $Version)) | Out-Null
}
if ($Mode -in @('send-telegram', 'release-final')) {
  $releaseRoot = Get-ReleaseRoot -ReleaseVersion $Version
  $mandatoryArtifacts = @(
    (Join-Path $releaseRoot 'Valley-ERP.exe'),
    (Join-Path $releaseRoot 'Valley-ERP-Linux.run'),
    (Join-Path $releaseRoot 'app-arm64-v8a-release.apk'),
    (Join-Path $releaseRoot 'VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf')
  )
  foreach ($artifact in $mandatoryArtifacts) {
    $fileName = Split-Path -Leaf $artifact
    $publicUrl = "$ApiBaseUrl/downloads/$Version/$fileName"
    $delivery = Send-TelegramArtifact -Path $artifact -Caption "END-USER-BUILD Valley $Version - $fileName" -PublicUrl $publicUrl
    $generatedArtifacts.Add($artifact) | Out-Null
    $generatedArtifacts.Add(($delivery | ConvertTo-Json -Compress)) | Out-Null
  }
}

$result = [pscustomobject]@{
  ok = $true
  keyword = 'END-USER-BUILD'
  mode = $Mode
  version = $Version
  command = 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode release-final'
  release_flags = $releaseDefines
  checks = $checks
  violations = $violations
  generated_artifacts = @($generatedArtifacts | Select-Object -Unique)
}

New-Item -ItemType Directory -Path (Split-Path -Parent $runtimeStatusPath) -Force | Out-Null
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $runtimeStatusPath -Encoding UTF8
$result | ConvertTo-Json -Depth 8
