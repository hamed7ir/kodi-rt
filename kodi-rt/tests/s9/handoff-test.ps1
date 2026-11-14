# kodi-rt: test of the "Open with" hand-off (reports/proposed-edits/openwith-running-instance.py) on this server:
# start Kodi from a scratch copy of the kit (portable, windowed, no file), then start a second kodi.exe with a clip;
# the second must exit by itself, and the first must play the clip ("playing 1 file(s) from another kodi.exe" and
# VideoPlayer::OpenFile in its log). Then the first is closed with WM_CLOSE. Needs a session with a screen.
# Usage: powershell -NoProfile -File tests\s9\handoff-test.ps1 -Arch x64|x86|arm32kit [-Clip <file>]
param(
    [ValidateSet('x64', 'x86')][string]$Arch = 'x64',
    [string]$Clip = 'F:\kodi-rt\build\s0\clips\h264_8bit_320x240.mkv'
)
$ErrorActionPreference = 'Stop'
$kit = "F:\kodi-rt\kit\kodi-rt-s9-$Arch\kodi"
$run = "F:\kodi-rt\build\s9\handoff-$Arch"
if (Test-Path $run) { Remove-Item $run -Recurse -Force }
New-Item -ItemType Directory -Force $run | Out-Null
Copy-Item $kit $run -Recurse
$ud = "$run\kodi\portable_data\userdata"
New-Item -ItemType Directory -Force $ud | Out-Null
Set-Content -Path "$ud\advancedsettings.xml" -Encoding ASCII -Value '<advancedsettings version="1.0"><fullscreen>false</fullscreen><loglevel>1</loglevel></advancedsettings>'
$exe = "$run\kodi\kodi.exe"; $log = "$run\kodi\portable_data\kodi.log"

$first = Start-Process -FilePath $exe -ArgumentList '-p' -WorkingDirectory "$run\kodi" -PassThru
"first kodi.exe ($Arch) pid $($first.Id), no file"
$t0 = Get-Date
do { Start-Sleep -Milliseconds 500 } until (((Test-Path $log) -and (Select-String -Path $log -Pattern 'Running the application' -Quiet)) -or ((Get-Date) - $t0).TotalSeconds -gt 40)
"first is running ($([int]((Get-Date) - $t0).TotalSeconds) s)"
Start-Sleep -Seconds 3

$second = Start-Process -FilePath $exe -ArgumentList @('-p', "`"$Clip`"") -WorkingDirectory "$run\kodi" -PassThru
$quit = $second.WaitForExit(15000)
"second kodi.exe pid $($second.Id): " + $(if ($quit) { "exited by itself, code $($second.ExitCode)" } else { 'STILL RUNNING after 15 s' })
Start-Sleep -Seconds 6
$handed = Select-String -Path $log -Pattern 'playing \d+ file\(s\) from another kodi.exe' | Select-Object -First 1
$opened = Select-String -Path $log -Pattern ('VideoPlayer::OpenFile: ' + [regex]::Escape($Clip)) | Select-Object -First 1
"hand-off logged:  " + $(if ($handed) { $handed.Line.Substring(24) } else { 'NO' })
"clip opened:      " + $(if ($opened) { $opened.Line.Substring(24) } else { 'NO' })

$null = $first.CloseMainWindow()
if (-not $first.WaitForExit(30000)) { Stop-Process -Id $first.Id -Force; "first killed after 30 s" } else { "first exited after WM_CLOSE, code $($first.ExitCode)" }
if (-not $quit) { Stop-Process -Id $second.Id -Force -ErrorAction SilentlyContinue }
if ($quit -and $handed -and $opened) { 'HANDOFF OK' } else { 'HANDOFF FAILED' }
