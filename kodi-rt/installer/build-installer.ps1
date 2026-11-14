# Builds the Kodi RT installer: Setup.cs (AnyCPU MSIL, .NET Framework 4.0) with the Kodi payload embedded as gzip
# resources, compiled with Roslyn csc. MSIL so ONE exe runs on Windows RT 8.1 / ARM32 Windows as well as x86/x64
# (a native x86 installer loader cannot start on ARM32 Windows). Venetium's installer\build-installer.ps1, adapted.
#
#   .\installer\build-installer.ps1 [-Flavor arm32|x64|x86] [-Kit <a full kit's kodi folder>] [-Version 1.0] [-Work <dir>]
#   Defaults per flavor: arm32 kit\kodi-rt-v1.0-arm32\kodi, work build\s8\installer; x64/x86 kit\kodi-rt-s9-<flavor>\kodi
#   (scripts/s9-package-kit.sh), work build\s8\installer-<flavor>. The payload's programs must be that machine type.
#
# Payload: the kit's kodi\ folder (kodi.exe, python314.dll, python314._pth, dvdnav.dll, addons, media, system with
# Python's standard library, userdata) WITHOUT the kit's portable_data, plus installer\presets:
#   system\advancedsettings.xml              skiploopfilter 48 (Kodi reads it before the user's own file)
#   system\keymaps\z-kodirt-touchscreen.xml  two-finger tap = Back, a tap keeps the video controls up
#   userdata-presets\...                     Estuary's touch mode, written to %AppData%\Kodi\userdata on a first install
# x64/x86 get only the keymap: skiploopfilter and Estuary's touch mode are the Surface RT's tuning, not a desktop's.
# Produces <Work>\dist\Kodi-RT-Setup-<ver>-<flavor>.exe (+ SHA256SUMS.txt). The exe ships as a GitHub Release asset.
param(
    [string]$Kit = '',
    [string]$Version = '1.0',
    [string]$Work = '',
    [ValidateSet('arm32', 'x64', 'x86')][string]$Flavor = 'arm32'
)
$ErrorActionPreference = 'Stop'
if (-not $Kit)  { $Kit  = if ($Flavor -eq 'arm32') { 'F:\kodi-rt\kit\kodi-rt-v1.0-arm32\kodi' } else { "F:\kodi-rt\kit\kodi-rt-s9-$Flavor\kodi" } }
if (-not $Work) { $Work = if ($Flavor -eq 'arm32') { 'F:\kodi-rt\build\s8\installer' } else { "F:\kodi-rt\build\s8\installer-$Flavor" } }
$wantMachine = @{ arm32 = 0x1C4; x64 = 0x8664; x86 = 0x14C }[$Flavor]
$repo    = Split-Path -Parent $PSScriptRoot
$setupCs = Join-Path $repo 'installer\Setup.cs'
$presets = Join-Path $repo 'installer\presets'
$icon    = Join-Path $repo 'installer\kodi.ico'
foreach ($p in @($Kit, $setupCs, $presets, $icon, (Join-Path $Kit 'kodi.exe'), (Join-Path $Kit 'system\settings\settings.xml'))) {
    if (-not (Test-Path $p)) { throw "missing: $p" }
}

