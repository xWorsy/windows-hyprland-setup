@echo off
rem Double-click to uninstall. Runs uninstall.ps1 with script execution allowed for this run only.
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
echo.
pause
