# kodi-rt: start chain-after.ps1 detached through WMI at BELOW_NORMAL priority (16384).
# Usage: powershell -NoProfile -File launch-chain.ps1 -WaitPid 1234 -Script /f/kodi-rt/scripts/.x-frozen.sh
param(
  [Parameter(Mandatory = $true)][int]$WaitPid,
  [Parameter(Mandatory = $true)][string]$Script
)
$cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File F:\kodi-rt\scripts\chain-after.ps1 -WaitPid $WaitPid -Script $Script"
$su = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ PriorityClass = [uint32]16384; ShowWindow = [uint16]0 }
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
  CommandLine = $cmd; CurrentDirectory = 'F:\kodi-rt'; ProcessStartupInformation = $su }
"command: $cmd"
"ReturnValue=$($r.ReturnValue) ProcessId=$($r.ProcessId)"
