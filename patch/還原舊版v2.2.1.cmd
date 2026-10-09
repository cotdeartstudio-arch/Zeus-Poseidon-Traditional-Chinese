@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0legacy-v2.2.1\Restore.ps1" -Mode Restore
pause
