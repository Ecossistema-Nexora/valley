@echo off
setlocal
set ROOT=%~dp0..
cd /d "%ROOT%"
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT%\scripts\ensure_valley_product_public.ps1" -Watch
