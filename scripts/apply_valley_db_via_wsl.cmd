@echo off
setlocal
set ROOT=%~dp0..
cd /d "%ROOT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\apply_valley_db_via_wsl.ps1" %*
