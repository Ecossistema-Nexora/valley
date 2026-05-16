param(
    [switch]$Quiet,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

function New-ValleyShortcut {
    param(
        [Parameter(Mandatory = $true)][string]$ShortcutPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [string]$Arguments = ""
    )

    $parent = Split-Path -Parent $ShortcutPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Arguments = $Arguments
    $shortcut.IconLocation = "$TargetPath,0"
    $shortcut.Description = "Valley"
    $shortcut.Save()
}

function Try-PinValleyTaskbar {
    param([Parameter(Mandatory = $true)][string]$ShortcutPath)

    try {
        $shell = New-Object -ComObject Shell.Application
        $folderPath = Split-Path -Parent $ShortcutPath
        $leaf = Split-Path -Leaf $ShortcutPath
        $folder = $shell.Namespace($folderPath)
        if ($null -eq $folder) {
            return $false
        }
        $item = $folder.ParseName($leaf)
        if ($null -eq $item) {
            return $false
        }

        foreach ($verb in $item.Verbs()) {
            $name = ($verb.Name -replace "&", "").Trim()
            if ($name -match "Pin to taskbar|Fixar na barra de tarefas|Fixar na Barra de Tarefas|Fixar na barra") {
                $verb.DoIt()
                Start-Sleep -Milliseconds 500
                return $true
            }
        }
    } catch {
        return $false
    }

    return $false
}

$bundlePath = Join-Path $PSScriptRoot "valley_super_app_windows_bundle.zip"
if (-not (Test-Path -LiteralPath $bundlePath)) {
    throw "Bundle nao encontrado: $bundlePath"
}

$valleyRoot = Join-Path $env:LOCALAPPDATA "Valley"
$installRoot = Join-Path $valleyRoot "ValleySuperApp"
$safeBase = [System.IO.Path]::GetFullPath($valleyRoot)
$safeTarget = [System.IO.Path]::GetFullPath($installRoot)

if (-not $safeTarget.StartsWith($safeBase, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destino de instalacao invalido: $safeTarget"
}

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
Get-ChildItem -LiteralPath $installRoot -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Expand-Archive -LiteralPath $bundlePath -DestinationPath $installRoot -Force

$exePath = Join-Path $installRoot "valley_super_app.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Executavel Valley nao encontrado apos extracao: $exePath"
}

$startMenuShortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Valley\Valley.lnk"
$startupShortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\Valley.lnk"
$taskbarShortcut = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Valley.lnk"

New-ValleyShortcut -ShortcutPath $startMenuShortcut -TargetPath $exePath -WorkingDirectory $installRoot
New-ValleyShortcut -ShortcutPath $startupShortcut -TargetPath $exePath -WorkingDirectory $installRoot
New-ValleyShortcut -ShortcutPath $taskbarShortcut -TargetPath $exePath -WorkingDirectory $installRoot

$taskbarPinned = Try-PinValleyTaskbar -ShortcutPath $taskbarShortcut

$status = [ordered]@{
    installed_at = (Get-Date).ToString("o")
    app_name = "Valley"
    install_root = $installRoot
    exe_path = $exePath
    start_menu_shortcut = $startMenuShortcut
    startup_shortcut = $startupShortcut
    taskbar_shortcut = $taskbarShortcut
    taskbar_pin_attempted = $true
    taskbar_pin_confirmed_by_shell_verb = $taskbarPinned
    launch_requested = (-not $NoLaunch.IsPresent)
}

$statusPath = Join-Path $installRoot "install-status.json"
$status | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statusPath -Encoding UTF8

if (-not $NoLaunch.IsPresent) {
    Start-Process -FilePath $exePath -WorkingDirectory $installRoot
}

if (-not $Quiet.IsPresent) {
    Write-Host "Valley instalado em: $installRoot"
    Write-Host "Menu Iniciar: $startMenuShortcut"
    Write-Host "Inicio automatico: $startupShortcut"
    Write-Host "Barra de tarefas: $taskbarShortcut"
}

