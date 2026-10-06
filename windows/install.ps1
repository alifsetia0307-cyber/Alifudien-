<#
  Pasang alarm Morning English di Windows.
  - Menyalin script ke %LOCALAPPDATA%\MorningEnglish
  - Membuat jadwal Task Scheduler setiap hari jam 03:00 dengan "Wake the computer to run this task"
  - Mengaktifkan "wake timers" di power plan (butuh Administrator, otomatis minta izin)
  Cara pakai: klik dua kali INSTALL.bat   (atau: powershell -ExecutionPolicy Bypass -File install.ps1 -Time 03:00)
#>
param(
    [string]$Time = '03:00',
    [string]$User = "$env:USERDOMAIN\$env:USERNAME",
    [string]$AppDir = (Join-Path $env:LOCALAPPDATA 'MorningEnglish')
)
$ErrorActionPreference = 'Stop'
$TaskName = 'MorningEnglish'

# Re-run as Administrator (needed for powercfg), keeping the real user + folder
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Meminta izin Administrator...'
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
        '-Time', $Time, '-User', "`"$User`"", '-AppDir', "`"$AppDir`"")
    exit
}

# 1. Copy files
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'MorningEnglish.ps1') $AppDir -Force
$srcList = Join-Path $AppDir 'sources.txt'
if (-not (Test-Path $srcList)) { Copy-Item (Join-Path $PSScriptRoot '..\sources.txt') $srcList }
Write-Host "File disalin ke $AppDir"

# 2. Allow wake timers (plugged in + on battery)
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
Write-Host 'Wake timers diaktifkan.'

# 3. Scheduled task
$script  = Join-Path $AppDir 'MorningEnglish.ps1'
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
           -Argument "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At ([datetime]::ParseExact($Time, 'HH:mm', $null))
$settings = New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description 'Alarm + YouTube English practice every morning' -Force | Out-Null

Write-Host ''
Write-Host "SELESAI. Alarm Morning English aktif setiap hari jam $Time untuk $User." -ForegroundColor Green
Write-Host 'Penting: sebelum tidur, pilih Start > Power > SLEEP (jangan Shut down), dan colokkan charger.'
Write-Host 'Tes sekarang: klik dua kali test-now.bat'
Read-Host 'Tekan Enter untuk menutup'
