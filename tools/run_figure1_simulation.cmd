@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0run_figure1_simulation.ps1" %*
exit /b %ERRORLEVEL%
