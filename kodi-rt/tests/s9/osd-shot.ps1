# kodi-rt: screenshot of the video OSD (the fullscreen button) taken by Kodi itself, from the x64 build tree's files:
# a scratch copy of the x64 kit, windowed 1024x576, JSON-RPC on 127.0.0.1:9090; plays a clip, pauses it, shows the
# OSD, screenshots it. Needs a session with a screen.
# Usage: powershell -NoProfile -File tests\s9\osd-shot.ps1 [-Clip <file>] [-Out <folder>]
param([string]$Clip = 'F:\kodi-rt\build\s0\clips\h264_8bit_320x240.mkv', [string]$Out = 'F:\kodi-rt\build\s9\osd-shots')
$ErrorActionPreference = 'Stop'
$kit = 'F:\kodi-rt\kit\kodi-rt-s9-x64\kodi'
$run = 'F:\kodi-rt\build\s9\osd-run'
foreach ($d in $run, $Out) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
New-Item -ItemType Directory -Force $run, $Out | Out-Null
Copy-Item $kit $run -Recurse
$ud = "$run\kodi\portable_data\userdata"
New-Item -ItemType Directory -Force $ud | Out-Null
Set-Content -Path "$ud\advancedsettings.xml" -Encoding ASCII -Value '<advancedsettings version="1.0"><fullscreen>false</fullscreen><loglevel>1</loglevel></advancedsettings>'
Set-Content -Path "$ud\guisettings.xml" -Encoding UTF8 -Value @"
<settings version="2">
    <setting id="services.esenabled">true</setting>
    <setting id="debug.screenshotpath">$Out\</setting>
    <setting id="videoscreen.screenmode">WINDOW</setting>
    <setting id="lookandfeel.skincolors">violet</setting>
    <setting id="window.width">1024</setting>
    <setting id="window.height">576</setting>
</settings>
"@
$log = "$run\kodi\portable_data\kodi.log"
$kodi = Start-Process -FilePath "$run\kodi\kodi.exe" -ArgumentList '-p' -WorkingDirectory "$run\kodi" -PassThru
$t0 = Get-Date
do { Start-Sleep -Milliseconds 500 } until (((Test-Path $log) -and (Select-String -Path $log -Pattern 'Running the application' -Quiet)) -or ((Get-Date) - $t0).TotalSeconds -gt 60)
Start-Sleep -Seconds 6
$script:id = 0
function Rpc([string]$method, [string]$params = '{}') {
    $script:id++
    $c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', 9090); $s = $c.GetStream()
    $req = [System.Text.Encoding]::UTF8.GetBytes("{`"jsonrpc`":`"2.0`",`"method`":`"$method`",`"params`":$params,`"id`":$script:id}")
    $s.Write($req, 0, $req.Length); $s.ReadTimeout = 5000
    $buf = New-Object byte[] 65536; $n = 0; try { $n = $s.Read($buf, 0, $buf.Length) } catch { }
    $c.Close(); return [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
}
$file = $Clip.Replace('\', '/')
"Player.Open: " + (Rpc 'Player.Open' ('{"item":{"file":"' + $file + '"}}'))
# the test clips are 2 s long: pause as soon as the renderer is configured (the first frame is up)
$t = Get-Date
do { Start-Sleep -Milliseconds 100 } until ((Select-String -Path $log -Pattern 'CRenderManager::Configure - change configuration' -Quiet) -or ((Get-Date) - $t).TotalSeconds -gt 5)
Start-Sleep -Milliseconds 300
"PlayPause: " + (Rpc 'Player.PlayPause' '{"playerid":1,"play":false}')
Start-Sleep -Milliseconds 700
"ShowOSD: " + (Rpc 'Input.ShowOSD')
Start-Sleep -Seconds 2
"screenshot: " + (Rpc 'Input.ExecuteAction' '{"action":"screenshot"}')
Start-Sleep -Seconds 2
Rpc 'Player.Stop' '{"playerid":1}' | Out-Null; Start-Sleep -Seconds 1
Rpc 'Application.Quit' | Out-Null
if (-not $kodi.WaitForExit(30000)) { Stop-Process -Id $kodi.Id -Force; 'killed' } else { "kodi exited, code $($kodi.ExitCode)" }
Get-ChildItem $Out -Filter *.png | ForEach-Object { $_.FullName }