function Sha256([string]$p) { (Get-FileHash $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function PeMachine([string]$p) {
    $b = [System.IO.File]::ReadAllBytes($p)
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    return [BitConverter]::ToUInt16($b, $pe + 4)
}

# ── 1. stage the payload: the kit's kodi folder without portable_data, plus the presets ─────────────────────────
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
$stage = Join-Path $Work 'stage'
New-Item -ItemType Directory -Force $stage | Out-Null
Get-ChildItem $Kit -Force | Where-Object { $_.Name -ne 'portable_data' } | ForEach-Object { Copy-Item $_.FullName $stage -Recurse -Force }
$presetFiles = Get-ChildItem $presets -File -Recurse | ForEach-Object { $_.FullName.Substring($presets.Length + 1) }
if ($Flavor -ne 'arm32') {
    $presetFiles = $presetFiles | Where-Object { $_ -notmatch '^(system\\advancedsettings\.xml|userdata-presets\\)' }
}
foreach ($rel in $presetFiles) {
    $dst = Join-Path $stage $rel
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Copy-Item (Join-Path $presets $rel) $dst -Force
}
"presets ($Flavor): $($presetFiles -join ', ')"
foreach ($f in 'kodi.exe', 'python314.dll', 'dvdnav.dll') {
    $m = PeMachine (Join-Path $stage $f)
    if ($m -ne $wantMachine) { throw ("{0} is machine 0x{1:X}, not 0x{2:X} ({3})" -f $f, $m, $wantMachine, $Flavor) }
}
# every other program in the payload too: pycryptodome's C modules (addons\script.module.pycryptodome\lib\**\*.pyd)
# are built per architecture, and a module of the wrong flavor would only fail when an add-on loads it
$progs = @(Get-ChildItem $stage -File -Recurse -Include *.exe, *.dll, *.pyd)
foreach ($p in $progs) {
    $m = PeMachine $p.FullName
    if ($m -ne $wantMachine) { throw ("{0} is machine 0x{1:X}, not 0x{2:X} ({3})" -f $p.FullName.Substring($stage.Length + 1), $m, $wantMachine, $Flavor) }
}
"programs: $($progs.Count), all machine 0x{0:X}" -f $wantMachine
if (Test-Path (Join-Path $stage 'portable_data')) { throw 'portable_data must not be in the payload' }
$files = Get-ChildItem $stage -File -Recurse | ForEach-Object { $_.FullName.Substring($stage.Length + 1) }
$bad = $files | Where-Object { $_ -match ',' }
if ($bad) { throw "payload names with a comma break csc's /resource syntax: $($bad -join '; ')" }
"payload: $($files.Count) files (kodi.exe sha256 $(Sha256 (Join-Path $stage 'kodi.exe')))"

# ── 2. gzip each payload file (subdirs preserved); build payload.list + csc /resource args ───────────────────
Add-Type -AssemblyName System.IO.Compression.FileSystem
$setupDir = Join-Path $Work 'setup'
New-Item -ItemType Directory -Force (Join-Path $setupDir 'payload') | Out-Null
$list = New-Object System.Collections.Generic.List[string]
$res  = New-Object System.Collections.Generic.List[string]
foreach ($rel in $files) {
    $srcf = Join-Path $stage $rel
    $relf = ($rel -replace '\\', '/')                         # forward slashes in list + resource name
    $gz   = Join-Path $setupDir ('payload\' + $rel + '.gz')
    New-Item -ItemType Directory -Force (Split-Path $gz) | Out-Null
    $in = [System.IO.File]::OpenRead($srcf); $out = [System.IO.File]::Create($gz)
    $z  = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionMode]::Compress)
    $in.CopyTo($z); $z.Dispose(); $out.Dispose(); $in.Dispose()
    $list.Add((Sha256 $srcf) + "`t" + (Get-Item $srcf).Length + "`t" + $relf)
    $res.Add('"/resource:' + $gz + ',payload/' + $relf + '.gz"')   # quoted whole: a few names have spaces
}
[System.IO.File]::WriteAllLines((Join-Path $setupDir 'payload.list'), $list, (New-Object System.Text.UTF8Encoding($false)))
"staged + gzipped $($list.Count) payload files"

# ── 3. SetupInfo.cs (namespace must match Setup.cs) ──────────────────────────────────────────────────────────
$info = @"
using System.Reflection;
[assembly: AssemblyTitle("Kodi RT Setup")]
[assembly: AssemblyProduct("Kodi RT")]
[assembly: AssemblyCompany("Hamed Ghorbani")]
[assembly: AssemblyCopyright("(c) 2026 Hamed Ghorbani")]
[assembly: AssemblyVersion("$Version")]
[assembly: AssemblyFileVersion("$Version")]
[assembly: AssemblyInformationalVersion("$Version $Flavor")]
namespace KodiRtSetup
{
    internal static class Info
    {
        internal const string AppVersion = "$Version";
        internal const string Flavor = "$Flavor";
    }
}
"@
[System.IO.File]::WriteAllText((Join-Path $setupDir 'SetupInfo.cs'), $info, (New-Object System.Text.UTF8Encoding($false)))

# ── 4. compile with Roslyn csc against .NET 4.0 reference assemblies ($csc, $refs: csc-common.ps1) ─────────────
. (Join-Path $PSScriptRoot 'csc-common.ps1')

$setupExe = Join-Path $setupDir ("Kodi-RT-Setup-$Version-$Flavor.exe")
$rsp = New-Object System.Collections.Generic.List[string]
$rsp.AddRange([string[]]@(
    '/nostdlib+', '/nologo', '/target:winexe', '/platform:anycpu', '/optimize+', '/langversion:7.3', '/codepage:65001',
    ('/out:"' + $setupExe + '"'),
    ('/win32icon:"' + $icon + '"'),
    ('"/resource:' + $icon + ',setup.icon.ico"'),
    ('"/resource:' + (Join-Path $setupDir 'payload.list') + ',payload.list"'),
    ('/r:"' + (Join-Path $refs 'mscorlib.dll') + '"'),
    ('/r:"' + (Join-Path $refs 'System.dll') + '"'),
    ('/r:"' + (Join-Path $refs 'System.Core.dll') + '"'),
    ('/r:"' + (Join-Path $refs 'System.Drawing.dll') + '"'),
    ('/r:"' + (Join-Path $refs 'System.Windows.Forms.dll') + '"')))
$rsp.AddRange([string[]]$res)
$rsp.Add('"' + $setupCs + '"')
$rsp.Add('"' + (Join-Path $setupDir 'SetupInfo.cs') + '"')
$rspFile = Join-Path $setupDir 'csc.rsp'
[System.IO.File]::WriteAllLines($rspFile, $rsp, (New-Object System.Text.UTF8Encoding($false)))
& $csc /noconfig "@$rspFile"
if ($LASTEXITCODE -ne 0) { throw "Setup build failed ($LASTEXITCODE)" }

# ── 5. verify it is MSIL and references only 4.0.0.0 assemblies ───────────────────────────────────────────────
# Read the facts in a CHILD Windows PowerShell: ReflectionOnlyLoadFrom in-process keeps $setupExe mapped until this
# powershell.exe exits, so a second build in the same console could not overwrite it.
function AsmFacts([string]$path) {
    $helper = Join-Path ([System.IO.Path]::GetTempPath()) ('kodirt-asmfacts-' + $PID + '.ps1')
    $code = @'
param([string]$p)
$a = [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($p)
$r = ($a.GetReferencedAssemblies() | ForEach-Object { $_.Name + ' ' + $_.Version }) -join ', '
'A=' + [System.Reflection.AssemblyName]::GetAssemblyName($p).ProcessorArchitecture
'R=' + $r
'@
    [System.IO.File]::WriteAllText($helper, $code, (New-Object System.Text.UTF8Encoding($false)))
    try {
        $ps  = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $out = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helper $path
        if ($LASTEXITCODE -ne 0) { throw "could not read assembly facts of $path" }
    } finally { Remove-Item $helper -ErrorAction SilentlyContinue }
    $f = @{}
    foreach ($line in $out) { if ($line -match '^([AR])=(.*)$') { $f[$Matches[1]] = $Matches[2] } }
    return $f
}
$facts = AsmFacts $setupExe
$sarch = $facts['A']; $srefs = $facts['R']
"Setup arch = $sarch   refs = $srefs"
if ("$sarch" -ne 'MSIL') { throw "Setup: expected MSIL, got $sarch" }
if ($srefs -match ' [1-9][0-9]*\.[1-9]' -or $srefs -notmatch 'mscorlib 4\.0\.0\.0') { throw "Setup must reference only 4.0.0.0 assemblies: $srefs" }

# ── 6. publish ───────────────────────────────────────────────────────────────────────────────────────────────
$dist = Join-Path $Work 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item $setupExe $dist -Force
$exeOut = Join-Path $dist (Split-Path $setupExe -Leaf)
[System.IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'), (Sha256 $exeOut) + '  ' + (Split-Path $exeOut -Leaf) + "`n", (New-Object System.Text.UTF8Encoding($false)))
"setup:  $exeOut"
"size:   {0:N0} bytes" -f (Get-Item $exeOut).Length
"sha256: $(Sha256 $exeOut)"
