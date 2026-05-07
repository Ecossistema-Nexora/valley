param(
    [int]$ApiPort = 8085
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $RepoRoot 'tmp\runtime'
$ApiOutLog = Join-Path $RuntimeDir 'valley-product-api.win.out.log'
$ApiErrLog = Join-Path $RuntimeDir 'valley-product-api.win.err.log'
$RuntimeManifest = Join-Path $RuntimeDir 'valley-product-public-runtime.json'
$AdminManifest = Join-Path $RuntimeDir 'valley-admin-public-runtime.json'
$PublicationManifest = Join-Path $RuntimeDir 'valley-product-web-publication.json'
$ServeScript = Join-Path $RepoRoot 'scripts\serve_valley_admin.py'

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Get-TailscaleIp {
    $Ip = (& tailscale ip -4 2>$null | Select-Object -First 1).Trim()
    if (-not $Ip) {
        throw 'Tailscale IP nao encontrado. Verifique se o Tailscale esta logado e conectado.'
    }
    return $Ip
}

function Stop-PortOwner {
    param([int]$Port)
    $Lines = cmd /c "netstat -ano | findstr :$Port"
    foreach ($Line in $Lines) {
        if ($Line -match 'LISTENING\s+(\d+)$') {
            $PidToStop = [int]$Matches[1]
            if ($PidToStop -gt 0 -and $PidToStop -ne $PID) {
                Stop-Process -Id $PidToStop -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Test-Health {
    param([string]$BaseUrl)
    try {
        $Response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Uri "$BaseUrl/healthz"
        return $Response.StatusCode -eq 200 -and $Response.Content.Contains('"service": "valley-admin"')
    } catch {
        return $false
    }
}

$TailscaleIp = Get-TailscaleIp
$LocalBaseUrl = "http://127.0.0.1:$ApiPort"
$TailnetBaseUrl = "http://$TailscaleIp`:$ApiPort"

if (-not (Test-Health -BaseUrl $TailnetBaseUrl)) {
    Stop-PortOwner -Port $ApiPort
    Start-Process `
        -FilePath python `
        -ArgumentList @('-u', $ServeScript, '--host', '0.0.0.0', '--port', $ApiPort.ToString()) `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $ApiOutLog `
        -RedirectStandardError $ApiErrLog `
        -WindowStyle Hidden | Out-Null

    $Deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 1
        if (Test-Health -BaseUrl $TailnetBaseUrl) {
            break
        }
    } while ((Get-Date) -lt $Deadline)
}

if (-not (Test-Health -BaseUrl $TailnetBaseUrl)) {
    throw "Runtime Tailscale nao ficou saudavel em $TailnetBaseUrl. Consulte $ApiErrLog"
}

$GeneratedAt = (Get-Date).ToString('o')
$ProductUrl = "$TailnetBaseUrl/product"
$ProductApiUrl = "$TailnetBaseUrl/api/product-shell"

$RuntimePayload = [ordered]@{
    status = 'ok'
    service = 'valley-product-public'
    provider = 'tailscale'
    public_url = $ProductUrl
    public_api_url = $ProductApiUrl
    local_api_url = "$LocalBaseUrl/api/product-shell"
    generated_at = $GeneratedAt
    temporary = $false
    provider_status = 'healthy'
    persistence = 'Windows Startup fallback via Tailscale IP'
    requires_tailscale = $true
}

$AdminPayload = [ordered]@{
    status = 'ok'
    service = 'valley-admin-public'
    provider = 'tailscale'
    public_url = $TailnetBaseUrl
    local_url = $LocalBaseUrl
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    temporary = $false
    provider_status = 'healthy'
    requires_tailscale = $true
}

$PublicationPayload = [ordered]@{
    status = 'published'
    provider = 'tailscale'
    public_url = $ProductUrl
    api_url = $ProductApiUrl
    generated_at = $GeneratedAt
    temporary = $false
    provider_status = 'healthy'
    requires_tailscale = $true
}

$RuntimePayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $RuntimeManifest -Encoding UTF8
$AdminPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $AdminManifest -Encoding UTF8
$PublicationPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $PublicationManifest -Encoding UTF8

Write-Host "Valley Tailscale runtime ativo: $ProductUrl"
