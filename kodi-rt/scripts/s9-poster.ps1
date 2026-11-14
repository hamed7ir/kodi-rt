# kodi-rt: render the README poster (branding/poster/poster.html, 1920x800 CSS) to branding/poster-v1.0.png at 1.5x
# (2880x1200), with headless Chrome and a throwaway profile under build/ (the way Venetium's poster was made).
# Usage: powershell -NoProfile -File scripts\s9-poster.ps1
$ErrorActionPreference = 'Stop'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$html = 'F:\kodi-rt\branding\poster\poster.html'
$out = 'F:\kodi-rt\branding\poster-v1.0.png'
$prof = 'F:\kodi-rt\build\s9\poster-chrome-profile'
if (Test-Path $prof) { Remove-Item $prof -Recurse -Force }
if (Test-Path $out) { Remove-Item $out -Force }
$args = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1.5', '--window-size=1920,800',
          "--user-data-dir=$prof", '--no-first-run', '--no-default-browser-check', "--screenshot=$out",
          ('file:///' + $html.Replace('\', '/')))
$p = Start-Process -FilePath $chrome -ArgumentList $args -PassThru -WindowStyle Hidden
if (-not $p.WaitForExit(60000)) { Stop-Process -Id $p.Id -Force; throw 'chrome did not finish in 60 s' }
if (-not (Test-Path $out)) { throw "no $out" }
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($out); "poster: $out ($($img.Width)x$($img.Height), $([int]((Get-Item $out).Length / 1KB)) KB)"; $img.Dispose()
Remove-Item $prof -Recurse -Force -ErrorAction SilentlyContinue
