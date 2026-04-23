@echo off
setlocal

set ROOT=%~dp0..
set RUNTIME=%ROOT%\tmp\runtime
set LOG=%RUNTIME%\communication-bridge.log

if not exist "%RUNTIME%" mkdir "%RUNTIME%"

start "ValleyCommunicationBridge" /min cmd /d /c "cd /d "%ROOT%" && python scripts\valley_communication_bridge.py watch --interval 30 >> "%LOG%" 2>>&1"
echo Bridge iniciado em background. Log=%LOG%
