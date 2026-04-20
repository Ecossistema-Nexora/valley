param(
    [switch]$InstallIfMissing
)

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$EnvExamplePath = Join-Path $RepoRoot '.env.example'
$ReleaseEnvExamplePath = Join-Path $RepoRoot 'config\VALLEY_RELEASE_ENV.example'
$EnvPath = Join-Path $RepoRoot '.env'

function Parse-EnvFile {
    param(
        [string]$Path
    )

    $Values = @{}

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Values
    }

    foreach ($RawLine in Get-Content -LiteralPath $Path) {
        $Line = $RawLine.Trim()

        if (-not $Line -or $Line.StartsWith('#') -or -not $Line.Contains('=')) {
            continue
        }

        $Key, $Value = $Line.Split('=', 2)
        $Key = $Key.Trim()
        $Value = $Value.Trim().Trim('"').Trim("'")

        if ($Key) {
            $Values[$Key] = $Value
        }
    }

    return $Values
}

function Import-ValleyEnv {
    param(
        [string[]]$Paths
    )

    $LoadedSources = @{}

    foreach ($Path in $Paths) {
        foreach ($Entry in (Parse-EnvFile -Path $Path).GetEnumerator()) {
            $CurrentValue = [Environment]::GetEnvironmentVariable($Entry.Key, 'Process')
            $CanOverride = $LoadedSources.ContainsKey($Entry.Key)

            if ([string]::IsNullOrWhiteSpace($CurrentValue) -or $CanOverride) {
                [Environment]::SetEnvironmentVariable($Entry.Key, $Entry.Value, 'Process')
                $LoadedSources[$Entry.Key] = Split-Path -Leaf $Path
            }
        }
    }

    return $LoadedSources
}

Import-ValleyEnv -Paths @($EnvExamplePath, $ReleaseEnvExamplePath, $EnvPath) | Out-Null

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
if ($env:VALLEY_NGROK_AUTHTOKEN -or $env:NGROK_AUTHTOKEN) {
    $tokenSource = if ($env:VALLEY_NGROK_AUTHTOKEN) { 'VALLEY_NGROK_AUTHTOKEN' } else { 'NGROK_AUTHTOKEN' }
    Write-Output ("authtoken carregado do ambiente local ({0})." -f $tokenSource)
} elseif (Test-Path $globalConfig) {
    Write-Output ("config global detectada em: {0}" -f $globalConfig)
} else {
    Write-Output "authtoken ausente. Defina VALLEY_NGROK_AUTHTOKEN no .env ou rode: ngrok config add-authtoken <SEU_TOKEN>"
}

Write-Output "config do workspace: config/ngrok/valley-ngrok.yml"
Write-Output "template release: config/ngrok/valley-ngrok.release.example.yml"
