@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0legacy-v2.2\Restore.ps1" -Mode Restore
pause
