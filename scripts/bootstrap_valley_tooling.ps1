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

function Get-EditorCommands {
  param(
    [object]$Manifest
  )

  $editorNames = @('code')
  if ($Manifest.PSObject.Properties.Name -contains 'editor_clis' -and $null -ne $Manifest.editor_clis) {
    $editorNames = @($Manifest.editor_clis | ForEach-Object { [string]$_ })
  }

  $editorCommands = [System.Collections.Generic.List[object]]::new()
  foreach ($editorName in $editorNames) {
    $editorCommand = Get-Command $editorName -ErrorAction SilentlyContinue
    if ($null -eq $editorCommand) {
      Add-Result -Name $editorName -Kind 'editor-cli' -Status 'missing' -Detail 'nao encontrado no PATH'
      continue
    }

    $extensionsDir = $null
    switch ($editorName.ToLowerInvariant()) {
      'code' {
        $extensionsDir = Join-Path $env:USERPROFILE '.vscode\extensions'
      }
      'antigravity' {
        $extensionsDir = Join-Path $env:USERPROFILE '.antigravity\extensions'
      }
    }

    if ($extensionsDir) {
      New-Item -ItemType Directory -Force $extensionsDir | Out-Null
      Add-Result -Name $editorName -Kind 'editor-cli' -Status 'ok' -Detail ("{0} | extensions -> {1}" -f $editorCommand.Source, $extensionsDir)
    }
    else {
      Add-Result -Name $editorName -Kind 'editor-cli' -Status 'ok' -Detail $editorCommand.Source
    }

    $editorCommands.Add([pscustomobject]@{
        Name = $editorName
        Source = $editorCommand.Source
        CommandArguments = @()
        ExtensionsDirectory = $extensionsDir
      })
  }

  return $editorCommands
}

function Get-InstalledExtensions {
  param(
    [object]$Editor
  )

  try {
    $rawOutput = & $Editor.Source @($Editor.CommandArguments + '--list-extensions') 2>$null
  }
  catch {
    return @()
  }

  return @(
    $rawOutput |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ -match '^[A-Za-z0-9._-]+$' } |
      ForEach-Object { $_.Trim().ToLowerInvariant() }
  )
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
  $editorCommands = Get-EditorCommands -Manifest $manifest

  if ($editorCommands.Count -eq 0) {
    Add-Result -Name 'workspace-extensions' -Kind 'extension' -Status 'skipped' -Detail 'nenhum editor CLI encontrado'
  }
  else {
    foreach ($editor in $editorCommands) {
      foreach ($extensionId in $manifest.workspace_extensions) {
        $normalizedExtensionId = $extensionId.ToLowerInvariant()
        try {
          $installOutput = (& $editor.Source @($editor.CommandArguments + '--install-extension', $extensionId, '--force') 2>&1 | Out-String).Trim()
          $installedExtensions = Get-InstalledExtensions -Editor $editor

          if ($installedExtensions -contains $normalizedExtensionId) {
            Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'ok' -Detail 'instalada ou atualizada'
          }
          else {
            $detail = if ([string]::IsNullOrWhiteSpace($installOutput)) { 'nao confirmada na lista instalada' } else { $installOutput }
            Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'failed' -Detail $detail
          }
        }
        catch {
          Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'failed' -Detail $_.Exception.Message
        }
      }

      if ($manifest.PSObject.Properties.Name -contains 'workspace_unwanted_extensions' -and $null -ne $manifest.workspace_unwanted_extensions) {
        foreach ($extensionId in $manifest.workspace_unwanted_extensions) {
          $normalizedExtensionId = $extensionId.ToLowerInvariant()
          try {
            $uninstallOutput = (& $editor.Source @($editor.CommandArguments + '--uninstall-extension', $extensionId) 2>&1 | Out-String).Trim()
            $installedExtensions = Get-InstalledExtensions -Editor $editor
            $removedStaleDirs = $false

            if ($editor.ExtensionsDirectory) {
              $staleExtensionDirs = Get-ChildItem -LiteralPath $editor.ExtensionsDirectory -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$extensionId-*" }
              foreach ($staleExtensionDir in $staleExtensionDirs) {
                try {
                  Remove-Item -LiteralPath $staleExtensionDir.FullName -Recurse -Force
                  $removedStaleDirs = $true
                }
                catch {
                  Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension-cleanup' -Status 'failed' -Detail ("falha ao remover pasta residual: {0}" -f $staleExtensionDir.FullName)
                }
              }
            }

            if ($installedExtensions -notcontains $normalizedExtensionId) {
              if ($uninstallOutput -match 'not installed|is not installed|nao esta instalada|is not installed in') {
                $detail = if ($removedStaleDirs) { 'nao instalada e pasta residual removida' } else { 'nao instalada' }
                Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'skipped' -Detail $detail
              }
              else {
                $detail = if ($removedStaleDirs) { 'removida e pasta residual limpa' } else { 'removida' }
                Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'ok' -Detail $detail
              }
            }
            else {
              Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'failed' -Detail $uninstallOutput
            }
          }
          catch {
            Add-Result -Name ("{0}:{1}" -f $editor.Name, $extensionId) -Kind 'extension' -Status 'failed' -Detail $_.Exception.Message
          }
        }
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
