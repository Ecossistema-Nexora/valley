@echo off
setlocal

set ROOT=%~dp0..
cd /d "%ROOT%" || exit /b 1

npx --yes --package playwright node scripts\whatsapp_web_driver.js login
exit /b %ERRORLEVEL%
