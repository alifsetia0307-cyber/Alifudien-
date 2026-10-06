<#
  Morning English Alarm (Windows)
  1. Bangunkan layar + tahan laptop agar tidak tidur lagi
  2. Volume dinaikkan, alarm berbunyi terus
  3. Alarm hanya mati kalau kamu MENGETIK kalimat bahasa Inggris (anti snooze setengah sadar)
  4. YouTube (BBC / latihan English) langsung diputar
  Dijalankan otomatis oleh Task Scheduler (lihat install.ps1). Tes manual: test-now.bat
#>
param(
    [int]$AlarmVolume       = 100,  # % volume saat alarm
    [int]$VideoVolume       = 70,   # % volume saat video
    [int]$MaxAlarmMinutes   = 15,   # kalau tidak dimatikan, alarm berhenti & video tetap diputar
    [int]$StayAwakeMinutes  = 90    # laptop dijaga tetap menyala selama ini
)

$ErrorActionPreference = 'Continue'
$AppDir   = Join-Path $env:LOCALAPPDATA 'MorningEnglish'
$Sources  = Join-Path $PSScriptRoot 'sources.txt'
if (-not (Test-Path $Sources)) { $Sources = Join-Path $PSScriptRoot '..\sources.txt' }
$LogFile  = Join-Path $AppDir 'log.txt'
$Streak   = Join-Path $AppDir 'streak.txt'
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null

function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Add-Content -Path $LogFile }
Log '=== Morning English started ==='

# ---------------------------------------------------------------- Win32 helpers
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Power {
    [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);
    // ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED | ES_AWAYMODE_REQUIRED
    public static void KeepAwake() { SetThreadExecutionState(0x80000000 | 0x00000001 | 0x00000002 | 0x00000040); }
    public static void Release()   { SetThreadExecutionState(0x80000000); }

    [DllImport("user32.dll")] static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
    // Nudge the mouse so Windows turns the screen on after a wake timer.
    public static void WakeScreen() { mouse_event(0x0001, 1, 0, 0, UIntPtr.Zero); mouse_event(0x0001, -1, 0, 0, UIntPtr.Zero); }
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown), ComImport]
interface IAudioEndpointVolume {
    int f(); int g(); int h(); int i();
    int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
    int j();
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int k(); int l(); int m(); int n();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
    int GetMute(out bool pbMute);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown), ComImport]
interface IMMDevice { int Activate(ref Guid id, int clsCtx, IntPtr activationParams, out IAudioEndpointVolume aev); }
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown), ComImport]
interface IMMDeviceEnumerator { int f(); int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint); }
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }

public static class Audio {
    static IAudioEndpointVolume Vol() {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDevice dev;
        Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out dev));
        IAudioEndpointVolume epv;
        Guid id = typeof(IAudioEndpointVolume).GUID;
        Marshal.ThrowExceptionForHR(dev.Activate(ref id, 23, IntPtr.Zero, out epv));
        return epv;
    }
    public static void Set(int percent) {
        var v = Vol();
        Marshal.ThrowExceptionForHR(v.SetMute(false, Guid.Empty));
        Marshal.ThrowExceptionForHR(v.SetMasterVolumeLevelScalar(Math.Max(0, Math.Min(100, percent)) / 100f, Guid.Empty));
    }
}
'@

function Set-Volume([int]$percent) {
    try { [Audio]::Set($percent); Log "Volume -> $percent%" }
    catch {
        # Fallback: tekan tombol volume-up berkali-kali
        Log "Core Audio failed ($_), using volume keys"
        $sh = New-Object -ComObject WScript.Shell
        1..50 | ForEach-Object { $sh.SendKeys([char]175) }
    }
}

# ---------------------------------------------------------------- pilih video
function Get-TodaySource {
    $lines = Get-Content $Sources -ErrorAction SilentlyContinue |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') }
    if (-not $lines) { return @{ Name = 'BBC Learning English'; Url = 'https://www.youtube.com/@bbclearningenglish/videos' } }
    $line  = @($lines)[(Get-Date).DayOfYear % @($lines).Count]
    $parts = $line -split '\|', 2
    if ($parts.Count -lt 2) { return @{ Name = 'English'; Url = $parts[0].Trim() } }
    return @{ Name = $parts[0].Trim(); Url = $parts[1].Trim() }
}

function Resolve-VideoUrl($src) {
    if ($src.Url -match '/watch\?|youtu\.be/|/live') { return $src.Url }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $html = (Invoke-WebRequest -Uri $src.Url -UseBasicParsing -TimeoutSec 20 `
                 -Headers @{ 'Accept-Language' = 'en-US,en' }).Content
        if ($html -match '"videoId":"([\w-]{11})"') {
            return "https://www.youtube.com/watch?v=$($Matches[1])"
        }
    } catch { Log "Could not fetch $($src.Url): $_" }
    # Fallback: hasil pencarian YouTube
    return 'https://www.youtube.com/results?search_query=' + [uri]::EscapeDataString($src.Name)
}

function Open-Video($url) {
    $profileDir = Join-Path $AppDir 'browser'
    $browserArgs = @("--user-data-dir=`"$profileDir`"", '--autoplay-policy=no-user-gesture-required',
              '--no-first-run', '--start-maximized', '--new-window', $url)
    $candidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )
    $browser = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if ($browser) { Start-Process -FilePath $browser -ArgumentList $browserArgs; Log "Opened $url in $browser" }
    else          { Start-Process $url; Log "Opened $url in default browser" }
}

