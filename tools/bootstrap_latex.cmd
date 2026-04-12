@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0bootstrap_latex.ps1" %*
exit /b %ERRORLEVEL%
