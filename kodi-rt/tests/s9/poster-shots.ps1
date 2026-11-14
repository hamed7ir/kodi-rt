# kodi-rt: real Kodi screenshots for the README poster, taken by Kodi itself (its "screenshot" action renders the
# frame to a PNG; nothing of the desktop is captured). A scratch copy of the x64 kit runs portable and windowed
# (1024x576, fits a 1080-wide RDP screen) with JSON-RPC on 127.0.0.1:9090 (services.esenabled) and a screenshot folder; the script opens a few
# windows through JSON-RPC and takes one screenshot each, then quits Kodi. Needs a session with a screen.
# (No System info screen: it shows the machine's IP address.)
# Usage: powershell -NoProfile -File tests\s9\poster-shots.ps1 [-Out F:\kodi-rt\build\s9\poster-shots]
param([string]$Out = 'F:\kodi-rt\build\s9\poster-shots', [string]$Clip = 'F:\kodi-rt\build\s0\clips\letterbox_320x240_bars40.mp4')
$ErrorActionPreference = 'Stop'
$kit = 'F:\kodi-rt\kit\kodi-rt-s9-x64\kodi'
$run = 'F:\kodi-rt\build\s9\poster-run'
foreach ($d in $run, $Out) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
New-Item -ItemType Directory -Force $run, $Out | Out-Null
Copy-Item $kit $run -Recurse
$ud = "$run\kodi\portable_data\userdata"
New-Item -ItemType Directory -Force $ud | Out-Null
Set-Content -Path "$ud\advancedsettings.xml" -Encoding ASCII -Value '<advancedsettings version="1.0"><fullscreen>false</fullscreen></advancedsettings>'
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
"kodi.exe pid $($kodi.Id)"
$t0 = Get-Date
do { Start-Sleep -Milliseconds 500 } until (((Test-Path $log) -and (Select-String -Path $log -Pattern 'Running the application' -Quiet)) -or ((Get-Date) - $t0).TotalSeconds -gt 60)
Start-Sleep -Seconds 8   # the home screen's fade-ins

$id = 0
function Rpc([string]$method, [string]$params = '{}') {
    $script:id++
    $c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', 9090)
    $s = $c.GetStream()
    $req = [System.Text.Encoding]::UTF8.GetBytes("{`"jsonrpc`":`"2.0`",`"method`":`"$method`",`"params`":$params,`"id`":$script:id}")
    $s.Write($req, 0, $req.Length)
    $s.ReadTimeout = 5000
    $buf = New-Object byte[] 65536; $n = 0
    try { $n = $s.Read($buf, 0, $buf.Length) } catch { }
    $c.Close()
    return [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
}
function Shot([string]$name) {
    $before = @(Get-ChildItem $Out -Filter *.png -ErrorAction SilentlyContinue).Count
    Rpc 'Input.ExecuteAction' '{"action":"screenshot"}' | Out-Null
    $t = Get-Date
    do { Start-Sleep -Milliseconds 300 } until (@(Get-ChildItem $Out -Filter *.png).Count -gt $before -or ((Get-Date) - $t).TotalSeconds -gt 10)
    Start-Sleep -Milliseconds 800
    $f = Get-ChildItem $Out -Filter 'screenshot*.png' | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($f) { Rename-Item $f.FullName "$name.png"; "  $name.png" } else { "  ${name}: NO SCREENSHOT" }
}
"JSON-RPC: " + (Rpc 'JSONRPC.Ping')
Shot 'home'
Rpc 'GUI.ActivateWindow' '{"window":"addonbrowser"}' | Out-Null; Start-Sleep -Seconds 3; Shot 'addons'
Rpc 'GUI.ActivateWindow' '{"window":"settings"}' | Out-Null; Start-Sleep -Seconds 3; Shot 'settings'
Rpc 'GUI.ActivateWindow' '{"window":"videos","parameters":["sources://video/"]}' | Out-Null; Start-Sleep -Seconds 3; Shot 'videos'
Rpc 'GUI.ActivateWindow' '{"window":"music"}' | Out-Null; Start-Sleep -Seconds 3; Shot 'music'
Rpc 'GUI.ActivateWindow' '{"window":"home"}' | Out-Null; Start-Sleep -Seconds 2
# playback with the controls up (Estuary's video OSD, with kodi-rt's fullscreen button): open, pause, show the OSD
$file = $Clip.Replace('\', '\\')
Rpc 'Player.Open' ('{"item":{"file":"' + $file + '"}}') | Out-Null; Start-Sleep -Milliseconds 1200
Rpc 'Player.PlayPause' '{"playerid":1,"play":false}' | Out-Null; Start-Sleep -Seconds 1
Rpc 'Input.ShowOSD' | Out-Null; Start-Sleep -Seconds 2; Shot 'videoosd'
Rpc 'Player.Stop' '{"playerid":1}' | Out-Null; Start-Sleep -Seconds 1
Rpc 'Application.Quit' | Out-Null
if (-not $kodi.WaitForExit(30000)) { Stop-Process -Id $kodi.Id -Force; 'killed after 30 s' } else { "kodi exited, code $($kodi.ExitCode)" }
Get-ChildItem $Out -Filter *.png | ForEach-Object { '{0}  {1:N0} KB' -f $_.Name, ($_.Length / 1KB) }
