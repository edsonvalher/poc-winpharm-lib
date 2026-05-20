@echo off
setlocal

set DEFAULT_DIR=C:\Winpharm
set /p INSTALL_DIR="Installation directory [%DEFAULT_DIR%]: "
if "%INSTALL_DIR%"=="" set INSTALL_DIR=%DEFAULT_DIR%

if "%GH_TOKEN%"=="" set /p GH_TOKEN="GitHub token (leave blank for public repos): "

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -InstallDir "%INSTALL_DIR%" -Token "%GH_TOKEN%"
pause
