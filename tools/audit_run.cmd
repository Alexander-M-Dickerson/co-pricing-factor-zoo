@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0audit_run.ps1" %*
exit /b %ERRORLEVEL%
