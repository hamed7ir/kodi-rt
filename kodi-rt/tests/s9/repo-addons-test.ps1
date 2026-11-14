# kodi-rt: can our x64/x86 builds use Kodi's binary add-ons from Kodi's own repository (where desktop users get them;
# only the ARM32 build ships its own)? Copies the kit's kodi folder to a scratch folder, adds the test add-on
# tests\s9\repotest\script.kodirt.repotest, starts kodi.exe -p windowed with JSON-RPC on 127.0.0.1:9090, runs the
# add-on (it installs inputstream.adaptive, pvr.iptvsimple, inputstream.ffmpegdirect, inputstream.rtmp, vfs.rar and
# vfs.libarchive from the repository and enables them), then prints the results, the add-on load lines of kodi.log
# and the imports of each downloaded DLL (Kodi's official builds use MSVC's shared C runtime).
# Needs network access to mirrors.kodi.tv. Usage: powershell -NoProfile -File tests\s9\repo-addons-test.ps1 -Arch x64
param([ValidateSet('x64', 'x86')][string]$Arch = 'x64', [int]$Timeout = 600)
$ErrorActionPreference = 'Stop'
$kit = "F:\kodi-rt\kit\kodi-rt-s9-$Arch\kodi"
$run = "F:\kodi-rt\build\s9\repotest-$Arch"
$addon = 'F:\kodi-rt\tests\s9\repotest\script.kodirt.repotest'
$readobj = 'F:\kodi-rt\tc\rt24d-cr\bin\llvm-readobj.exe'
if (-not (Test-Path "$kit\kodi.exe")) { throw "no $kit\kodi.exe" }
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
$result = "$pd\repotest-result.json"
$kodi = Start-Process -FilePath "$run\kodi\kodi.exe" -ArgumentList '-p' -WorkingDirectory "$run\kodi" -PassThru
"kodi.exe ($Arch) started, pid $($kodi.Id)"
$t0 = Get-Date
do { Start-Sleep -Milliseconds 500 } until (((Test-Path $log) -and (Select-String -Path $log -Pattern 'Running the application' -Quiet)) -or ((Get-Date) - $t0).TotalSeconds -gt 90)
Start-Sleep -Seconds 8
$script:id = 0
function Rpc([string]$method, [string]$params = '{}') {
    $script:id++
    $c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', 9090); $s = $c.GetStream()
    $req = [System.Text.Encoding]::UTF8.GetBytes("{`"jsonrpc`":`"2.0`",`"method`":`"$method`",`"params`":$params,`"id`":$script:id}")
    $s.Write($req, 0, $req.Length); $s.ReadTimeout = 15000
    $buf = New-Object byte[] 65536; $n = 0; try { $n = $s.Read($buf, 0, $buf.Length) } catch { }
    $c.Close(); return [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
}
"SetAddonEnabled: " + (Rpc 'Addons.SetAddonEnabled' '{"addonid":"script.kodirt.repotest","enabled":true}')
Start-Sleep -Seconds 2
"ExecuteAddon: " + (Rpc 'Addons.ExecuteAddon' '{"addonid":"script.kodirt.repotest"}')
$t = Get-Date
do { Start-Sleep -Seconds 1 } until ((Test-Path $result) -or ((Get-Date) - $t).TotalSeconds -gt $Timeout)
Start-Sleep -Seconds 1
if (Test-Path $result) { Get-Content $result -Raw } else { "NO RESULT FILE after $Timeout s" }
"--- kodi.log: install and load lines"
Select-String -Path $log -Pattern 'kodi-rt repotest:|CAddonDll|LoadLibrary|failed to load|Unable to load|incompatible|CPVRClient|pvr.iptvsimple|inputstream.adaptive' |
    Select-Object -First 60 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(260, $_.Line.Length)) }
"--- imports of the downloaded DLLs"
Get-ChildItem "$pd\addons" -Recurse -Filter *.dll | ForEach-Object {
    $imps = (& $readobj --coff-imports $_.FullName 2>$null | Select-String -Pattern '^\s*Name: ' | ForEach-Object { ($_.Line -split 'Name: ')[1].Trim() }) -join ' '
    "{0}: {1}" -f $_.FullName.Substring($pd.Length + 1), $imps
}
Rpc 'Application.Quit' | Out-Null
if (-not $kodi.WaitForExit(30000)) { Stop-Process -Id $kodi.Id -Force; 'kodi killed after 30 s' } else { "kodi exited, code $($kodi.ExitCode)" }
