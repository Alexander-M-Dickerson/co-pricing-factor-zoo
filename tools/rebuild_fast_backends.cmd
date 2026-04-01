@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0rebuild_fast_backends.ps1" %*
exit /b %ERRORLEVEL%
