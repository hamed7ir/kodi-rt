# End-to-end test of Kodi-RT-Setup-<ver>-<flavor>.exe against a SCRATCH folder (Venetium's installer test, adapted).
# Build the installer first (.\installer\build-installer.ps1 [-Flavor x64|x86]), then:
#     powershell -NoProfile -ExecutionPolicy Bypass -File installer\tests\test-installer.ps1 [-Flavor x64|x86]
# arm32 (the default) checks the Surface RT presets too (skiploopfilter, Estuary's touch mode written to userdata);
# x64/x86 check that neither is installed (build-installer.ps1 gives them only the touch keymap).
# The installer is MSIL, so it runs on an x64 PC too (Kodi itself won't: the requirements check says so).
# Safe on a dev box: it installs only under -Work (default F:\kodi-rt\build\s8\installer-test), backs up and restores the
# Start-menu and desktop "Kodi RT.lnk", removes the uninstall key only if it didn't exist before, and removes from
# %AppData%\Kodi only the files and folders it created itself. The byte-identical check compares installed files with
# the build's stage folder (-Stage).
param(
    [ValidateSet('arm32', 'x64', 'x86')][string]$Flavor = 'arm32',
    [string]$Setup,
    [string]$Stage,
    [string]$Work
)
$ErrorActionPreference = 'Stop'
$buildDir = if ($Flavor -eq 'arm32') { 'F:\kodi-rt\build\s8\installer' } else { "F:\kodi-rt\build\s8\installer-$Flavor" }
if (-not $Stage) { $Stage = Join-Path $buildDir 'stage' }
if (-not $Setup) {
    $c = Get-ChildItem (Join-Path $buildDir "dist\Kodi-RT-Setup-*-$Flavor.exe") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($c) { $Setup = $c.FullName }
}
if (-not $Setup -or -not (Test-Path $Setup)) { throw "No Kodi-RT-Setup-*-$Flavor.exe found. Build the installer first." }
$surface = $Flavor -eq 'arm32'   # the Surface RT presets are in the arm32 payload only
if (-not (Test-Path $Stage)) { throw "Stage not found: $Stage" }
# A scratch folder with a LONG path: %TEMP% can be an 8.3 name (C:\Users\ADMINI~1\...), while Setup stores and reports
# the long form, so string comparisons with it would fail (measured on the build server).
if (-not $Work) { $Work = 'F:\kodi-rt\build\s8\installer-test' }
$version = [regex]::Match((Split-Path $Setup -Leaf), "Kodi-RT-Setup-(.+)-$Flavor\.exe$").Groups[1].Value
"Setup:   $Setup"
"Stage:   $Stage"
"Version: $version"
$fails = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
    $tag = if ($ok) { '  ok  ' } else { '  FAIL' }
    Write-Output ("{0} {1,-64} {2}" -f $tag, $name, $detail)
    if (-not $ok) { $script:fails++ }
}
function RunSetup([string[]]$a) { $p = Start-Process -FilePath $Setup -ArgumentList $a -PassThru -Wait -WindowStyle Hidden; return $p.ExitCode }

. (Join-Path $PSScriptRoot '..\csc-common.ps1') | Out-Null
$here = $PSScriptRoot
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory $Work | Out-Null
$dir = Join-Path $Work 'inst'
$programs = [Environment]::GetFolderPath('Programs')
$lnk = Join-Path $programs 'Kodi RT.lnk'
$desk = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Kodi RT.lnk'
$lnkBackup = Join-Path $Work 'start.lnk.backup'; $deskBackup = Join-Path $Work 'desk.lnk.backup'
$hadLnk = Test-Path $lnk; $hadDesk = Test-Path $desk
if ($hadLnk) { Copy-Item $lnk $lnkBackup }
if ($hadDesk) { Copy-Item $desk $deskBackup }
$ukey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Kodi RT'
$hadKey = Test-Path $ukey
# "Open with" (Setup's FileAssoc): the ProgID, the Capabilities and the RegisteredApplications value
$progKey = 'HKCU:\Software\Classes\KodiRT.Media'
$capKey = 'HKCU:\Software\Kodi RT\Capabilities'
$regApps = 'HKCU:\Software\RegisteredApplications'
$hadProg = Test-Path $progKey
function OpenWithHas([string]$ext) {
    $k = Get-Item ("HKCU:\Software\Classes\$ext\OpenWithProgids") -ErrorAction SilentlyContinue
    return [bool]($k -and ($k.GetValueNames() -contains 'KodiRT.Media'))
}

