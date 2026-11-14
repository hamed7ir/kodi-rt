# kodi-rt Stage 9: smoke test of an x64/x86 kit on this server (Windows Server 2022, no GPU: Direct3D 11 on WARP).
# Copies the kit's kodi folder to a scratch folder, runs kodi.exe -p (portable: data in portable_data) WINDOWED
# (advancedsettings <fullscreen>false</fullscreen>) with a small clip on the command line, lets it play, closes the
# window (WM_CLOSE, Kodi's normal exit), and reads portable_data\kodi.log: version, Python, the clip opening, the
# video decoder, errors, and whether Kodi shut down cleanly.
# Usage: powershell -NoProfile -File tests\s9\smoke-kodi.ps1 -Arch x64 [-Clip <file>] [-Seconds 25]
param(
    [ValidateSet('x64', 'x86')][string]$Arch = 'x64',
    [string]$Clip = 'F:\kodi-rt\build\s0\clips\h264_8bit_320x240.mkv',
    [int]$Seconds = 25
)
$ErrorActionPreference = 'Stop'
$kit = "F:\kodi-rt\kit\kodi-rt-s9-$Arch\kodi"
$run = "F:\kodi-rt\build\s9\smoke-$Arch"
if (-not (Test-Path "$kit\kodi.exe")) { throw "no $kit\kodi.exe (scripts/s9-package-kit.sh $Arch)" }
if (-not (Test-Path $Clip)) { throw "no $Clip" }
if (Test-Path $run) { Remove-Item $run -Recurse -Force }
New-Item -ItemType Directory -Force $run | Out-Null
Copy-Item $kit $run -Recurse
$ud = "$run\kodi\portable_data\userdata"
New-Item -ItemType Directory -Force $ud | Out-Null
Set-Content -Path "$ud\advancedsettings.xml" -Encoding ASCII -Value '<advancedsettings version="1.0"><fullscreen>false</fullscreen><loglevel>1</loglevel></advancedsettings>'

$t0 = Get-Date
$p = Start-Process -FilePath "$run\kodi\kodi.exe" -ArgumentList @('-p', "`"$Clip`"") -WorkingDirectory "$run\kodi" -PassThru
"started kodi.exe ($Arch) pid $($p.Id); playing $Clip for $Seconds s"
Start-Sleep -Seconds $Seconds
$p.Refresh()
if ($p.HasExited) {
    "kodi exited early, code $($p.ExitCode)"
} else {
    $null = $p.CloseMainWindow()
    if (-not $p.WaitForExit(30000)) { "no exit 30 s after WM_CLOSE: killing pid $($p.Id)"; Stop-Process -Id $p.Id -Force }
    else { "exited after WM_CLOSE, code $($p.ExitCode), $([int]((Get-Date) - $t0).TotalSeconds) s in all" }
}
$log = "$run\kodi\portable_data\kodi.log"
if (-not (Test-Path $log)) { throw "no kodi.log in $run\kodi\portable_data" }
$L = Get-Content $log
"kodi.log: $($L.Count) lines"
$pat = 'Starting Kodi|Platform:|Running on|Host CPU|Desktop Resolution|Direct3D|feature level|Adapter|Python|VideoPlayer::OpenFile|Creating video codec|CDVDVideoCodecFFmpeg::Open|ffmpeg\[|Closing stream player|application stopped|Stopped|Exiting|Shutdown|Error|exception'
$L | Select-String -Pattern $pat | Select-Object -First 60 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(200, $_.Line.Length)) }
"errors: $(($L | Select-String -Pattern ' error <' ).Count)   warnings: $(($L | Select-String -Pattern ' warning <').Count)"
