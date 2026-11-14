#!/usr/bin/env python3
# kodi-rt Python stage: the source edits behind patches/python/*.patch, applied to a fresh copy of CPython 3.14.10
# (build/py/src/Python-3.14.10, made by scripts/py-prepare-src.sh). Each replacement must match the given number of
# times. The patch file is the record; this script makes it reproducible.
# Usage: python -I scripts/py-src-edits.py <copy of the CPython source>
import os, sys

root = sys.argv[1]

def edit(rel, old, new, count=1):
    p = os.path.join(root, rel)
    s = open(p, encoding='utf-8', newline='').read()
    n = s.count(old)
    if n != count:
        raise SystemExit(f'{rel}: expected {count} match(es), found {n}:\n{old}')
    open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
    print(f'edited {rel} ({n}x)')

# ---------------------------------------------------------------- 0001: mimalloc TLS callbacks on Windows ARM32
# mimalloc forces its TLS callbacks into the link with /INCLUDE pragmas. Its "32-bit" branch spells the symbols with
# the x86 leading underscore (__tls_used, __mi_tls_callback_pre, ...); 32-bit ARM decorates C names like x64 does,
# without it, so lld-link reported them undefined. ARM32 takes the 64-bit branch's names (in all three init modes).
edit('Objects/mimalloc/prim/windows/prim.c',
     '  #if defined(_WIN64) && defined(_MSC_VER) // 64-bit\n',
     '  #if (defined(_WIN64) || defined(_M_ARM)) && defined(_MSC_VER) // 64-bit; ARM32 has no leading underscore either\n',
     count=3)
