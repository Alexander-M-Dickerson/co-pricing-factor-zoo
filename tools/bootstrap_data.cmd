@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0bootstrap_data.ps1" %*
exit /b %ERRORLEVEL%
