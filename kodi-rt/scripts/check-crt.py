# kodi-rt: report which C runtime each object in .lib/.obj files was compiled for, from the linker directives in its
# .drectve section: /DEFAULTLIB:LIBCMT (/MT), MSVCRT (/MD), LIBCMTD/MSVCRTD (debug), none (/Zl, or no CRT use),
# and C++'s /FAILIFMISMATCH:"RuntimeLibrary=..." when present. kodi-rt links everything /MT.
# Usage: python -I scripts/check-crt.py [--want=MT] <file.lib|file.obj> ...   (exit 1 if a member is not MT/none)
import re, struct, sys

def members(d):
    if d[:8] != b'!<arch>\n':
        yield '', d
        return
    off = 8
    while off + 60 <= len(d):
        h = d[off:off + 60]
        name = h[:16].decode('latin-1').rstrip()
        size = int(h[48:58].decode('latin-1').strip() or 0)
        yield name, d[off + 60:off + 60 + size]
        off += 60 + size + (size & 1)

def directives(o):
    if len(o) < 20:
        return None
    if o[:4] == b'BC\xc0\xde':
        # LLVM bitcode (ThinLTO objects, PGO phase 2): the linker directives are llvm.linker.options metadata, stored
        # as plain strings in the module's metadata string blob. Collect every /DEFAULTLIB: and /FAILIFMISMATCH: in it
        # (classify() reads the same text as from a .drectve section). Marked so the summary can count them.
        found = re.findall(rb'/(?:DEFAULTLIB|FAILIFMISMATCH):[\x21-\x7e]+', o, re.I)
        return ' '.join(x.decode('latin-1') for x in found) + ' <bitcode>'
    sig1, sig2 = struct.unpack_from('<HH', o, 0)
    if sig1 == 0 and sig2 == 0xFFFF:
        return None                      # import or bigobj member: not handled (none expected here)
    nsec = struct.unpack_from('<H', o, 2)[0]
    optsz = struct.unpack_from('<H', o, 16)[0]
    base = 20 + optsz
    out = b''
    for i in range(nsec):
        s = base + 40 * i
        if o[s:s + 8].rstrip(b'\0') == b'.drectve':
            size, ptr = struct.unpack_from('<II', o, s + 16)
            out += o[ptr:ptr + size]
    return out.decode('latin-1', 'replace')

def classify(dr):
    up = dr.upper()
    kinds = set()
    for lib, k in (('LIBCMTD', 'MTd'), ('MSVCRTD', 'MDd'), ('LIBCMT', 'MT'), ('MSVCRT', 'MD')):
        if re.search(r'/DEFAULTLIB:"?' + lib + r'(\.LIB)?"?(\s|$)', up):
            kinds.add(k)
    m = re.search(r'RUNTIMELIBRARY=(\w+)', up)
    if m:
        kinds.add({'MT_STATICRELEASE': 'MT', 'MD_DYNAMICRELEASE': 'MD', 'MTD_STATICDEBUG': 'MTd',
                   'MDD_DYNAMICDEBUG': 'MDd'}.get(m.group(1), m.group(1)))
    return kinds or {'none'}

rc = 0
for f in [a for a in sys.argv[1:] if not a.startswith('--')]:
    counts = {}
    for name, o in members(open(f, 'rb').read()):
        if name in ('/', '//', '/SYM64/', '/<ECSYMBOLS>/'):
            continue
        dr = directives(o)
        if dr is None:
            continue
        for k in classify(dr):
            counts[k] = counts.get(k, 0) + 1
        if dr.endswith('<bitcode>'):
            counts['(bitcode)'] = counts.get('(bitcode)', 0) + 1
    bad = [k for k in counts if k not in ('MT', 'none', '(bitcode)')]
    print(f"{'BAD ' if bad else 'OK  '} {f}: " + ', '.join(f'{k} x{v}' for k, v in sorted(counts.items())))
    if bad:
        rc = 1
sys.exit(rc)
