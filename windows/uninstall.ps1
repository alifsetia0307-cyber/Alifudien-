# Hapus alarm Morning English (jadwal + file). Klik dua kali UNINSTALL.bat
Unregister-ScheduledTask -TaskName 'MorningEnglish' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA 'MorningEnglish') -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'Alarm Morning English sudah dihapus.'
Read-Host 'Tekan Enter untuk menutup'
