# kodi-rt: start a bash script DETACHED from the agent session, through WMI.
# Why: background commands started from an agent session are stopped after ~30 minutes (handoff §0); WMI-created
# processes are not. Native children inherit the priority class.
# Priority: Normal by default. Hamed, 2026-11-12: "no venetium build do not run below normal". Use -Priority
# BelowNormal (16384) only while a Venetium build is running again (then also back to -j2, and tell him).
#
# Usage: powershell -NoProfile -File launch-detached.ps1 -Script /f/kodi-rt/scripts/.x-frozen.sh [-Shell msys2|git] [-ScriptArgs "a b"] [-Priority Normal|BelowNormal]
# The script must redirect its own output (exec > log 2>&1). Prints the PID; kill by that PID only.
param(
  [Parameter(Mandatory = $true)][string]$Script,
  [ValidateSet('msys2', 'git', 'cmd')][string]$Shell = 'msys2',
  [string]$ScriptArgs = '',
  [ValidateSet('Normal', 'BelowNormal')][string]$Priority = 'Normal'
)
$pc = if ($Priority -eq 'BelowNormal') { 16384 } else { 32 }
if ($Shell -eq 'cmd') {
  # a .cmd script (Windows path); it must redirect its own output
  $cmd = "`"$env:SystemRoot\System32\cmd.exe`" /c `"`"$Script`" $ScriptArgs`""
} else {
  $bash = if ($Shell -eq 'msys2') { 'D:\MSYS2\usr\bin\bash.exe' } else { 'C:\Program Files\Git\bin\bash.exe' }
  if (-not (Test-Path $bash)) { throw "no bash at $bash" }
  $cmd = "`"$bash`" -l -c `"bash $Script $ScriptArgs`""
}
$su = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ PriorityClass = [uint32]$pc; ShowWindow = [uint16]0 }
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
  CommandLine = $cmd; CurrentDirectory = 'F:\kodi-rt'; ProcessStartupInformation = $su }
"command: $cmd"
"ReturnValue=$($r.ReturnValue) ProcessId=$($r.ProcessId)"
if ($r.ReturnValue -eq 0) {
  Start-Sleep -Milliseconds 800
  $p = Get-Process -Id $r.ProcessId -ErrorAction SilentlyContinue
  if ($p) { "running: $($p.ProcessName) priority=$($p.PriorityClass)" } else { "process already exited (check the script's log)" }
}
