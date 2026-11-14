# kodi-rt: check that every function a PE image imports is exported by the DEVICE's copy of that DLL (the Surface RT's
# System32 DLLs, copied in Stage 0 run 1 to results/stage0-run1/dlls/). A missing export means the program would not
# load on Windows RT 8.1. DLLs absent from the device folder are listed as "not on the device list" (check them by hand:
# the folder holds the DLLs Kodi-like programs need, not all of System32).
# Usage: python -I scripts/check-imports.py <llvm-readobj.exe> <device dll dir>[;<dir>...] <image.exe|.dll> ...
#   Further ';'-separated folders hold DLLs that ship with the program (e.g. python314.dll); the first folder that has
#   a DLL is used.
import os, re, subprocess, sys

readobj, devdirs, images = sys.argv[1], sys.argv[2], sys.argv[3:]
dev = {}
for devdir in devdirs.split(';'):
    for f in os.listdir(devdir):
        dev.setdefault(f.lower(), os.path.join(devdir, f))
cache = {}

def exports(dll):
    key = dll.lower()
    if key not in cache:
        p = dev.get(key)
        if p is None:
            cache[key] = None
        else:
            out = subprocess.run([readobj, '--coff-exports', p], capture_output=True, text=True).stdout
            # names, and ordinals as '#<n>' (imports by ordinal, e.g. oleaut32's and dsound's, name no function)
            cache[key] = (set(re.findall(r'^\s*Name: (\S+)', out, re.M)) |
                          {'#' + o for o in re.findall(r'^\s*Ordinal: (\d+)', out, re.M)})
    return cache[key]

rc = 0
for img in images:
    out = subprocess.run([readobj, '--coff-imports', img], capture_output=True, text=True).stdout
    cur, imports, prev = None, {}, ''
    for line in out.splitlines():
        m = re.match(r'^\s*Name: (\S+)$', line)
        if m and 'Import {' in prev:
            cur = m.group(1); imports.setdefault(cur, [])
        m2 = re.match(r'^\s*Symbol: (\S*) \((\d+)\)', line)
        if m2 and cur:
            # "Symbol:  (6)" is an import by ordinal: check it as '#6'
            imports[cur].append(m2.group(1) if m2.group(1) else '#' + m2.group(2))
        prev = line
    print(f'== {img}')
    for dll, syms in imports.items():
        if re.match(r'^(api|ext)-ms-', dll, re.I):
            # API sets are not files on Windows 8.1: scripts/apiset-resolve.py checks them through the device's schema
            print(f'   {dll}: {len(syms)} functions; API set, checked by scripts/apiset-resolve.py')
            continue
        ex = exports(dll)
        if ex is None:
            print(f'   {dll}: {len(syms)} functions; NOT ON THE DEVICE LIST'); rc = 1; continue
        missing = [s for s in syms if s not in ex]
        print(f'   {dll}: {len(syms)} functions, {len(syms) - len(missing)} exported by the device copy' +
              (f'; MISSING: {", ".join(missing)}' if missing else ''))
        if missing:
            rc = 1
sys.exit(rc)
