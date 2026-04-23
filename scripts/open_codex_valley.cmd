@echo off
setlocal
set "REPO_ROOT=%~dp0.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
codex -C "%REPO_ROOT%" %*
exit /b %ERRORLEVEL%
