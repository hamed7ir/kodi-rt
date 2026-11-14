# kodi-rt: resolve API-set DLL names (api-ms-win-*.dll, ext-ms-win-*.dll) through a device's own apisetschema.dll
# (Windows 8.1: schema version 4, in the DLL's .apiset section), and optionally check that every function a PE image
# imports from an API set is exported by the host DLL the schema names (from the device DLL folder).
# Usage:
#   python -I scripts/apiset-resolve.py <apisetschema.dll> api-ms-win-core-winrt-l1-1-0.dll ...
#   python -I scripts/apiset-resolve.py <apisetschema.dll> --check <llvm-readobj.exe> <device dll dir> <image.exe>
# Exit 1 if a name doesn't resolve, or (with --check) a function is missing from its host DLL.
import os, re, struct, subprocess, sys

def sections(d):
    pe = struct.unpack_from('<I', d, 0x3C)[0]
    nsec = struct.unpack_from('<H', d, pe + 6)[0]
    optsz = struct.unpack_from('<H', d, pe + 20)[0]
    for i in range(nsec):
        o = pe + 24 + optsz + 40 * i
        name = d[o:o + 8].rstrip(b'\0').decode('latin-1')
        vsz, va, rsz, roff = struct.unpack_from('<IIII', d, o + 8)
        yield name, d[roff:roff + rsz]

def load_schema(path):
    d = open(path, 'rb').read()
    data = dict(sections(d)).get('.apiset')
    if data is None:
        raise SystemExit(f'{path}: no .apiset section')
    version = struct.unpack_from('<I', data, 0)[0]
    if version != 4:
        raise SystemExit(f'{path}: schema version {version}, this reader knows version 4 (Windows 8.1)')
    _, size, flags, count = struct.unpack_from('<IIII', data, 0)
    u16 = lambda off, ln: data[off:off + ln].decode('utf-16-le')
    schema = {}
    for i in range(count):
        eflags, noff, nlen, aoff, alen, doff = struct.unpack_from('<IIIIII', data, 16 + 24 * i)
        name = u16(noff, nlen).lower()          # e.g. "ms-win-core-winrt-l1-1-0" (no "api-", no ".dll")
        vflags, vcount = struct.unpack_from('<II', data, doff)
        hosts = []
        for j in range(vcount):
            f2, n2off, n2len, voff, vlen = struct.unpack_from('<IIIII', data, doff + 8 + 20 * j)
            hosts.append((u16(n2off, n2len), u16(voff, vlen)))   # (importing module or '', host dll)
        schema[name] = hosts
    return schema

def resolve(schema, dll):
    n = dll.lower()
    if n.endswith('.dll'):
        n = n[:-4]
    for prefix in ('api-', 'ext-'):
        if n.startswith(prefix):
            key = n[4:]
            break
    else:
        return None
    hosts = schema.get(key)
    if hosts is None:
        return None
    default = [h for importer, h in hosts if importer == '']
    return default[0] if default and default[0] else (hosts[0][1] if hosts else None)

def main():
    schema = load_schema(sys.argv[1])
    args = sys.argv[2:]
    rc = 0
    if args and args[0] == '--check':
        readobj, devdir, image = args[1:4]
        dev = {f.lower(): os.path.join(devdir, f) for f in os.listdir(devdir)}
        out = subprocess.run([readobj, '--coff-imports', image], capture_output=True, text=True).stdout
        cur, imports, prev = None, {}, ''
        for line in out.splitlines():
            m = re.match(r'^\s*Name: (\S+)$', line)
            if m and 'Import {' in prev:
                cur = m.group(1); imports.setdefault(cur, [])
            m2 = re.match(r'^\s*Symbol: (\S+) \(\d+\)', line)
            if m2 and cur:
                imports[cur].append(m2.group(1))
            prev = line
        for dll, syms in imports.items():
            if not re.match(r'^(api|ext)-ms-', dll, re.I):
                continue
            host = resolve(schema, dll)
            if not host:
                print(f'   {dll}: NOT IN THE DEVICE SCHEMA'); rc = 1; continue
            p = dev.get(host.lower())
            if not p:
                print(f'   {dll} -> {host}: host DLL not in the device folder ({len(syms)} functions unchecked)'); rc = 1; continue
            ex = set(re.findall(r'^\s*Name: (\S+)', subprocess.run([readobj, '--coff-exports', p], capture_output=True,
                                                                   text=True).stdout, re.M))
            missing = [s for s in syms if s not in ex]
            print(f'   {dll} -> {host}: {len(syms)} functions, {len(syms) - len(missing)} exported by the device copy'
                  + (f'; MISSING: {", ".join(missing)}' if missing else ''))
            if missing:
                rc = 1
    else:
        for dll in args:
            host = resolve(schema, dll)
            print(f'{dll} -> {host if host else "NOT IN THE SCHEMA"}')
            if not host:
                rc = 1
    sys.exit(rc)

main()
