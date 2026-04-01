@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0run_conditional_smoke.ps1" %*
exit /b %ERRORLEVEL%
