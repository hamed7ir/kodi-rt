# kodi-rt: wait until process <WaitPid> has exited, then run a bash script (sequential builds, never two at once).
# Start this through WMI at BELOW_NORMAL (launch-detached.ps1 style); the bash it starts inherits the priority.
# Usage: powershell -NoProfile -File chain-after.ps1 -WaitPid 1234 -Script /f/kodi-rt/scripts/.x-frozen.sh
param(
  [Parameter(Mandatory = $true)][int]$WaitPid,
  [Parameter(Mandatory = $true)][string]$Script,
  [ValidateSet('msys2', 'git')][string]$Shell = 'msys2'
)
$log = 'F:\kodi-rt\logs\chain-after.log'
"$(Get-Date -Format s) waiting for pid $WaitPid, then: $Script" | Out-File -Append -Encoding utf8 $log
Wait-Process -Id $WaitPid -ErrorAction SilentlyContinue
$bash = if ($Shell -eq 'msys2') { 'D:\MSYS2\usr\bin\bash.exe' } else { 'C:\Program Files\Git\bin\bash.exe' }
"$(Get-Date -Format s) pid $WaitPid gone; starting $bash (priority $((Get-Process -Id $PID).PriorityClass))" | Out-File -Append -Encoding utf8 $log
& $bash -l -c "bash $Script"
"$(Get-Date -Format s) finished, exit $LASTEXITCODE" | Out-File -Append -Encoding utf8 $log
