@echo off
setlocal

set ROOT=%~dp0..
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT%\scripts\start_valley_communication_bridge.ps1" -IntervalSeconds 30
