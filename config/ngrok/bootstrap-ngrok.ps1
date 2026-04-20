param(
    [switch]$InstallIfMissing
)

$ngrokCommand = Get-Command ngrok -ErrorAction SilentlyContinue

if (-not $ngrokCommand) {
    if (-not $InstallIfMissing) {
        Write-Error "ngrok nao encontrado. Rode com -InstallIfMissing ou instale com: winget install --id Ngrok.Ngrok -e"
        exit 1
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget nao encontrado. Instale ngrok manualmente e execute este bootstrap novamente."
        exit 1
    }

    winget install --id Ngrok.Ngrok -e --accept-source-agreements --accept-package-agreements
    $ngrokCommand = Get-Command ngrok -ErrorAction SilentlyContinue

    if (-not $ngrokCommand) {
        Write-Error "ngrok continua indisponivel apos a tentativa de instalacao."
        exit 1
    }
}

Write-Output ("ngrok binario: {0}" -f $ngrokCommand.Source)
& $ngrokCommand.Source version

$globalConfig = Join-Path $env:LOCALAPPDATA "ngrok\\ngrok.yml"
if (Test-Path $globalConfig) {
    Write-Output ("config global detectada em: {0}" -f $globalConfig)
} else {
    Write-Output "config global ausente. Rode: ngrok config add-authtoken <SEU_TOKEN>"
}

Write-Output "config do workspace: config/ngrok/valley-ngrok.yml"
Write-Output "template release: config/ngrok/valley-ngrok.release.example.yml"
