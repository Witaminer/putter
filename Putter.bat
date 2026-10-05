@echo off
REM Prefer PowerShell 7.x when available.
REM Fall back to Windows PowerShell 5.1.

where pwsh.exe >nul 2>&1
if not errorlevel 1 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Putter.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Putter.ps1"
)
