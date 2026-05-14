# PROPOSITO: Automatizar check valley brand terms no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/check_valley_brand_terms.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param(
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$forbiddenPatterns = @(
  @{ name = 'Nexora'; pattern = '(?i)nexora' },
  @{ name = 'persona'; pattern = '(?i)\bpersona\b|persona_mode|owner_persona|cross_persona_allowed|persona_separation|chat_persona_enum' },
  @{ name = '$NEX'; pattern = '\$NEX' },
  @{ name = 'Nexus-ID'; pattern = 'Nexus-ID' },
  @{ name = 'Nexora Pay'; pattern = 'Nexora Pay' }
)

$excludedPathPatterns = @(
  '\\.git\\',
  '\\tmp\\',
  '\\PLANOS\\',
  '\\.dart_tool\\',
  '\\config\\brand\\VALLEY_BRAND_TERMS\.json$',
  '\\config\\github\\',
  '\\config\\VALLEY_RELEASE_ENV\.example$',
  '\\config\\tooling\.bootstrap\.json$',
  '\\config\\mcp\\',
  '\\admin\\product\\main\.dart\.js$',
  '\\scripts\\check_valley_brand_terms\.ps1$',
  '\\scripts\\setup_github_actions_runner\.ps1$',
  '\\output\\pdf\\.*\.pdf$',
  '\\frontend\\flutter\\build\\',
  '\\node_modules\\'
)

$allowedLinePatterns = @(
  'Ecossistema-Nexora/valley',
  'github\.com/Ecossistema-Nexora/valley',
  'This Codex project is persistently bound to the GitHub repository Ecossistema-Nexora/valley',
  'origin remote https://github\.com/Ecossistema-Nexora/valley\.git',
  'Do not introduce product references to Nexora, persona, Nexus-ID, Nexora Pay, or \$NEX',
  'The only accepted Nexora string is the technical GitHub repository owner'
)

$extensions = @(
  '.cfg',
  '.cmd',
  '.css',
  '.dart',
  '.example',
  '.html',
  '.js',
  '.json',
  '.md',
  '.mongo.js',
  '.ps1',
  '.py',
  '.sql',
  '.toml',
  '.txt',
  '.yaml',
  '.yml'
)

function Test-ExcludedPath {
  param([string]$Path)

  $normalized = $Path.Replace('/', '\')
  foreach ($pattern in $excludedPathPatterns) {
    if ($normalized -match $pattern) {
      return $true
    }
  }
  return $false
}

function Test-AllowedLine {
  param([string]$Line)

  foreach ($pattern in $allowedLinePatterns) {
    if ($Line -match $pattern) {
      return $true
    }
  }
  return $false
}

function Get-RepoRelativePath {
  param([string]$Path)

  $normalizedRoot = $repoRoot.TrimEnd('\', '/')
  if ($Path.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $Path.Substring($normalizedRoot.Length).TrimStart('\', '/')
  }
  return $Path
}

$violations = [System.Collections.Generic.List[object]]::new()

function Get-TrackedFiles {
  $trackedPaths = @()
  try {
    $trackedPaths = & git -C $repoRoot ls-files 2>$null
  }
  catch {
    $trackedPaths = @()
  }

  if ($LASTEXITCODE -ne 0 -or -not $trackedPaths) {
    return $null
  }

  $items = [System.Collections.Generic.List[object]]::new()
  foreach ($trackedPath in $trackedPaths) {
    try {
      $fullPath = Join-Path $repoRoot $trackedPath
      if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        $items.Add((Get-Item -LiteralPath $fullPath)) | Out-Null
      }
    }
    catch {
      continue
    }
  }

  return $items
}

$files = Get-TrackedFiles
if ($null -eq $files) {
  $files = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force
}

$files = $files |
  Where-Object {
    -not (Test-ExcludedPath -Path $_.FullName) -and
    ($extensions -contains $_.Extension -or $_.Name.EndsWith('.mongo.js'))
  }

foreach ($file in $files) {
  try {
    $lines = Get-Content -LiteralPath $file.FullName -ErrorAction Stop
  }
  catch {
    continue
  }

  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = [string]$lines[$index]
    if (Test-AllowedLine -Line $line) {
      continue
    }

    foreach ($entry in $forbiddenPatterns) {
      if ($line -match $entry.pattern) {
        $relativePath = Get-RepoRelativePath -Path $file.FullName
        $violations.Add([pscustomobject]@{
            path = $relativePath
            line = $index + 1
            term = $entry.name
            text = $line.Trim()
          }) | Out-Null
      }
    }
  }
}

$result = [pscustomobject]@{
  ok = $violations.Count -eq 0
  checked_at = [DateTime]::UtcNow.ToString('o')
  canonical_terms = [pscustomobject]@{
    ecosystem = 'Valley'
    assistant = 'Helena'
    token = 'V-Coin'
  }
  matches = $violations
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
}
else {
  if ($violations.Count -eq 0) {
    Write-Output 'ok=true'
  }
  else {
    $violations | Format-Table -AutoSize
  }
}

if ($violations.Count -gt 0) {
  exit 1
}
