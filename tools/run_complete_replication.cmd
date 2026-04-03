@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0run_complete_replication.ps1" %*
exit /b %ERRORLEVEL%
