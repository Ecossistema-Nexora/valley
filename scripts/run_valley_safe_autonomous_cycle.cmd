@echo off
setlocal
set ROOT=%~dp0..
cd /d "%ROOT%" || exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\run_valley_safe_autonomous_cycle.ps1" %*
exit /b %ERRORLEVEL%
