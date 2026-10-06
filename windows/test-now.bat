@echo off
rem Tes alarm sekarang juga (tanpa menunggu jam 3)
schtasks /Run /TN MorningEnglish >nul 2>&1 || powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0MorningEnglish.ps1" -StayAwakeMinutes 0
