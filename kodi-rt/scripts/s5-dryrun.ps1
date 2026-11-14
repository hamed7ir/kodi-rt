# kodi-rt Stage 5: dry-run the device kit's scripts on this server with x64 stand-ins for kodi.exe.
# For each case: package build/s5/kit-dryrun/kodi-rt-stage5 with the stand-in role (scripts/s5-package-kit.sh
# --dryrun-x64=<role>), run the kit script the way the tablet would (double-click = cmd in the kit folder; "< nul"
# answers its final pause), and print VERDICT.txt and the results listing.
# Usage: powershell -NoProfile -File scripts\s5-dryrun.ps1
#   For a later kit set KNAME and GATED first, as for s5-package-kit.sh (bash inherits them), e.g.
#   $env:KNAME='kodi-rt-stage5-run4'; $env:GATED='/f/kodi-rt/results/stage5-kit4/bin'
$ErrorActionPreference = 'Stop'
$kname = if ($env:KNAME) { $env:KNAME } else { 'kodi-rt-stage5' }
$kit = "F:\kodi-rt\build\s5\kit-dryrun\$kname"
$bash = 'C:\Program Files\Git\bin\bash.exe'
$cases = @(
  @('normal', 'run-kodi.cmd'),
  @('crash',  'run-kodi.cmd'),
  @('nolog',  'run-kodi.cmd'),
  @('normal', 'run-kodi-dbgrun.cmd'),
  @('break',  'run-kodi-dbgrun.cmd')
)
foreach ($c in $cases) {
  $role = $c[0]; $script = $c[1]
  $pk = & $bash -l -c "cd /f/kodi-rt && bash scripts/s5-package-kit.sh --dryrun-x64=$role 2>&1 | tail -1"
  if ($pk -notmatch 'PACKAGE DONE') { "packaging failed for $role : $pk"; continue }
  cmd /c "cd /d `"$kit`" && call `"$kit\$script`" < nul" | Out-Null
  "===== role=$role script=$script"
  $v = Join-Path $kit 'results\VERDICT.txt'
  if (Test-Path $v) { Get-Content $v | Where-Object { $_ -notmatch '^(kodi-rt stage 5|finished)' } } else { 'NO VERDICT.txt' }
  "   results: " + ((Get-ChildItem (Join-Path $kit 'results') -Recurse -File | ForEach-Object { $_.FullName.Substring($kit.Length + 9) }) -join ', ')
}
