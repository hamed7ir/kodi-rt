# kodi-rt PGO: dry-run the profiling kit's scripts (kit/kodi-rt-pgo-profile) on this server, with an x64 stand-in
# for kodi.exe that is INSTRUMENTED like the real one (-fprofile-generate + tools/pgo/pgoflush.c), so the run script's
# LLVM_PROFILE_FILE (the %%m escape), the prof folder and the collection are exercised for real.
#   Case 1: run-kodi.cmd           -> results\prof\kodi-<signature>_0.profraw, VERDICT "counts: ...", main() counted 1
#   Case 2: run-kodi.cmd again     -> the same file, main() counted 2 (each run adds to the counts)
#   Case 3: run-kodi-dbgrun.cmd    -> the same file, main() counted 3
# Usage: powershell -NoProfile -File scripts\s7-dryrun-pgo.ps1      Folder: build\s7\kit-dryrun\kodi-rt-pgo-profile
$ErrorActionPreference = 'Stop'
$rt = 'F:\kodi-rt\tc\rt24c-cr\bin'
$crt = 'F:/kodi-rt/tc/rt24c-cr/lib/clang/23/lib/windows'
$kit = 'F:\kodi-rt\build\s7\kit-dryrun\kodi-rt-pgo-profile'
$obj = 'F:\kodi-rt\build\s7\kit-dryrun\obj'
if (Test-Path $kit) { Remove-Item -Recurse -Force $kit }
New-Item -ItemType Directory -Force "$kit\kodi\system\settings", "$kit\bin", $obj | Out-Null
foreach ($f in 'run-kodi.cmd', 'run-kodi-dbgrun.cmd', 'README.txt') { Copy-Item "F:\kodi-rt\kit\kodi-rt-pgo-profile\$f" $kit }
Set-Content -Path "$kit\kodi\system\settings\settings.xml" -Value '<settings/>' -Encoding ascii
Copy-Item 'F:\kodi-rt\tools\dbgrun\x64\dbgrun.exe' "$kit\bin\"
# the stand-in: instrumented x64, the clang runtime folder FIRST on the link path (MSVC's x64 lib folder has an older
# clang_rt.profile-x86_64.lib that refuses this compiler's raw version)
$cc = @("@F:/kodi-rt/cross/x64-msvc.rsp", '-MT', '-O2', '-nologo')
& "$rt\clang-cl.exe" @cc -c 'F:/kodi-rt/tools/pgo/pgoflush.c' "-Fo$obj\pgoflush.obj"
if ($LASTEXITCODE) { throw 'pgoflush.c' }
& "$rt\clang-cl.exe" @cc -fprofile-generate -c 'F:/kodi-rt/tests/stage5/kodi-standin.c' "-Fo$obj\standin.obj"
if ($LASTEXITCODE) { throw 'kodi-standin.c' }
& "$rt\lld-link.exe" "-libpath:$crt" '@F:/kodi-rt/cross/x64-link.rsp' "-out:$kit\kodi\kodi.exe" "$obj\standin.obj" "$obj\pgoflush.obj"
if ($LASTEXITCODE) { throw 'link' }
$cases = @('run-kodi.cmd', 'run-kodi.cmd', 'run-kodi-dbgrun.cmd')
$n = 0
foreach ($script in $cases) {
  $n++
  cmd /c "cd /d `"$kit`" && call `"$kit\$script`" < nul" | Out-Null
  $res = if ($n -eq 1) { "$kit\results" } else { "$kit\results-$n" }
  "===== case $n : $script -> $(Split-Path $res -Leaf)"
  if (Test-Path "$res\VERDICT.txt") { Get-Content "$res\VERDICT.txt" | Where-Object { $_ -notmatch '^(kodi-rt PGO|finished)' } } else { 'NO VERDICT.txt' }
  $p = Get-ChildItem "$res\prof\*.profraw" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p) {
    $show = & "$rt\llvm-profdata.exe" show --counts --function=main $p.FullName 2>&1
    $bc = ($show | Select-String 'Block counts: \[(\d+)').Matches
    "   $($p.Name): main() entry count $(if ($bc) { $bc[0].Groups[1].Value } else { '?' }) (want $n)"
  } else { '   no profraw in results\prof' }
}
"kit prof folder: " + ((Get-ChildItem "$kit\prof" | ForEach-Object { "$($_.Name) $($_.Length) bytes" }) -join ', ')
