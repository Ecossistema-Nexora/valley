@echo off
setlocal EnableExtensions

python "%~dp0psql_wrapper.py" %*
exit /b %ERRORLEVEL%
