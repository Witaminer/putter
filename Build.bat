@echo off
REM Build Putter.exe using Windows PowerShell 5.1 and ps2exe.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build.ps1"

echo.
if errorlevel 1 (
    echo Build failed.
) else (
    echo Build finished successfully.
)

echo.
pause