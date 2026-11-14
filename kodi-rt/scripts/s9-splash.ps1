# kodi-rt: put the right version on Kodi's splash (media/splash.jpg). Kodi master (23.0 alpha) still ships the Kodi 22
# "Piers" RC artwork: "v. 22.0 - RC" on the banner under the logo, and "PIERS" (22's codename) lit up in the names
# below it. This repaints the banner's text area from the banner's own gradient (each column interpolated between a
# clean row above and one below the text), writes the new text in the old text's colour and size, and dims "PIERS" to
# the brightness of the names beside it (feathered, so no edge shows).
# Usage: powershell -NoProfile -File scripts\s9-splash.ps1 -In <splash.jpg> -Out <new.jpg> [-Text "v. 23.0 - ALPHA 1"]
#        [-Preview <banner crop .png>]
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Text = 'v. 23.0 - ALPHA 1',
    [string]$Preview = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$src = New-Object System.Drawing.Bitmap $In
if ($src.Width -ne 1920 -or $src.Height -ne 1080) { throw "expected the 1920x1080 Kodi 22 splash, got $($src.Width)x$($src.Height)" }
$b = New-Object System.Drawing.Bitmap 1920, 1080, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($b); $g.DrawImage($src, 0, 0, 1920, 1080); $g.Dispose(); $src.Dispose()

# 1. the old text: columns 905..1015, rows 739 (above) .. 757 (below) are clean banner; the text is in between
$x0 = 905; $x1 = 1015; $yA = 739; $yB = 757
$dark = [System.Drawing.Color]::White; $minL = 999
for ($x = $x0; $x -le $x1; $x++) {
    for ($y = $yA + 1; $y -lt $yB; $y++) {
        $c = $b.GetPixel($x, $y); $l = $c.R + $c.G + $c.B
        if ($l -lt $minL) { $minL = $l; $dark = $c }
    }
}
"old text's darkest pixel: $($dark.R),$($dark.G),$($dark.B)"
for ($x = $x0; $x -le $x1; $x++) {
    $a = $b.GetPixel($x, $yA); $z = $b.GetPixel($x, $yB)
    for ($y = $yA + 1; $y -lt $yB; $y++) {
        $t = ($y - $yA) / ($yB - $yA)
        $b.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int]($a.R + ($z.R - $a.R) * $t), [int]($a.G + ($z.G - $a.G) * $t), [int]($a.B + ($z.B - $a.B) * $t)))
    }
}

# 2. the new text, centred where the old one was (x 960, rows 743..752: a 10 px cap height)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.SmoothingMode = 'AntiAlias'
$font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$font = New-Object System.Drawing.Font('Segoe UI', [single](10.5 * 13.5 / 10.5), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, [Math]::Max(0, $dark.R - 10), [Math]::Max(0, $dark.G - 10), [Math]::Max(0, $dark.B - 15)))
$fmt = [System.Drawing.StringFormat]::GenericTypographic
$size = $g.MeasureString($Text, $font, 1000, $fmt)
$tx = 960 - $size.Width / 2; $ty = 747.5 - $size.Height / 2
$g.DrawString($Text, $font, $brush, [single]$tx, [single]$ty, $fmt)
"new text '$Text': {0:N1} x {1:N1} px at {2:N1},{3:N1}" -f $size.Width, $size.Height, $tx, $ty
$g.Dispose()

# 3. "PIERS": per-channel gains that give its letters the colour of the letters of "PIKE" beside it (mean colour of
#    the brightest 20% of each box), applied with a feathered mask
function TopMean($bmp, $rx0, $rx1, $ry0, $ry1) {
    $v = New-Object System.Collections.Generic.List[object]
    for ($x = $rx0; $x -le $rx1; $x++) { for ($y = $ry0; $y -le $ry1; $y++) { $v.Add($bmp.GetPixel($x, $y)) } }
    $s = $v | Sort-Object { $_.R + $_.G + $_.B } -Descending | Select-Object -First ([int]($v.Count * 0.2))
    return @(($s | Measure-Object -Property R -Average).Average, ($s | Measure-Object -Property G -Average).Average, ($s | Measure-Object -Property B -Average).Average)
}
$piers = TopMean $b 931 989 787 803
$pike = TopMean $b 1003 1049 787 803
$gain = @(0, 1, 2 | ForEach-Object { [Math]::Min(1.0, $pike[$_] / [Math]::Max(1, $piers[$_])) })
"PIERS letters {0:N0},{1:N0},{2:N0}; PIKE letters {3:N0},{4:N0},{5:N0}; gains {6:N2},{7:N2},{8:N2}" -f $piers[0], $piers[1], $piers[2], $pike[0], $pike[1], $pike[2], $gain[0], $gain[1], $gain[2]
$cx0 = 931; $cx1 = 989; $cy0 = 786; $cy1 = 804; $feather = 10
for ($x = $cx0 - $feather; $x -le $cx1 + $feather; $x++) {
    for ($y = $cy0 - $feather; $y -le $cy1 + $feather; $y++) {
        $dx = [Math]::Max(0, [Math]::Max($cx0 - $x, $x - $cx1)); $dy = [Math]::Max(0, [Math]::Max($cy0 - $y, $y - $cy1))
        $d = [Math]::Sqrt($dx * $dx + $dy * $dy); if ($d -ge $feather) { continue }
        $w = 1.0 - $d / $feather
        $c = $b.GetPixel($x, $y)
        $k = @(0, 1, 2 | ForEach-Object { 1.0 - (1.0 - $gain[$_]) * $w })
        $b.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int]($c.R * $k[0]), [int]($c.G * $k[1]), [int]($c.B * $k[2])))
    }
}

# save: JPEG quality 95
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]95)
$b.Save($Out, $enc, $ep)
"wrote $Out ($((Get-Item $Out).Length) bytes)"
if ($Preview) {
    $r = New-Object System.Drawing.Rectangle 800, 700, 330, 120
    $crop = New-Object System.Drawing.Bitmap ($r.Width * 3), ($r.Height * 3)
    $g = [System.Drawing.Graphics]::FromImage($crop); $g.InterpolationMode = 'NearestNeighbor'
    $g.DrawImage($b, (New-Object System.Drawing.Rectangle 0, 0, ($r.Width * 3), ($r.Height * 3)), $r, [System.Drawing.GraphicsUnit]::Pixel)
    $crop.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $crop.Dispose()
    "preview $Preview"
}
$b.Dispose()
