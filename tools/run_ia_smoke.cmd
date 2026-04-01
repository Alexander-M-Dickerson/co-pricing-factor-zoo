@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0run_ia_smoke.ps1" %*
exit /b %ERRORLEVEL%
