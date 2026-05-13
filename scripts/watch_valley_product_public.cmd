@echo off
setlocal
set ROOT=%~dp0..
cd /d "%ROOT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\ensure_valley_product_public.ps1" -Watch -ReplaceStale
