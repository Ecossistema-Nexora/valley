param(
  [switch]$InstallExtensions = $true,
  [switch]$InstallOptionalTools = $false
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $root 'config/tooling.bootstrap.json'
$logPath = Join-Path $root 'tmp/tooling-bootstrap.json'

if (-not (Test-Path $manifestPath)) {
  throw "Manifesto de tooling nao encontrado: $manifestPath"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
  param(
    [string]$Name,
    [string]$Kind,
    [string]$Status,
    [string]$Detail
  )

  $results.Add([pscustomobject]@{
      name = $Name
      kind = $Kind
      status = $Status
      detail = $Detail
      timestamp = [DateTime]::UtcNow.ToString('o')
    })
}

function Configure-GitRepositoryBinding {
  param(
    [object]$Binding
  )

  if ($null -eq $Binding) {
    Add-Result -Name 'github-repository-binding' -Kind 'git' -Status 'skipped' -Detail 'binding nao declarado no manifesto'
    return
  }

  $gitCommand = Get-Command git -ErrorAction SilentlyContinue

  if ($null -eq $gitCommand) {
    Add-Result -Name 'github-repository-binding' -Kind 'git' -Status 'missing' -Detail 'git nao encontrado no PATH'
    return
  }

  try {
    $isGitWorkTree = (& $gitCommand.Source -C $root rev-parse --is-inside-work-tree 2>$null).Trim()
  }
  catch {
    $isGitWorkTree = ''
  }

  if ($isGitWorkTree -ne 'true') {
    Add-Result -Name 'github-repository-binding' -Kind 'git' -Status 'skipped' -Detail 'workspace nao esta em um git worktree'
    return
  }

  $remoteName = if ($Binding.remote_name) { [string]$Binding.remote_name } else { 'origin' }
  $fetchUrl = [string]$Binding.fetch_url
  $pushUrl = if ($Binding.push_url) { [string]$Binding.push_url } else { $fetchUrl }

  if ([string]::IsNullOrWhiteSpace($fetchUrl)) {
    Add-Result -Name 'github-repository-binding' -Kind 'git' -Status 'failed' -Detail 'fetch_url vazio no manifesto'
    return
  }

  try {
    $existingFetchUrl = (& $gitCommand.Source -C $root remote get-url $remoteName 2>$null).Trim()
  }
  catch {
    $existingFetchUrl = ''
  }

  if ([string]::IsNullOrWhiteSpace($existingFetchUrl)) {
    & $gitCommand.Source -C $root remote add $remoteName $fetchUrl | Out-Null
  }
  elseif ($existingFetchUrl -ne $fetchUrl) {
    & $gitCommand.Source -C $root remote set-url $remoteName $fetchUrl | Out-Null
  }

  try {
    $existingPushUrl = (& $gitCommand.Source -C $root remote get-url --push $remoteName 2>$null).Trim()
  }
  catch {
    $existingPushUrl = ''
  }

  if ($existingPushUrl -ne $pushUrl) {
    & $gitCommand.Source -C $root remote set-url --push $remoteName $pushUrl | Out-Null
  }

  Add-Result -Name 'github-repository-binding' -Kind 'git' -Status 'ok' -Detail ("{0} -> {1}" -f $remoteName, $fetchUrl)
}

foreach ($tool in $manifest.host_tools) {
  if ($tool.type -eq 'command') {
    $command = Get-Command $tool.name -ErrorAction SilentlyContinue
    if ($null -ne $command) {
      Add-Result -Name $tool.name -Kind 'command' -Status 'ok' -Detail $command.Source
    }
    else {
      Add-Result -Name $tool.name -Kind 'command' -Status 'missing' -Detail 'nao encontrado no PATH'
    }
  }
}

Configure-GitRepositoryBinding -Binding $manifest.github_repository_binding

if ($InstallExtensions) {
  $codeCommand = Get-Command code -ErrorAction SilentlyContinue

  if ($null -eq $codeCommand) {
    Add-Result -Name 'vscode-extensions' -Kind 'extension' -Status 'skipped' -Detail 'CLI code nao encontrada'
  }
  else {
    foreach ($extensionId in $manifest.workspace_extensions) {
      try {
        & $codeCommand.Source --install-extension $extensionId --force | Out-Null
        Add-Result -Name $extensionId -Kind 'extension' -Status 'ok' -Detail 'instalada ou atualizada'
      }
      catch {
        Add-Result -Name $extensionId -Kind 'extension' -Status 'failed' -Detail $_.Exception.Message
      }
    }
  }
}

if ($InstallOptionalTools) {
  $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue

  if ($null -eq $wingetCommand) {
    Add-Result -Name 'winget' -Kind 'package-manager' -Status 'skipped' -Detail 'winget nao encontrado'
  }
  else {
    foreach ($tool in $manifest.host_tools | Where-Object { $_.type -eq 'winget' }) {
      try {
        & $wingetCommand.Source install --id $tool.id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity --silent | Out-Null
        Add-Result -Name $tool.name -Kind 'winget' -Status 'ok' -Detail $tool.id
      }
      catch {
        Add-Result -Name $tool.name -Kind 'winget' -Status 'failed' -Detail $_.Exception.Message
      }
    }
  }
}

$results | ConvertTo-Json -Depth 6 | Set-Content -Path $logPath -Encoding UTF8
Write-Output $logPath
