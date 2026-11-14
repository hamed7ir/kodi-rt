# kodi-rt: an upgrade from an older Kodi RT setup to a newer one, on this server (the setups are MSIL, so the arm32 one
# runs here too; Kodi itself isn't started). Installs -Old silently into a scratch folder, puts a sentinel file into
# %AppData%\Kodi\userdata (the user's data), installs -New over it, then checks: exit codes, every file of the new
# payload (-Stage) installed byte-identical, which installed files are not in the new payload (left from the old
# version), the sentinel untouched; then uninstalls and checks the folder, the start menu shortcut, the uninstall key
# and the "Open with" registration are gone. Safe on a dev box: stops if Kodi RT is installed for this user already
# (shortcut or uninstall key), removes from %AppData%\Kodi only what it created.
# Usage: powershell -NoProfile -File tests\s9\upgrade-test.ps1 -Flavor x64 -Old C:\handoff\Kodi-RT-Setup-1.0-x64.exe
#            -New build\s8\installer-x64\dist\Kodi-RT-Setup-1.1-x64.exe -Stage build\s8\installer-x64\stage
param(
    [ValidateSet('arm32', 'x64', 'x86')][string]$Flavor = 'x64',
    [Parameter(Mandatory = $true)][string]$Old,
    [Parameter(Mandatory = $true)][string]$New,
    [Parameter(Mandatory = $true)][string]$Stage,
    [string]$Work = 'F:\kodi-rt\build\s9\upgrade-test'
)
$ErrorActionPreference = 'Stop'
foreach ($p in $Old, $New, $Stage) { if (-not (Test-Path $p)) { throw "missing: $p" } }
$startLnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Kodi RT.lnk'
$deskLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Kodi RT.lnk'
$uninstKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Kodi RT'
if ((Test-Path $startLnk) -or (Test-Path $deskLnk) -or (Test-Path $uninstKey)) { throw 'Kodi RT is installed for this user already (shortcut or uninstall key): not testing over it' }
$kodiData = Join-Path $env:APPDATA 'Kodi'
$dataExisted = Test-Path $kodiData
$fails = 0
function Check([string]$what, [bool]$ok, [string]$detail = '') {
    if ($ok) { '  ok   ' + $what } else { '  FAIL ' + $what + $(if ($detail) { " ($detail)" }); $script:fails++ }
}
function Run([string]$exe, [string[]]$a) { (Start-Process -FilePath $exe -ArgumentList $a -PassThru -Wait -WindowStyle Hidden).ExitCode }
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory -Force $Work | Out-Null
$dir = Join-Path $Work 'Kodi RT'
$sentDir = Join-Path $kodiData 'userdata'
$sentinel = Join-Path $sentDir 'kodirt-upgrade-sentinel.txt'
"old: $Old"
"new: $New"
try {
    Check 'old setup installs -> exit 0' ((Run $Old @('--silent', "`"$dir`"", '--no-desktop')) -eq 0)
    New-Item -ItemType Directory -Force $sentDir | Out-Null
    Set-Content -Path $sentinel -Value 'my kodi data' -Encoding ASCII
    $sentHash = (Get-FileHash $sentinel).Hash
    Check 'new setup installs over the old one -> exit 0' ((Run $New @('--silent', "`"$dir`"", '--no-desktop')) -eq 0)
    $stageFiles = Get-ChildItem $Stage -File -Recurse | ForEach-Object { $_.FullName.Substring($Stage.Length + 1) }
    $bad = @($stageFiles | Where-Object { -not ($_ -like 'userdata-presets\*') } | Where-Object {
            $i = Join-Path $dir $_
            -not (Test-Path $i) -or (Get-FileHash $i).Hash -ne (Get-FileHash (Join-Path $Stage $_)).Hash })
    Check "every file of the new payload installed byte-identical ($($stageFiles.Count) files)" ($bad.Count -eq 0) ((@($bad | Select-Object -First 5)) -join ', ')
    $stageSet = @{}; foreach ($f in $stageFiles) { $stageSet[$f.ToLowerInvariant()] = 1 }
    $extra = @(Get-ChildItem $dir -File -Recurse | ForEach-Object { $_.FullName.Substring($dir.Length + 1) } | Where-Object { -not $stageSet.ContainsKey($_.ToLowerInvariant()) })
    "  info files in the folder that the new payload doesn't have: $($extra.Count)"
    $extra | Select-Object -First 15 | ForEach-Object { "       $_" }
    Check 'the user''s data is untouched (sentinel)' ((Test-Path $sentinel) -and (Get-FileHash $sentinel).Hash -eq $sentHash)
    $ver = (Get-ItemProperty $uninstKey -ErrorAction SilentlyContinue).DisplayVersion
    "  info uninstall entry DisplayVersion: $ver"
    Check 'uninstall -> exit 0' ((Run $New @('--uninstall', "`"$dir`"", '--silent')) -eq 0)
    Check 'program folder removed' (-not (Test-Path (Join-Path $dir 'kodi.exe')))
    Check 'start menu shortcut and uninstall key removed' (-not (Test-Path $startLnk) -and -not (Test-Path $uninstKey))
    Check '"Open with" registration removed' (-not (Test-Path 'HKCU:\Software\Classes\KodiRT.Media'))
    Check 'the user''s data is still there after uninstall' (Test-Path $sentinel)
} finally {
    if (Test-Path $sentinel) { Remove-Item $sentinel -Force }
    if (-not $dataExisted -and (Test-Path $kodiData)) { Remove-Item $kodiData -Recurse -Force; 'cleanup: %AppData%\Kodi removed (this test created it)' }
}
if ($fails -eq 0) { 'UPGRADE TEST: ALL OK' } else { "UPGRADE TEST: $fails FAILED" }
