@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0build_paper.ps1" %*
exit /b %ERRORLEVEL%
