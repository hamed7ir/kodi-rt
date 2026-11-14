# kodi-rt: byte-compare two PE images and explain every differing range (section, offset, the bytes as text).
# Usage: python -I pe-diff.py <a.exe> <b.exe>
import struct, sys

def load(p):
    d = open(p, 'rb').read()
    pe = struct.unpack_from('<I', d, 0x3C)[0]
    nsec = struct.unpack_from('<H', d, pe + 6)[0]
    optsz = struct.unpack_from('<H', d, pe + 20)[0]
    opt = pe + 24
    secs = []
    for i in range(nsec):
        o = opt + optsz + 40 * i
        name = d[o:o + 8].rstrip(b'\0').decode()
        vsz, va, rsz, roff = struct.unpack_from('<IIII', d, o + 8)
        secs.append((name, roff, rsz, va))
    return d, pe, secs

a, pea, sa = load(sys.argv[1])
b, peb, sb = load(sys.argv[2])
print(f'sizes {len(a)} / {len(b)}; sections a: {[(n, hex(r), s) for n, r, s, _ in sa]}')
print(f'                 sections b: {[(n, hex(r), s) for n, r, s, _ in sb]}')
if len(a) != len(b) or [x[:3] for x in sa] != [x[:3] for x in sb]:
    print('LAYOUT DIFFERS')
    sys.exit(1)
diffs = [i for i in range(len(a)) if a[i] != b[i]]
ranges = []
for i in diffs:
    if ranges and i - ranges[-1][1] <= 8:
        ranges[-1][1] = i
    else:
        ranges.append([i, i])

def where(off):
    if off < sa[0][1]:
        if pea + 8 <= off < pea + 12:
            return 'PE header: TimeDateStamp'
        if pea + 24 + 64 <= off < pea + 24 + 68:
            return 'PE header: CheckSum'
        return 'headers'
    for n, r, s, va in sa:
        if r <= off < r + s:
            return f'{n}+0x{off - r:x} (rva 0x{va + off - r:x})'
    return 'beyond sections'

print(f'{len(diffs)} differing bytes in {len(ranges)} ranges')
for s, e in ranges:
    ctx_a = a[max(0, s - 24):e + 25]
    ctx_b = b[max(0, s - 24):e + 25]
    show = lambda x: ''.join(chr(c) if 32 <= c < 127 else '.' for c in x)
    print(f'  0x{s:x}-0x{e:x} ({e - s + 1} B) {where(s)}')
    print(f'     a: {show(ctx_a)}')
    print(f'     b: {show(ctx_b)}')
