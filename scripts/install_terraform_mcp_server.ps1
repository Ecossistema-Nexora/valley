<#
PROPOSITO: Instalar localmente o binario oficial Terraform MCP Server.

CONTEXTO: O workspace Valley usa MCPs persistentes para ferramentas de engenharia.
O Terraform MCP deve ficar disponivel sem gravar token HCP/TFE no repositorio.

REGRAS: Baixar apenas do release oficial da HashiCorp, instalar em tmp/runtime
ignorado pelo git, nao imprimir segredos e manter operacoes destrutivas
desativadas por padrao.
#>

param(
  [string]$Version = '',
  [string]$InstallDir = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$ToolsDir = if ($InstallDir) { $InstallDir } else { Join-Path $RuntimeDir 'tools' }
$DownloadsDir = Join-Path $RuntimeDir 'downloads'
$StatusPath = Join-Path $RuntimeDir 'terraform-mcp-server-status.json'

New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Index = Invoke-RestMethod -Uri 'https://releases.hashicorp.com/terraform-mcp-server/index.json' -TimeoutSec 45
  $Version = @($Index.versions.PSObject.Properties.Name |
    Where-Object { $_ -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_ } -Descending |
    Select-Object -First 1)[0]
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  throw 'Nao foi possivel resolver a versao do Terraform MCP Server.'
}

$ArchiveName = "terraform-mcp-server_${Version}_windows_amd64.zip"
$ArchiveUrl = "https://releases.hashicorp.com/terraform-mcp-server/$Version/$ArchiveName"
$ArchivePath = Join-Path $DownloadsDir $ArchiveName
$ExtractDir = Join-Path $DownloadsDir "terraform-mcp-server_$Version"
$BinaryPath = Join-Path $ToolsDir 'terraform-mcp-server.exe'

Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath -TimeoutSec 120
if (Test-Path -LiteralPath $ExtractDir) {
  Remove-Item -LiteralPath $ExtractDir -Recurse -Force
}
Expand-Archive -LiteralPath $ArchivePath -DestinationPath $ExtractDir -Force

$DownloadedBinary = Get-ChildItem -LiteralPath $ExtractDir -Recurse -Filter 'terraform-mcp-server.exe' |
  Select-Object -First 1
if (-not $DownloadedBinary) {
  throw "Binario terraform-mcp-server.exe nao encontrado em $ArchivePath"
}
Copy-Item -LiteralPath $DownloadedBinary.FullName -Destination $BinaryPath -Force

$HelpOutput = & $BinaryPath --help 2>&1 | Select-Object -First 20
$Payload = [ordered]@{
  status = 'installed'
  installed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
  version = $Version
  binary = $BinaryPath
  source_url = $ArchiveUrl
  terraform_cli = (Get-Command terraform -ErrorAction SilentlyContinue | Select-Object -First 1).Source
  secret_policy = 'TFE_TOKEN/TFE_ADDRESS somente em ambiente local; nao versionar.'
  destructive_operations = 'disabled_by_default'
  help_head = @($HelpOutput)
}
$Payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatusPath -Encoding UTF8
$Payload | ConvertTo-Json -Depth 5
