# kodi-rt: the video OSD's fullscreen/window icons in Estuary's OSD icon style (Hamed, 2026-11-14: the button was
# bigger than the rest; he asked for an "expand" and a "collapse" icon). Estuary's OSD icons
# (media/osd/fullscreen/buttons/*.png) are flat white on a transparent 128x128 canvas, the drawing about 64-80 px in
# the middle; the old button reused icons/now-playing/fullscreen.png, an 80x80 icon drawn edge to edge, so it showed
# larger in the same 74x74 box.
#   fullscreen.png  shown in a window: a diagonal double arrow to the corners ("go fullscreen")
#   windowed.png    shown in fullscreen: two arrows pointing in from the corners ("back to a window")
# Usage: powershell -NoProfile -File scripts\s9-osd-icons.ps1 [-Out <folder>] [-Preview <png>]
param([string]$Out = 'F:\kodi-rt\branding\osd', [string]$Preview = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
$W = 9   # stroke width at 128 px (the playlist icon's check mark weight)

function NewIcon() {
    $b = New-Object System.Drawing.Bitmap 128, 128, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
    $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), $W
    $p.StartCap = 'Square'; $p.EndCap = 'Square'; $p.LineJoin = 'Miter'
    return @($b, $g, $p)
}
function Pts([double[]]$xy) {
    $a = New-Object 'System.Drawing.PointF[]' ($xy.Count / 2)
    for ($i = 0; $i -lt $a.Count; $i++) { $a[$i] = New-Object System.Drawing.PointF ([single]$xy[2 * $i]), ([single]$xy[2 * $i + 1]) }
    return , $a
}
function Save($icon, [string]$name) {
    $icon[2].Dispose(); $icon[1].Dispose()
    $icon[0].Save((Join-Path $Out $name), [System.Drawing.Imaging.ImageFormat]::Png); $icon[0].Dispose()
    "wrote $(Join-Path $Out $name)"
}

# fullscreen.png: corner brackets at top right and bottom left, joined by the diagonal
$i = NewIcon
$i[1].DrawLines($i[2], (Pts 70, 38, 90, 38, 90, 58))
$i[1].DrawLines($i[2], (Pts 38, 70, 38, 90, 58, 90))
$i[1].DrawLine($i[2], 84, 44, 44, 84)
Save $i 'fullscreen.png'

# windowed.png: from each corner an arrow in towards the middle, its bracket at the inner end
$i = NewIcon
$i[1].DrawLines($i[2], (Pts 72, 40, 72, 56, 88, 56))
$i[1].DrawLine($i[2], 92, 36, 76, 52)
$i[1].DrawLines($i[2], (Pts 40, 72, 56, 72, 56, 88))
$i[1].DrawLine($i[2], 36, 92, 52, 76)
Save $i 'windowed.png'

if ($Preview) {
    # the new icons beside Estuary's own, at the OSD's size (74 px) and at 2x, on a dark background
    $m = 'F:\kodi-rt\build\s9\kodi\addons\skin.estuary\media\osd\fullscreen\buttons'
    $list = @("$m\settings.png", "$m\playlist.png", "$m\streams.png", (Join-Path $Out 'fullscreen.png'), (Join-Path $Out 'windowed.png'))
    $sheet = New-Object System.Drawing.Bitmap (90 * $list.Count + 20), (90 + 266)
    $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(18, 18, 18)); $g.InterpolationMode = 'HighQualityBicubic'
    for ($k = 0; $k -lt $list.Count; $k++) {
        $img = [System.Drawing.Image]::FromFile($list[$k])
        $g.DrawImage($img, 10 + 90 * $k, 8, 74, 74)
        $img.Dispose()
    }
    for ($k = 3; $k -lt $list.Count; $k++) {
        $img = [System.Drawing.Image]::FromFile($list[$k]); $g.DrawImage($img, 10 + 266 * ($k - 3), 90, 256, 256); $img.Dispose()
    }
    $g.Dispose(); $sheet.Save($Preview); $sheet.Dispose(); "preview $Preview"
}