# ---------------------------------------------------------------- streak (motivasi)
function Update-Streak {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $days  = @(Get-Content $Streak -ErrorAction SilentlyContinue)
    if ($days -notcontains $today) { Add-Content $Streak $today; $days += $today }
    $set = [System.Collections.Generic.HashSet[string]]::new([string[]]$days)
    $n = 0; $d = Get-Date
    while ($set.Contains($d.ToString('yyyy-MM-dd'))) { $n++; $d = $d.AddDays(-1) }
    return $n
}

# ---------------------------------------------------------------- alarm
$Sentences = @(
    'I am awake and ready to learn English',
    'Today I will speak English with confidence',
    'Small steps every morning build a strong habit',
    'I choose discipline over comfort today',
    'My future self will thank me for this morning'
)
$Target = $Sentences[(Get-Date).DayOfYear % $Sentences.Count]

function Find-AlarmSound {
    $media = Join-Path $env:WINDIR 'Media'
    foreach ($f in 'Alarm01.wav','Alarm03.wav','Alarm05.wav','Ring06.wav','Windows Notify System Generic.wav') {
        $p = Join-Path $media $f; if (Test-Path $p) { return $p }
    }
    return $null
}

[Power]::KeepAwake()
[Power]::WakeScreen()
Set-Volume $AlarmVolume

# Resolve the video while the alarm is ringing (network may need a few seconds after wake)
$source = Get-TodaySource
Log "Today's source: $($source.Name) $($source.Url)"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$player = $null
$sound  = Find-AlarmSound
if ($sound) { $player = New-Object System.Media.SoundPlayer $sound; $player.PlayLooping() }

$form = New-Object Windows.Forms.Form -Property @{
    Text = 'Morning English'; WindowState = 'Maximized'; FormBorderStyle = 'None'
    TopMost = $true; BackColor = [Drawing.Color]::FromArgb(18, 18, 28); KeyPreview = $true
}
$layout = New-Object Windows.Forms.FlowLayoutPanel -Property @{
    Dock = 'Fill'; FlowDirection = 'TopDown'; WrapContents = $false; Padding = '80,80,80,80'
}
function New-Label($text, $size, $color) {
    New-Object Windows.Forms.Label -Property @{
        Text = $text; AutoSize = $true; ForeColor = $color; Margin = '0,0,0,24'
        Font = New-Object Drawing.Font('Segoe UI', $size, [Drawing.FontStyle]::Bold)
    }
}
$white = [Drawing.Color]::White; $gold = [Drawing.Color]::FromArgb(255, 200, 60); $grey = [Drawing.Color]::FromArgb(170, 170, 190)
$layout.Controls.Add((New-Label "GOOD MORNING! It's $(Get-Date -Format 'HH:mm')" 40 $white))
$layout.Controls.Add((New-Label "Type this sentence to stop the alarm:" 20 $grey))
$layout.Controls.Add((New-Label $Target 30 $gold))
$box = New-Object Windows.Forms.TextBox -Property @{
    Width = 1100; Font = New-Object Drawing.Font('Segoe UI', 26)
}
$layout.Controls.Add($box)
$hint = New-Label "Next: $($source.Name) on YouTube" 16 $grey
$layout.Controls.Add($hint)
$form.Controls.Add($layout)

$normalize = { param($s) ($s -replace '[^a-zA-Z ]', '' -replace '\s+', ' ').Trim().ToLower() }
$box.Add_TextChanged({
    if ((& $normalize $box.Text) -eq (& $normalize $Target)) { $form.Tag = 'dismissed'; $form.Close() }
})
# Ignore Alt+F4 / Esc: the only way out is typing the sentence (or the timeout)
$form.Add_FormClosing({ param($s, $e) if (-not $form.Tag) { $e.Cancel = $true } })

$timeout = New-Object Windows.Forms.Timer -Property @{ Interval = $MaxAlarmMinutes * 60 * 1000 }
$timeout.Add_Tick({ $form.Tag = 'timeout'; $form.Close() })
$timeout.Start()
# Keep the alarm window in front and the screen on
$keepFront = New-Object Windows.Forms.Timer -Property @{ Interval = 5000 }
$keepFront.Add_Tick({ $form.Activate(); $box.Focus() | Out-Null; [Power]::WakeScreen() })
$keepFront.Start()

$form.Add_Shown({ $form.Activate(); $box.Focus() | Out-Null })
[void]$form.ShowDialog()
$timeout.Stop(); $keepFront.Stop()
if ($player) { $player.Stop() }
Log "Alarm closed: $($form.Tag)"

# ---------------------------------------------------------------- video
Set-Volume $VideoVolume
$url = Resolve-VideoUrl $source
Open-Video $url

if ($form.Tag -eq 'dismissed') {
    $n = Update-Streak
    Log "Streak: $n day(s)"
    $msg = "Nice! Streak: $n day(s) in a row.`n`nNow: $($source.Name).`nListen, then repeat 3 sentences out loud."
    $popup = New-Object -ComObject WScript.Shell
    [void]$popup.Popup($msg, 8, 'Morning English', 64)
}

# Hold the laptop awake while you watch/listen, then let Windows manage power again
Start-Sleep -Seconds ($StayAwakeMinutes * 60)
[Power]::Release()
Log '=== Morning English finished ==='
