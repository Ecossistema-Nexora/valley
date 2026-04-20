#requires -RunAsAdministrator
<#
Enables the mandatory local virtualization stack for Valley:
- Hyper-V platform and management tools when available on this Windows edition.
- Windows Subsystem for Linux and Virtual Machine Platform.
- Windows Hypervisor Platform and Containers.
- Boot hypervisor launch set to Auto.
- WSL default version set to 2.
- Core virtualization services set to Automatic.
- Docker Desktop forced to auto-start at sign-in.

Run from an elevated PowerShell session:
  powershell -ExecutionPolicy Bypass -File .\scripts\enable_windows_virtualization.ps1
#>

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[Valley virtualization] $Message"
}

function Get-AvailableServiceName {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if (Get-Service -Name $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    return $null
}

function Enable-FeatureIfAvailable {
    param([string]$Name)

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
        if ($feature.State -eq 'Enabled') {
            Write-Step "$Name already enabled."
            return
        }

        Write-Step "Enabling $Name..."
        Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart -ErrorAction Stop | Out-Null
        Write-Step "$Name enabled; reboot may be required."
    }
    catch {
        Write-Warning "$Name could not be enabled on this edition/session: $($_.Exception.Message)"
    }
}

function Get-DockerSettingsPath {
    $settingsCandidates = @(
        (Join-Path $env:APPDATA 'Docker\settings-store.json'),
        (Join-Path $env:APPDATA 'Docker\settings.json')
    )

    foreach ($candidate in $settingsCandidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Enable-DockerAutoStart {
    param([string]$DockerDesktopPath)

    $settingsPath = Get-DockerSettingsPath
    if ($settingsPath) {
        Write-Step "Persisting Docker Desktop settings in $settingsPath..."
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

        $settings | Add-Member -NotePropertyName AutoStart -NotePropertyValue $true -Force
        $settings | Add-Member -NotePropertyName EnableIntegrationWithDefaultWslDistro -NotePropertyValue $true -Force

        $settings |
            ConvertTo-Json -Depth 100 |
            Set-Content -Path $settingsPath -Encoding utf8
    }
    else {
        Write-Warning 'Docker settings file not found; skipping JSON persistence.'
    }

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $runValue = '"' + $DockerDesktopPath + '"'

    Write-Step 'Writing Docker Desktop startup entry for the current user...'
    New-Item -Path $runKey -Force | Out-Null
    Set-ItemProperty -Path $runKey -Name 'Docker Desktop' -Value $runValue -Type String
}

$features = @(
    'Microsoft-Windows-Subsystem-Linux',
    'VirtualMachinePlatform',
    'Microsoft-Hyper-V-All',
    'Microsoft-Hyper-V',
    'Microsoft-Hyper-V-Management-Clients',
    'HypervisorPlatform',
    'Containers'
)

foreach ($feature in $features) {
    Enable-FeatureIfAvailable -Name $feature
}

Write-Step 'Setting hypervisorlaunchtype to Auto...'
bcdedit /set hypervisorlaunchtype auto | Out-Host

Write-Step 'Setting WSL default version to 2...'
wsl --set-default-version 2 | Out-Host

Write-Step 'Updating WSL kernel/runtime...'
wsl --update | Out-Host

$wslService = Get-AvailableServiceName -Candidates @('WslService', 'LxssManager')
$services = @('vmcompute', 'hns', 'com.docker.service')
if ($wslService) {
    $services = @($wslService) + $services
}

foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Warning "Service $serviceName not found; skipping."
        continue
    }

    Write-Step "Setting service $serviceName to Automatic..."
    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop

    if ($service.Status -ne 'Running') {
        Write-Step "Starting service $serviceName..."
        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
    }
}

Write-Step 'Stopping WSL so .wslconfig and feature changes are picked up on next start...'
wsl --shutdown | Out-Host

$dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
if (Test-Path $dockerDesktop) {
    Enable-DockerAutoStart -DockerDesktopPath $dockerDesktop

    Write-Step 'Starting Docker Desktop...'
    Start-Process -FilePath $dockerDesktop
}
else {
    Write-Warning 'Docker Desktop executable not found under Program Files.'
}

Write-Step 'Final feature snapshot:'
foreach ($feature in $features) {
    try {
        Get-WindowsOptionalFeature -Online -FeatureName $feature |
            Select-Object FeatureName, State |
            Format-Table -AutoSize
    }
    catch {
        Write-Warning "Could not read ${feature}: $($_.Exception.Message)"
    }
}

Write-Step 'Current boot hypervisor setting:'
bcdedit /enum '{current}' | Select-String -Pattern 'hypervisorlaunchtype|identifier|description' | Out-Host

Write-Step 'Done. Reboot Windows if any feature was enabled or if Docker still reports virtualization unavailable.'
