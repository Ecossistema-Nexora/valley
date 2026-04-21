@echo off
setlocal EnableExtensions

python "%~dp0mongosh_wrapper.py" %*
exit /b %ERRORLEVEL%