# %AppData%\Kodi\userdata: a sentinel that must survive everything, and the Estuary preset (written only if absent)
$kodiRoot = Join-Path $env:APPDATA 'Kodi'
$userData = Join-Path $kodiRoot 'userdata'
$made = New-Object System.Collections.Generic.List[string]   # folders this test created, deepest last
foreach ($d in @($kodiRoot, $userData)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null; $made.Add($d) } }
$sentinel = Join-Path $userData ('__installer_test_' + [guid]::NewGuid().ToString('N') + '.txt')
Set-Content $sentinel 'user data - must survive uninstall'
$sentinelBefore = (Get-FileHash $sentinel).Hash
$presetRel = 'addon_data\skin.estuary\settings.xml'
$preset = Join-Path $userData $presetRel
$hadPreset = Test-Path $preset
$presetBefore = if ($hadPreset) { (Get-FileHash $preset).Hash } else { $null }
$stagePreset = Join-Path $Stage ('userdata-presets\' + $presetRel)
$madePresetDirs = @()
foreach ($d in @((Join-Path $userData 'addon_data'), (Join-Path $userData 'addon_data\skin.estuary'))) { if (-not (Test-Path $d)) { $madePresetDirs += $d } }

try {
    # 1. requirements report (on an x64 PC: exit 2, the ARM32 programs cannot run here; installing is still allowed)
    $rep = Join-Path $Work 'check.txt'
    $code = RunSetup @('--check', "`"$rep`"")
    Check '--check writes a report' ((Test-Path $rep) -and $code -in 0, 2, 3) "exit $code"

    # 2. silent install to scratch, without a desktop shortcut
    $deskBefore = if (Test-Path $desk) { (Get-FileHash $desk).Hash + '|' + (Get-Item $desk).LastWriteTimeUtc.Ticks } else { $null }
    $code = RunSetup @('--silent', "`"$dir`"", '--no-desktop')
    Check '--silent install exit 0' ($code -eq 0) "exit $code"
    foreach ($f in 'kodi.exe', 'python314.dll', 'python314._pth', 'dvdnav.dll', 'uninstall.exe', 'system\settings\settings.xml',
                   'system\keymaps\z-kodirt-touchscreen.xml', 'system\python\Lib\os.py', 'addons\skin.estuary\addon.xml') {
        Check "  installed: $f" (Test-Path (Join-Path $dir $f))
    }
    if ($surface) { Check '  installed: system\advancedsettings.xml (skiploopfilter)' (Test-Path (Join-Path $dir 'system\advancedsettings.xml')) }
    else { Check "  no system\advancedsettings.xml in the $Flavor payload" (-not (Test-Path (Join-Path $dir 'system\advancedsettings.xml'))) }
    Check 'no userdata-presets folder and no portable_data in the program folder' (-not (Test-Path (Join-Path $dir 'userdata-presets')) -and -not (Test-Path (Join-Path $dir 'portable_data')))
    $installed = Get-ChildItem $dir -File -Recurse | Where-Object { $_.Name -ne 'uninstall.exe' }
    $stageFiles = Get-ChildItem $Stage -File -Recurse | Where-Object { -not $_.FullName.StartsWith((Join-Path $Stage 'userdata-presets\')) }
    $diff = $installed | Where-Object {
        $rel = $_.FullName.Substring($dir.Length + 1)
        $srcf = Join-Path $Stage $rel
        (-not (Test-Path $srcf)) -or ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $srcf).Hash)
    }
    Check 'installed files byte-identical to the stage, none missing' ($diff.Count -eq 0 -and $installed.Count -eq $stageFiles.Count) ("$($installed.Count) of $($stageFiles.Count); " + (($diff | Select-Object -First 3 | ForEach-Object Name) -join ', '))
    $k = Get-ItemProperty $ukey -ErrorAction SilentlyContinue
    Check 'uninstall entry written (location + version)' ($k -and $k.InstallLocation -eq $dir -and $k.DisplayVersion -eq $version) ("" + $k.DisplayVersion + " " + $k.InstallLocation)
    $cmd = (Get-ItemProperty "$progKey\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
    Check 'Open with: ProgID opens the installed kodi.exe with the file' ($cmd -eq ('"' + (Join-Path $dir 'kodi.exe') + '" "%1"')) "$cmd"
    Check 'Open with: .mkv .mp4 .mp3 .flac .m3u list Kodi RT' ((OpenWithHas '.mkv') -and (OpenWithHas '.mp4') -and (OpenWithHas '.mp3') -and (OpenWithHas '.flac') -and (OpenWithHas '.m3u'))
    Check 'Open with: no pictures and no .zip' (-not (OpenWithHas '.jpg') -and -not (OpenWithHas '.png') -and -not (OpenWithHas '.zip'))
    $ra = (Get-ItemProperty $regApps -ErrorAction SilentlyContinue).'Kodi RT'
    $fa = (Get-ItemProperty "$capKey\FileAssociations" -ErrorAction SilentlyContinue).'.mkv'
    Check 'Open with: RegisteredApplications -> Capabilities (.mkv -> KodiRT.Media)' ($ra -eq 'Software\Kodi RT\Capabilities' -and $fa -eq 'KodiRT.Media') "$ra / $fa"
    $sh = New-Object -ComObject WScript.Shell
    Check 'start menu shortcut -> installed kodi.exe' ((Test-Path $lnk) -and $sh.CreateShortcut($lnk).TargetPath -eq (Join-Path $dir 'kodi.exe'))
    $deskAfter = if (Test-Path $desk) { (Get-FileHash $desk).Hash + '|' + (Get-Item $desk).LastWriteTimeUtc.Ticks } else { $null }
    Check 'no desktop shortcut with --no-desktop' ($deskAfter -eq $deskBefore) $(if ($deskBefore) { 'pre-existing shortcut unchanged' })

    # 3. the user-data preset: written when absent, identical to the stage's; an existing one is untouched
    if ($hadPreset) {
        Check 'existing Estuary settings left as they were' ((Get-FileHash $preset).Hash -eq $presetBefore)
    } elseif ($surface) {
        Check 'Estuary touch-mode preset written to %AppData%\Kodi\userdata' ((Test-Path $preset) -and (Get-FileHash $preset).Hash -eq (Get-FileHash $stagePreset).Hash)
    } else {
        Check "no Estuary preset written for $Flavor" (-not (Test-Path $preset))
    }

    # 4. a running kodi.exe from the folder blocks upgrade + uninstall (exit 4), and is never killed
    & $csc /nologo "/out:$Work\kodi.exe" "$here\Sleeper.cs" | Out-Null
    Copy-Item (Join-Path $dir 'kodi.exe') (Join-Path $Work 'real-kodi.exe')
    Copy-Item "$Work\kodi.exe" (Join-Path $dir 'kodi.exe') -Force
    $sleeper = Start-Process (Join-Path $dir 'kodi.exe') -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 700
    $code = RunSetup @('--silent', "`"$dir`"", '--no-desktop')
    Check 'install over a running Kodi -> exit 4' ($code -eq 4) "exit $code"
    $code = RunSetup @('--uninstall', "`"$dir`"", '--silent')
    Check 'uninstall while Kodi runs -> exit 4' ($code -eq 4) "exit $code"
    Check 'the running Kodi was not killed' (-not $sleeper.HasExited)
    Stop-Process -Id $sleeper.Id -Force; $sleeper.WaitForExit()
    Copy-Item (Join-Path $Work 'real-kodi.exe') (Join-Path $dir 'kodi.exe') -Force

    # 5. upgrade in place: a file Kodi RT never shipped stays; the user's changed preset stays; /S is rejected
    Set-Content (Join-Path $dir 'my-notes.txt') 'not ours'
    if (-not $hadPreset) { New-Item -ItemType Directory -Force (Split-Path $preset) | Out-Null; Set-Content $preset '<settings><!-- changed by the user --></settings>' }
    $presetMine = (Get-FileHash $preset).Hash
    $code = RunSetup @('--silent', "`"$dir`"", '--no-desktop')
    Check 'upgrade in place -> exit 0' ($code -eq 0) "exit $code"
    Check 'upgrade keeps a file Kodi RT never shipped' (Test-Path (Join-Path $dir 'my-notes.txt'))
    Check 'upgrade keeps the user''s Estuary settings' ((Get-FileHash $preset).Hash -eq $presetMine)
    $code = RunSetup @('--silent', '/S')
    Check '--silent with an unknown switch (/S) -> exit 2' ($code -eq 2) "exit $code"

    # 6. folder guard (internal SafeTarget.Problem, via reflection on the AnyCPU Setup assembly)
    $asm = [System.Reflection.Assembly]::LoadFrom($Setup)
    $bf = [System.Reflection.BindingFlags]'NonPublic,Static,Public'
    $st = $asm.GetType('KodiRtSetup.SafeTarget').GetMethod('Problem', $bf)
    $prob = { param($d) $st.Invoke($null, @(, [string]$d)) }
    $docs0 = [Environment]::GetFolderPath('MyDocuments'); $desk0 = [Environment]::GetFolderPath('DesktopDirectory')
    Check 'guard refuses Documents / Desktop / profile / drive root / LocalAppData\Programs / %AppData%\Kodi' (
        (& $prob $docs0) -and (& $prob $desk0) -and (& $prob $env:USERPROFILE) -and (& $prob 'C:\') -and (& $prob (Join-Path $env:LOCALAPPDATA 'Programs')) -and (& $prob $kodiRoot))
    Check 'guard refuses a name with % or ^' ((& $prob 'C:\foo%bar') -and (& $prob 'C:\foo^bar'))
    Check 'guard accepts a new folder under Documents' ($null -eq (& $prob (Join-Path $docs0 'Kodi-RT-new-folder-that-does-not-exist')))

    # 6b. a non-empty FOREIGN folder is refused by install and by uninstall, and its files are kept
    $foreign = Join-Path $Work 'foreign'; New-Item -ItemType Directory $foreign | Out-Null; Set-Content (Join-Path $foreign 'keep.txt') 'user data'
    $code = RunSetup @('--silent', "`"$foreign`"", '--no-desktop')
    Check '--silent into a non-empty foreign folder -> exit 5, file kept' ($code -eq 5 -and (Test-Path (Join-Path $foreign 'keep.txt'))) "exit $code"
    $code = RunSetup @('--uninstall', "`"$foreign`"", '--silent')
    Start-Sleep -Seconds 2
    Check '--uninstall of a foreign folder -> exit 5, file kept' ($code -eq 5 -and (Test-Path (Join-Path $foreign 'keep.txt'))) "exit $code"

    # 7. uninstall with the user's own files in the folder and Python's __pycache__: ours (and the .pyc) go, theirs stay
    Set-Content (Join-Path $dir 'keep-me.txt') 'mine'
    $pc = Join-Path $dir 'system\python\Lib\__pycache__'; New-Item -ItemType Directory -Force $pc | Out-Null
    Set-Content (Join-Path $pc 'os.cpython-314.pyc') 'pyc'
    $code = RunSetup @('--uninstall', "`"$dir`"", '--silent')
    Start-Sleep -Seconds 9   # the detached cmd waits for Setup to exit, then deletes uninstall.exe and rmdir's if empty
    $left = @(Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $_.FullName.Substring($dir.Length + 1) })
    Check 'uninstall with user files: exit 0, only theirs left (no .pyc)' ($code -eq 0 -and (($left | Sort-Object) -join ',') -eq 'keep-me.txt,my-notes.txt') ("exit $code, left: " + ($left -join ','))
    Remove-Item $dir -Recurse -Force

    # 7b. install to a path given with a trailing backslash: stored without it, and it really installed
    $code = RunSetup @('--silent', "`"$dir\\`"", '--no-desktop')
    $k2 = Get-ItemProperty $ukey -ErrorAction SilentlyContinue
    Check 'trailing-backslash path: exit 0, normalised location' ($code -eq 0 -and $k2 -and $k2.InstallLocation -eq $dir -and (Test-Path (Join-Path $dir 'kodi.exe'))) ("exit $code " + $k2.InstallLocation)

    # 7c. clean uninstall: folder gone, uninstall key gone, our shortcut gone, user data untouched
    $code = RunSetup @('--uninstall', "`"$dir`"", '--silent')
    Start-Sleep -Seconds 9
    Check '--uninstall exit 0' ($code -eq 0) "exit $code"
    Check 'install folder removed' (-not (Test-Path $dir))
    Check 'uninstall entry removed' (-not (Test-Path $ukey) -or $hadKey)
    Check 'Open with removed (ProgID, .mkv/.mp3 entries, RegisteredApplications)' ((-not (Test-Path $progKey) -or $hadProg) -and -not (OpenWithHas '.mkv') -and -not (OpenWithHas '.mp3') -and -not (Get-ItemProperty $regApps -ErrorAction SilentlyContinue).'Kodi RT')
    Check 'our start menu shortcut removed' (-not (Test-Path $lnk))
    Check 'user data (%AppData%\Kodi) untouched: sentinel and Estuary settings' ((Test-Path $sentinel) -and (Get-FileHash $sentinel).Hash -eq $sentinelBefore -and (Test-Path $preset) -and (Get-FileHash $preset).Hash -eq $presetMine)
}
finally {
    if ($hadLnk -and (Test-Path $lnkBackup)) { Copy-Item $lnkBackup $lnk -Force } elseif (-not $hadLnk -and (Test-Path $lnk)) { Remove-Item $lnk -Force }
    if ($hadDesk -and (Test-Path $deskBackup)) { Copy-Item $deskBackup $desk -Force } elseif (-not $hadDesk -and (Test-Path $desk)) { Remove-Item $desk -Force }
    if (-not $hadKey -and (Test-Path $ukey)) { Remove-Item $ukey -Recurse -Force }
    if (-not $hadProg -and (Test-Path $progKey)) {
        # an aborted run: take back what Setup registered (the types are the Capabilities' FileAssociations)
        $types = @(); $fk = Get-Item "$capKey\FileAssociations" -ErrorAction SilentlyContinue; if ($fk) { $types = $fk.GetValueNames() }
        foreach ($t in $types) { try { Remove-ItemProperty "HKCU:\Software\Classes\$t\OpenWithProgids" -Name 'KodiRT.Media' -ErrorAction SilentlyContinue } catch { } }
        Remove-Item $progKey -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item 'HKCU:\Software\Kodi RT' -Recurse -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty $regApps -Name 'Kodi RT' -ErrorAction SilentlyContinue
    }
    try { if (Test-Path $sentinel) { Remove-Item $sentinel -Force } } catch { }
    try { if (-not $hadPreset -and (Test-Path $preset)) { Remove-Item $preset -Force } } catch { }
    [array]::Reverse($madePresetDirs)
    foreach ($d in $madePresetDirs) { try { if ((Test-Path $d) -and -not (Get-ChildItem $d -Force)) { Remove-Item $d -Force } } catch { } }
    $made.Reverse()
    foreach ($d in $made) { try { if ((Test-Path $d) -and -not (Get-ChildItem $d -Force)) { Remove-Item $d -Force } } catch { } }
    "cleanup: %AppData%\Kodi " + $(if (Test-Path $kodiRoot) { 'exists (it did before, or holds files this test did not create)' } else { 'removed (this test created it)' })
}
if ($fails -eq 0) { 'ALL OK' } else { "$fails FAILURE(S)" }
