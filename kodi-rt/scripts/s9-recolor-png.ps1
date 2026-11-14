# kodi-rt: turn the hue of every pixel of a PNG by a fixed angle (saturation, value and alpha stay), the PNG twin of
# scripts/s9-recolor-icon.py: Kodi's blue becomes purple, white and grey stay. Used for media/vendor_logo.png (the Kodi
# logo on Estuary's home and login screens) with the app icon's 85 degrees.
# Usage: powershell -NoProfile -File scripts\s9-recolor-png.ps1 -In <png> -Out <png> [-Turn 85]
param([Parameter(Mandatory = $true)][string]$In, [Parameter(Mandatory = $true)][string]$Out, [double]$Turn = 85)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class HueTurn {
    public static void Apply(Bitmap b, double turn) {
        var r = new Rectangle(0, 0, b.Width, b.Height);
        var d = b.LockBits(r, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int n = d.Stride * b.Height; var px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n);
        for (int i = 0; i < n; i += 4) {
            double B = px[i] / 255.0, G = px[i + 1] / 255.0, R = px[i + 2] / 255.0;
            double max = Math.Max(R, Math.Max(G, B)), min = Math.Min(R, Math.Min(G, B)), c = max - min;
            if (c <= 0) continue;
            double h = max == R ? ((G - B) / c) % 6 : max == G ? (B - R) / c + 2 : (R - G) / c + 4;
            h = (h * 60 + turn) % 360; if (h < 0) h += 360;
            double s = c / max, v = max, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - c, r1 = 0, g1 = 0, b1 = 0;
            if (h < 60) { r1 = c; g1 = x; } else if (h < 120) { r1 = x; g1 = c; } else if (h < 180) { g1 = c; b1 = x; }
            else if (h < 240) { g1 = x; b1 = c; } else if (h < 300) { r1 = x; b1 = c; } else { r1 = c; b1 = x; }
            px[i] = (byte)Math.Round((b1 + m) * 255); px[i + 1] = (byte)Math.Round((g1 + m) * 255); px[i + 2] = (byte)Math.Round((r1 + m) * 255);
        }
        Marshal.Copy(px, 0, d.Scan0, n); b.UnlockBits(d);
    }
}
"@
$src = New-Object System.Drawing.Bitmap $In
$b = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($b); $g.DrawImage($src, 0, 0, $src.Width, $src.Height); $g.Dispose(); $src.Dispose()
[HueTurn]::Apply($b, $Turn)
$b.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
"wrote $Out (hue +$Turn)"
