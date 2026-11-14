# kodi-rt: report the COFF machine type of every object in .obj files and .lib archives (MSVC or GNU/llvm-ar format),
# including short import members and bigobj/anonymous objects (both keep Machine at offset 6).
# Usage: python -I scripts/check-machine.py [--want=0x1c4] <file.obj|file.lib|file.exe|file.dll> ...
# Exit 1 if --want is given and any member has another machine type (or a member is not COFF at all).
import struct, sys

NAMES = {0x14c: 'x86', 0x8664: 'x64', 0x1c4: 'ARMNT', 0xaa64: 'ARM64', 0x1c0: 'ARM'}

RES_SIG = bytes.fromhex('0000000020000000ffff0000ffff0000')   # a compiled resource (.res) file, not an object

def obj_machine(b):
    if len(b) < 8:
        return None, 'short'
    if b[:16] == RES_SIG:                         # e.g. freetype.lib carries its ftver.rc.res: no code, no symbols
        return None, 'res'
    sig1, sig2 = struct.unpack_from('<HH', b, 0)
    if sig1 == 0 and sig2 == 0xFFFF:            # import object or anonymous (bigobj) object
        return struct.unpack_from('<H', b, 6)[0], 'import/anon'
    if b[:4] == b'BC\xc0\xde' or b[:4] == b'\xde\xc0\x17\x0b':
        return None, 'llvm-bitcode'
    return sig1, 'coff'

def archive_members(d):
    off = 8
    while off + 60 <= len(d):
        hdr = d[off:off + 60]
        name = hdr[:16].decode('latin-1').rstrip()
        size = int(hdr[48:58].decode('latin-1').strip() or 0)
        data = d[off + 60:off + 60 + size]
        yield name, data
        off += 60 + size + (size & 1)

def check(path):
    d = open(path, 'rb').read()
    counts, bad = {}, []
    if d[:8] == b'!<arch>\n':
        for name, data in archive_members(d):
            if name in ('/', '//', '/SYM64/', '/<ECSYMBOLS>/', '__.SYMDEF', '__.SYMDEF SORTED'):
                continue
            m, kind = obj_machine(data)
            key = NAMES.get(m, hex(m)) if m is not None else kind
            counts[key] = counts.get(key, 0) + 1
            if m is None and kind != 'res':
                bad.append((name, kind))
    elif d[:2] == b'MZ':
        pe = struct.unpack_from('<I', d, 0x3C)[0]
        m = struct.unpack_from('<H', d, pe + 4)[0]
        counts[NAMES.get(m, hex(m))] = 1
    else:
        m, kind = obj_machine(d)
        counts[NAMES.get(m, hex(m)) if m is not None else kind] = 1
    return counts, bad

want = None
files = []
for a in sys.argv[1:]:
    if a.startswith('--want='):
        want = NAMES.get(int(a[7:], 16), a[7:])
    else:
        files.append(a)
rc = 0
for f in files:
    counts, bad = check(f)
    ok = want is None or (sorted(k for k in counts if k != 'res') == [want])
    print(f"{'OK  ' if ok else 'BAD '} {f}: " + ', '.join(f'{k} x{v}' for k, v in sorted(counts.items())))
    if not ok:
        rc = 1
sys.exit(rc)
