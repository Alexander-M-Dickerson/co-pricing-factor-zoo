@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0run_full_replication.ps1" %*
exit /b %ERRORLEVEL%
