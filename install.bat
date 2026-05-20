@echo off
setlocal

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  ERROR: This installer must be run as Administrator.
    echo  Right-click install.bat and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

set DEFAULT_DIR=C:\Winpharm
set /p INSTALL_DIR="Installation directory [%DEFAULT_DIR%]: "
if "%INSTALL_DIR%"=="" set INSTALL_DIR=%DEFAULT_DIR%

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -InstallDir "%INSTALL_DIR%"
pause
