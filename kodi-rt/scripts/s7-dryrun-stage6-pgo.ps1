# kodi-rt: dry-run the stage 6 PGO kit's scripts (kit/kodi-rt-stage6-pgo: run-kodi.cmd, run-kodi-profile.cmd,
# run-kodi-dbgrun.cmd; the full kit's scripts with new banner lines) on this server with x64 stand-ins: kodi.exe =
# tests/stage5/kodi-standin.c (writes kodi.log and exits 0), bin\dbgrun.exe and bin\rtprof.exe = the x64 builds.
# Usage: powershell -NoProfile -File scripts\s7-dryrun-stage6-pgo.ps1      Folder: build\s7\kit-dryrun\kodi-rt-stage6-pgo
$ErrorActionPreference = 'Stop'
$rt = 'F:\kodi-rt\tc\rt24c-cr\bin'
$kit = 'F:\kodi-rt\build\s7\kit-dryrun\kodi-rt-stage6-pgo'
$obj = 'F:\kodi-rt\build\s7\kit-dryrun\obj6'
if (Test-Path $kit) { Remove-Item -Recurse -Force $kit }
New-Item -ItemType Directory -Force "$kit\kodi\system\settings", "$kit\bin", $obj | Out-Null
foreach ($f in 'run-kodi.cmd', 'run-kodi-profile.cmd', 'run-kodi-dbgrun.cmd', 'README.txt') { Copy-Item "F:\kodi-rt\kit\kodi-rt-stage6-pgo\$f" $kit }
Set-Content -Path "$kit\kodi\system\settings\settings.xml" -Value '<settings/>' -Encoding ascii
Copy-Item 'F:\kodi-rt\tools\dbgrun\x64\dbgrun.exe' "$kit\bin\"
Copy-Item 'F:\kodi-rt\build\s6\rtprof\x64\rtprof.exe' "$kit\bin\"
# -w: no warnings on stderr (PowerShell 5.1 turns native stderr into a terminating error under 'Stop')
& "$rt\clang-cl.exe" '@F:/kodi-rt/cross/x64-msvc.rsp' -MT -O2 -nologo -w -c 'F:/kodi-rt/tests/stage5/kodi-standin.c' "-Fo$obj\standin.obj"
if ($LASTEXITCODE) { throw 'kodi-standin.c' }
& "$rt\lld-link.exe" '@F:/kodi-rt/cross/x64-link.rsp' "-out:$kit\kodi\kodi.exe" "$obj\standin.obj"
if ($LASTEXITCODE) { throw 'link' }
$n = 0
foreach ($script in 'run-kodi.cmd', 'run-kodi-profile.cmd', 'run-kodi-dbgrun.cmd') {
  $n++
  cmd /c "cd /d `"$kit`" && call `"$kit\$script`" < nul" | Out-Null
  $res = if ($n -eq 1) { "$kit\results" } else { "$kit\results-$n" }
  "===== case $n : $script -> $(Split-Path $res -Leaf)"
  if (Test-Path "$res\VERDICT.txt") { Get-Content "$res\VERDICT.txt" } else { 'NO VERDICT.txt' }
  "   files: " + ((Get-ChildItem $res -Recurse -File | ForEach-Object { $_.FullName.Substring($res.Length + 1) }) -join ', ')
}
