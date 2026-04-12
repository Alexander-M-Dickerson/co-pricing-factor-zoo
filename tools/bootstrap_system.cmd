@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0bootstrap_system.ps1" %*
exit /b %ERRORLEVEL%
