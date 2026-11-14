# kodi-rt: ctypes, pycryptodome and Pillow inside Kodi, on an x64/x86 kit on this server. Copies the kit's kodi folder
# to a scratch folder, adds the test add-on tests\s9\modtest\script.kodirt.modtest (it requires
# script.module.pycryptodome and script.module.pil, like real add-ons), starts kodi.exe -p windowed with JSON-RPC on
# 127.0.0.1:9090, enables and runs the add-on, waits for portable_data\modtest-result.json, prints it and the add-on's
# kodi.log lines, then quits Kodi. Exit code 0 when every check passed.
# Usage: powershell -NoProfile -File tests\s9\addon-modules-test.ps1 -Arch x64
param([ValidateSet('x64', 'x86')][string]$Arch = 'x64', [int]$Timeout = 120)
$ErrorActionPreference = 'Stop'
$kit = "F:\kodi-rt\kit\kodi-rt-s9-$Arch\kodi"
$run = "F:\kodi-rt\build\s9\modtest-$Arch"
$addon = 'F:\kodi-rt\tests\s9\modtest\script.kodirt.modtest'
if (-not (Test-Path "$kit\kodi.exe")) { throw "no $kit\kodi.exe (scripts/s9-package-kit.sh $Arch)" }
if (Test-Path $run) { Remove-Item $run -Recurse -Force }
New-Item -ItemType Directory -Force $run | Out-Null
Copy-Item $kit $run -Recurse
$pd = "$run\kodi\portable_data"
New-Item -ItemType Directory -Force "$pd\userdata", "$pd\addons" | Out-Null
Copy-Item $addon "$pd\addons" -Recurse
Set-Content -Path "$pd\userdata\advancedsettings.xml" -Encoding ASCII -Value '<advancedsettings version="1.0"><fullscreen>false</fullscreen><loglevel>1</loglevel></advancedsettings>'
Set-Content -Path "$pd\userdata\guisettings.xml" -Encoding UTF8 -Value @"
<settings version="2">
    <setting id="services.esenabled">true</setting>
    <setting id="videoscreen.screenmode">WINDOW</setting>
    <setting id="window.width">1024</setting>
    <setting id="window.height">576</setting>
</settings>
"@
$log = "$pd\kodi.log"
$result = "$pd\modtest-result.json"
$kodi = Start-Process -FilePath "$run\kodi\kodi.exe" -ArgumentList '-p' -WorkingDirectory "$run\kodi" -PassThru
"kodi.exe ($Arch) started, pid $($kodi.Id)"
$t0 = Get-Date
do { Start-Sleep -Milliseconds 500 } until (((Test-Path $log) -and (Select-String -Path $log -Pattern 'Running the application' -Quiet)) -or ((Get-Date) - $t0).TotalSeconds -gt 90)
Start-Sleep -Seconds 5
$script:id = 0
function Rpc([string]$method, [string]$params = '{}') {
    $script:id++
    $c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', 9090); $s = $c.GetStream()
    $req = [System.Text.Encoding]::UTF8.GetBytes("{`"jsonrpc`":`"2.0`",`"method`":`"$method`",`"params`":$params,`"id`":$script:id}")
    $s.Write($req, 0, $req.Length); $s.ReadTimeout = 15000
    $buf = New-Object byte[] 65536; $n = 0; try { $n = $s.Read($buf, 0, $buf.Length) } catch { }
    $c.Close(); return [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
}
"SetAddonEnabled: " + (Rpc 'Addons.SetAddonEnabled' '{"addonid":"script.kodirt.modtest","enabled":true}')
Start-Sleep -Seconds 2
"ExecuteAddon: " + (Rpc 'Addons.ExecuteAddon' '{"addonid":"script.kodirt.modtest"}')
$t = Get-Date
do { Start-Sleep -Milliseconds 500 } until ((Test-Path $result) -or ((Get-Date) - $t).TotalSeconds -gt $Timeout)
Start-Sleep -Seconds 1
$ok = $false
if (Test-Path $result) {
    $j = Get-Content $result -Raw
    $j
    $ok = (ConvertFrom-Json $j).all_ok
} else { "NO RESULT FILE after $Timeout s" }
"--- kodi.log: add-on lines and Python errors"
Select-String -Path $log -Pattern 'kodi-rt modtest:|script.kodirt.modtest|EXCEPTION|Traceback|Error Contents' | ForEach-Object { $_.Line.Substring(0, [Math]::Min(300, $_.Line.Length)) }
Rpc 'Application.Quit' | Out-Null
if (-not $kodi.WaitForExit(30000)) { Stop-Process -Id $kodi.Id -Force; 'kodi killed after 30 s' } else { "kodi exited, code $($kodi.ExitCode)" }
if ($ok) { "MODTEST ($Arch): PASS"; exit 0 } else { "MODTEST ($Arch): FAIL"; exit 1 }
