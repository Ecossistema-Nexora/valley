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

$matches = [System.Collections.Generic.List[object]]::new()

$files = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force |
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
        $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName)
        $matches.Add([pscustomobject]@{
            path = $relativePath
            line = $index + 1
            term = $entry.name
            text = $line.Trim()
          })
      }
    }
  }
}

$result = [pscustomobject]@{
  ok = $matches.Count -eq 0
  checked_at = [DateTime]::UtcNow.ToString('o')
  canonical_terms = [pscustomobject]@{
    ecosystem = 'Valley'
    assistant = 'Helena'
    token = 'V-Coin'
  }
  matches = $matches
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
}
else {
  if ($matches.Count -eq 0) {
    Write-Output 'ok=true'
  }
  else {
    $matches | Format-Table -AutoSize
  }
}

if ($matches.Count -gt 0) {
  exit 1
}
