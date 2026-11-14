#!/usr/bin/env python3
# kodi-rt: heuristic stack scan of an ARM32 Windows minidump. Takes the exception thread's stack memory from the dump
# (from SP up), keeps every 4-byte value that points into the given module's executable section with the Thumb bit
# set and whose preceding instruction is a BL/BLX (so it is a plausible return address), and prints them as
# module RVAs, ready for llvm-symbolizer. Stale values above live frames also match, so read the list top down.
# Usage: python -I mdump-stack.py <crash.dmp> <module name, e.g. kodi.exe> [max] [start address, hex]
# The start address (e.g. an EXCEPTION_RECORD found by mdump-excscan.py) replaces the exception context's SP.
import struct, sys

path, modname = sys.argv[1], sys.argv[2].lower()
maxn = int(sys.argv[3]) if len(sys.argv) > 3 else 60
start_at = int(sys.argv[4], 16) if len(sys.argv) > 4 else None
d = open(path, 'rb').read()
sig, ver, nstreams, dir_rva = struct.unpack_from('<IIII', d, 0)
assert sig == 0x504d444d
streams = {}
for i in range(nstreams):
    st, size, rva = struct.unpack_from('<III', d, dir_rva + 12 * i)
    streams[st] = (rva, size)

# memory ranges (MemoryListStream = 5)
mem = []
rva, _ = streams[5]
n = struct.unpack_from('<I', d, rva)[0]
for i in range(n):
    start, dsize, drva = struct.unpack_from('<QII', d, rva + 4 + 16 * i)
    mem.append((start, dsize, drva))

def read(addr, size):
    for start, dsize, drva in mem:
        if start <= addr and addr + size <= start + dsize:
            o = drva + (addr - start)
            return d[o:o + size]
    return None

# exception thread and its context (ExceptionStream = 6)
rva, _ = streams[6]
tid = struct.unpack_from('<I', d, rva)[0]
ctx_size, ctx_rva = struct.unpack_from('<II', d, rva + 8 + 152)
ctx = d[ctx_rva:ctx_rva + ctx_size]
# ARM CONTEXT: ContextFlags, R0-R12, Sp, Lr, Pc, Cpsr
regs = struct.unpack_from('<I13IIIII', ctx, 0)
sp, lr, pc = regs[14], regs[15], regs[16]

# module (ModuleListStream = 4)
rva, _ = streams[4]
n = struct.unpack_from('<I', d, rva)[0]
base = size = None
for i in range(n):
    o = rva + 4 + 108 * i
    mbase, msize, csum, ts, name_rva = struct.unpack_from('<QIIII', d, o)
    nlen = struct.unpack_from('<I', d, name_rva)[0]
    name = d[name_rva + 4:name_rva + 4 + nlen].decode('utf-16-le')
    if name.lower().endswith(modname):
        base, size = mbase, msize
assert base is not None, 'module not found'
print(f'thread 0x{tid:x}  sp=0x{sp:08x} lr=0x{lr:08x} pc=0x{pc:08x}  {modname} base=0x{base:x} size=0x{size:x}')

def is_call_before(ret):
    # Thumb: return address ret (bit 0 clear here). BL is 32-bit (F000 D000 pattern), BLX reg is 16-bit (47xx)
    b4 = read(ret - 4, 4)
    b2 = read(ret - 2, 2)
    if b4:
        h1, h2 = struct.unpack('<HH', b4)
        if (h1 & 0xF800) == 0xF000 and (h2 & 0xD000) == 0xD000:   # BL / BLX imm
            return True
    if b2:
        h = struct.unpack('<H', b2)[0]
        if (h & 0xFF87) == 0x4780:                                  # BLX Rm
            return True
    return None if (b4 is None and b2 is None) else False

out = []
if start_at is not None:
    sp = start_at
a = sp
while len(out) < maxn:
    w = read(a, 4)
    if w is None:
        break
    v = struct.unpack('<I', w)[0]
    if base <= v < base + size and (v & 1):
        ret = v & ~1
        c = is_call_before(ret)
        if c is not False:
            out.append((a, v - base, c))
    a += 4
for a, rv, c in out:
    print(f'  [sp+0x{a - sp:04x}] {modname}+0x{rv:x}' + ('' if c else '  (code not in dump)'))
