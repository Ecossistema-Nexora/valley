param(
    [string]$Distro = '',
    [string]$User = 'root'
)

$ErrorActionPreference = 'Stop'

function Convert-ToWslPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $normalized = $Path -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):/(.*)$') {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2]
        return "/mnt/$drive/$rest"
    }
    return $normalized
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$envFile = Join-Path $root '.env'

if (Test-Path -LiteralPath $envFile) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') {
            continue
        }
        $index = $line.IndexOf('=')
        $key = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim().Trim('"').Trim("'")
        if (-not [string]::IsNullOrWhiteSpace($key) -and [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($key, 'Process'))) {
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

$script = Join-Path $root 'scripts/start_tailscale_wsl.sh'
$wslRoot = Convert-ToWslPath -Path $root
$wslScript = Convert-ToWslPath -Path $script
$wslArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Distro)) {
    $wslArgs += @('-d', $Distro)
}
if (-not [string]::IsNullOrWhiteSpace($User)) {
    $wslArgs += @('-u', $User)
}
$wslArgs += @('--cd', $wslRoot, '-e', 'bash', $wslScript)

wsl @wslArgs
