param(
  [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $repoRoot 'config/mcp/VALLEY_MCP_MANIFEST.json'
$genericMcpPath = Join-Path $repoRoot '.mcp.json'
$vscodeMcpPath = Join-Path $repoRoot '.vscode/mcp.json'
$codexConfigPath = Join-Path $repoRoot '.codex/config.toml'
$outputPath = Join-Path $repoRoot 'tmp/runtime/mcp-config-check.json'

$requiredPlatformCapabilities = @('MCP_DOCKER')
$requiredWorkspaceServers = @('context7', 'figma', 'linear', 'playwright', 'terraform')
$requiredAll = @($requiredPlatformCapabilities + $requiredWorkspaceServers)

$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail
  )

  $checks.Add([pscustomobject]@{
      name = $Name
      ok = $Ok
      detail = $Detail
    })
}

function Read-JsonFile {
  param(
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Arquivo obrigatorio nao encontrado: $Path"
  }

  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Has-Property {
  param(
    [object]$Object,
    [string]$Name
  )

  return $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

$manifest = Read-JsonFile -Path $manifestPath
$genericMcp = Read-JsonFile -Path $genericMcpPath
$vscodeMcp = Read-JsonFile -Path $vscodeMcpPath
$codexConfig = if (Test-Path -LiteralPath $codexConfigPath) {
  Get-Content -LiteralPath $codexConfigPath -Raw
}
else {
  ''
}

foreach ($capability in $requiredAll) {
  $declaredRequired = $false
  if (Has-Property -Object $manifest -Name 'mandatory_policy') {
    $declaredRequired = @($manifest.mandatory_policy.required_capabilities) -contains $capability
  }

  Add-Check -Name "manifest.required.$capability" -Ok $declaredRequired -Detail 'capability listed in mandatory_policy.required_capabilities'
}

$dockerOk = (Has-Property -Object $manifest.servers -Name 'docker') -and
  $manifest.servers.docker.mode -eq 'platform-managed' -and
  $manifest.servers.docker.platform_name -eq 'MCP_DOCKER' -and
  $manifest.servers.docker.mandatory -eq $true
Add-Check -Name 'manifest.platform.MCP_DOCKER' -Ok $dockerOk -Detail 'docker server is platform-managed MCP_DOCKER and mandatory'

foreach ($server in $requiredWorkspaceServers) {
  $inManifest = (Has-Property -Object $manifest.servers -Name $server) -and $manifest.servers.$server.mandatory -eq $true
  Add-Check -Name "manifest.server.$server" -Ok $inManifest -Detail 'server exists in manifest and is mandatory'

  $inGeneric = (Has-Property -Object $genericMcp -Name 'mcpServers') -and (Has-Property -Object $genericMcp.mcpServers -Name $server)
  Add-Check -Name ".mcp.json.$server" -Ok $inGeneric -Detail 'server declared in .mcp.json'

  $inVscode = (Has-Property -Object $vscodeMcp -Name 'servers') -and (Has-Property -Object $vscodeMcp.servers -Name $server)
  Add-Check -Name ".vscode/mcp.json.$server" -Ok $inVscode -Detail 'server declared in .vscode/mcp.json'

  $codexPattern = "(?ms)\[mcp_servers\.$([regex]::Escape($server))\]"
  $inCodex = $codexConfig -match $codexPattern
  Add-Check -Name ".codex/config.toml.$server" -Ok $inCodex -Detail 'server declared in Codex local config'
}

$figmaUrlOk = $genericMcp.mcpServers.figma.url -eq 'https://mcp.figma.com/mcp' -and
  $vscodeMcp.servers.figma.url -eq 'https://mcp.figma.com/mcp'
Add-Check -Name 'endpoint.figma' -Ok $figmaUrlOk -Detail 'Figma remote endpoint matches official URL'

$context7UrlOk = ([string]$genericMcp.mcpServers.context7.url).StartsWith('https://mcp.context7.com/mcp') -and
  ([string]$vscodeMcp.servers.context7.url).StartsWith('https://mcp.context7.com/mcp')
Add-Check -Name 'endpoint.context7' -Ok $context7UrlOk -Detail 'Context7 remote endpoint uses official MCP host'

$linearUrlOk = $genericMcp.mcpServers.linear.url -eq 'https://mcp.linear.app/mcp' -and
  $vscodeMcp.servers.linear.url -eq 'https://mcp.linear.app/mcp'
Add-Check -Name 'endpoint.linear' -Ok $linearUrlOk -Detail 'Linear remote endpoint matches official URL'

$genericPlaywrightArgs = @($genericMcp.mcpServers.playwright.args)
$vscodePlaywrightArgs = @($vscodeMcp.servers.playwright.args)
$playwrightCommandOk = $genericMcp.mcpServers.playwright.command -eq 'npx' -and
  $vscodeMcp.servers.playwright.command -eq 'npx' -and
  $genericPlaywrightArgs -contains '@playwright/mcp@latest' -and
  $vscodePlaywrightArgs -contains '@playwright/mcp@latest' -and
  $genericPlaywrightArgs -contains '--user-data-dir=tmp/runtime/playwright-mcp-profile' -and
  $vscodePlaywrightArgs -contains '--user-data-dir=tmp/runtime/playwright-mcp-profile' -and
  $genericPlaywrightArgs -contains '--output-dir=tmp/runtime/playwright-mcp' -and
  $vscodePlaywrightArgs -contains '--output-dir=tmp/runtime/playwright-mcp'
Add-Check -Name 'command.playwright' -Ok $playwrightCommandOk -Detail 'Playwright MCP uses npx @playwright/mcp@latest with ignored tmp/runtime persistence'

$genericTerraformArgs = @($genericMcp.mcpServers.terraform.args)
$vscodeTerraformArgs = @($vscodeMcp.servers.terraform.args)
$terraformCommandOk = $genericMcp.mcpServers.terraform.command -eq 'powershell' -and
  $vscodeMcp.servers.terraform.command -eq 'powershell' -and
  $vscodeMcp.servers.terraform.type -eq 'stdio' -and
  $genericTerraformArgs -contains 'scripts/start_terraform_mcp_server.ps1' -and
  $vscodeTerraformArgs -contains 'scripts/start_terraform_mcp_server.ps1' -and
  (Has-Property -Object $manifest.servers -Name 'terraform') -and
  $manifest.servers.terraform.mandatory -eq $true -and
  $manifest.servers.terraform.transport -eq 'stdio'
Add-Check -Name 'command.terraform' -Ok $terraformCommandOk -Detail 'Terraform MCP uses local stdio wrapper with no repo-stored token'

$secretLeakPatterns = @(
  'ctx7sk_[A-Za-z0-9_-]+',
  'figd_[A-Za-z0-9_-]+',
  'lin_api_[A-Za-z0-9_-]+',
  'ghp_[A-Za-z0-9_]+'
)

$configText = @(
  Get-Content -LiteralPath $genericMcpPath -Raw
  Get-Content -LiteralPath $vscodeMcpPath -Raw
  Get-Content -LiteralPath $manifestPath -Raw
  $codexConfig
) -join "`n"

foreach ($pattern in $secretLeakPatterns) {
  $secretFree = $configText -notmatch $pattern
  Add-Check -Name "secret_scan.$pattern" -Ok $secretFree -Detail 'no concrete token pattern found in MCP config files'
}

$allOk = -not ($checks | Where-Object { -not $_.ok })
$result = [pscustomobject]@{
  ok = $allOk
  checked_at = [DateTime]::UtcNow.ToString('o')
  required_capabilities = $requiredAll
  checks = $checks
}

if (-not $NoWrite) {
  $outputDir = Split-Path -Parent $outputPath
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
  $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
}

$result | ConvertTo-Json -Depth 6

if (-not $allOk) {
  exit 1
}
