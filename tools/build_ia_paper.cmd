@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0build_ia_paper.ps1" %*
exit /b %ERRORLEVEL%
