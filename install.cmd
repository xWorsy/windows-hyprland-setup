@echo off
rem Double-click to install. Runs install.ps1 with script execution allowed for this run only.
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
