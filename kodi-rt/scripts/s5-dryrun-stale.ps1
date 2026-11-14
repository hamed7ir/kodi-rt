# kodi-rt Stage 5: dry-run the "second run dies before logging" case. A normal run leaves kodi\portable_data\kodi.log;
# then kodi.exe is swapped for the no-log stand-in and run-kodi.cmd runs again (results-2). Expected: the first log
# is moved to results-2\previous-run-kodi.log, and results-2's VERDICT says "kodi.log: NONE".
# Usage: powershell -NoProfile -File scripts\s5-dryrun-stale.ps1   (KNAME/GATED as for s5-dryrun.ps1)
$ErrorActionPreference = 'Stop'
$kname = if ($env:KNAME) { $env:KNAME } else { 'kodi-rt-stage5' }
$kit = "F:\kodi-rt\build\s5\kit-dryrun\$kname"
$bash = 'C:\Program Files\Git\bin\bash.exe'
& $bash -l -c "cd /f/kodi-rt && bash scripts/s5-package-kit.sh --dryrun-x64=nolog 2>&1 | tail -1" | Out-Null
Copy-Item "$kit\kodi\kodi.exe" "$env:TEMP\kodirt-nolog-standin.exe" -Force
& $bash -l -c "cd /f/kodi-rt && bash scripts/s5-package-kit.sh --dryrun-x64=normal 2>&1 | tail -1" | Out-Null
cmd /c "cd /d `"$kit`" && call `"$kit\run-kodi.cmd`" < nul" | Out-Null
"===== run 1 (normal)"
Get-Content "$kit\results\VERDICT.txt" | Where-Object { $_ -match 'kodi.log|exit code' }
Copy-Item "$env:TEMP\kodirt-nolog-standin.exe" "$kit\kodi\kodi.exe" -Force
cmd /c "cd /d `"$kit`" && call `"$kit\run-kodi.cmd`" < nul" | Out-Null
"===== run 2 (dies before logging)"
Get-Content "$kit\results-2\VERDICT.txt" | Where-Object { $_ -match 'kodi.log|exit code|note' }
"   results-2: " + ((Get-ChildItem "$kit\results-2" -File | ForEach-Object Name) -join ', ')
Remove-Item "$env:TEMP\kodirt-nolog-standin.exe"
