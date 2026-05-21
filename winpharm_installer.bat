@echo off
setlocal

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  ERROR: This installer must be run as Administrator.
    echo  Right-click winpharm_installer.bat and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

set DEFAULT_DIR=C:\Winpharm
set /p INSTALL_DIR="Installation directory [%DEFAULT_DIR%]: "
if "%INSTALL_DIR%"=="" set INSTALL_DIR=%DEFAULT_DIR%

if "%GH_TOKEN%"=="" set /p GH_TOKEN="GitHub token: "

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0winpharm_installer.ps1" -InstallDir "%INSTALL_DIR%" -Token "%GH_TOKEN%"
pause
