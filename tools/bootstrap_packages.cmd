@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0bootstrap_packages.ps1" %*
exit /b %ERRORLEVEL%
