# kodi-rt: recolor an .ico whose images are 32-bit DIBs (Kodi's application.ico): every pixel's hue is turned by a
# fixed angle, saturation, value and alpha stay, so the blue logo becomes purple and greys/white stay as they are.
# Also writes a PNG preview of the largest image (to look at the result).
# Usage: python -I scripts/s9-recolor-icon.py <in.ico> <out.ico> <hue degrees> [preview.png]
import colorsys, struct, sys, zlib


def recolor_dib(d, off, size, w, h, turn):
    hdr = struct.unpack_from('<IiiHHIIiiII', d, off)
    if hdr[0] != 40 or hdr[4] != 32:
        raise SystemExit(f'not a 32-bit BITMAPINFOHEADER DIB (size {hdr[0]}, bpp {hdr[4]})')
    out = bytearray(d[off:off + size])
    px = 40
    rows = []
    for i in range(w * h):
        b, g, r, a = out[px + 4 * i:px + 4 * i + 4]
        hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s > 0.0:
            hh = (hh + turn / 360.0) % 1.0
            r2, g2, b2 = colorsys.hsv_to_rgb(hh, s, v)
            out[px + 4 * i:px + 4 * i + 3] = bytes((round(b2 * 255), round(g2 * 255), round(r2 * 255)))
    return bytes(out)


def png(path, w, h, bgra_bottom_up):
    raw = bytearray()
    for y in range(h - 1, -1, -1):
        raw.append(0)
        row = bgra_bottom_up[y * w * 4:(y + 1) * w * 4]
        for x in range(w):
            b, g, r, a = row[4 * x:4 * x + 4]
            raw += bytes((r, g, b, a))
    def chunk(t, c):
        return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + \
        chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(data)


src, dst, turn = sys.argv[1], sys.argv[2], float(sys.argv[3])
preview = sys.argv[4] if len(sys.argv) > 4 else None
d = open(src, 'rb').read()
_, typ, n = struct.unpack_from('<HHH', d, 0)
if typ != 1:
    raise SystemExit('not an icon')
out = bytearray(d)
best = None
for i in range(n):
    w, h, _, _, _, bpp, size, off = struct.unpack_from('<BBBBHHII', d, 6 + 16 * i)
    w, h = w or 256, h or 256
    if d[off:off + 8] == b'\x89PNG\r\n\x1a\n':
        raise SystemExit('PNG-compressed icon images are not handled')
    new = recolor_dib(d, off, size, w, h, turn)
    out[off:off + size] = new
    print(f'image {i}: {w}x{h} {bpp} bpp recolored')
    if best is None or w > best[0]:
        best = (w, h, new[40:40 + w * h * 4])
open(dst, 'wb').write(bytes(out))
print(f'wrote {dst}')
if preview:
    png(preview, *best)
    print(f'preview {preview}')
