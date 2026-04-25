@echo off
setlocal

set ROOT=%~dp0..
cd /d "%ROOT%" || exit /b 1

python scripts\valley_communication_bridge.py whatsapp-login
exit /b %ERRORLEVEL%
