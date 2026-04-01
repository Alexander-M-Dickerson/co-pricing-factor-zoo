@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0doctor.ps1" %*
exit /b %ERRORLEVEL%
