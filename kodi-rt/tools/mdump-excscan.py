#!/usr/bin/env python3
# kodi-rt: look through every thread stack saved in an ARM32 Windows minidump for the EXCEPTION_RECORD and ARM CONTEXT
# that KiUserExceptionDispatcher leaves on the stack of a thread that is handling an exception. Finds what a thread
# other than the one in the exception stream was doing when it, too, raised or hit an exception.
# Usage: python -I mdump-excscan.py <crash.dmp> <module name, e.g. kodi.exe> [thread id, decimal]
import struct, sys

path, modname = sys.argv[1], sys.argv[2].lower()
only = int(sys.argv[3]) if len(sys.argv) > 3 else None
d = open(path, 'rb').read()
sig, ver, nstreams, dir_rva = struct.unpack_from('<IIII', d, 0)
streams = {}
for i in range(nstreams):
    st, size, rva = struct.unpack_from('<III', d, dir_rva + 12 * i)
    streams[st] = (rva, size)

mods = []
rva, _ = streams[4]
n = struct.unpack_from('<I', d, rva)[0]
for i in range(n):
    o = rva + 4 + 108 * i
    mbase, msize, csum, ts, name_rva = struct.unpack_from('<QIIII', d, o)
    nlen = struct.unpack_from('<I', d, name_rva)[0]
    name = d[name_rva + 4:name_rva + 4 + nlen].decode('utf-16-le').split('\\')[-1]
    mods.append((mbase, msize, name))

def where(v):
    for b, s, nm in mods:
        if b <= v < b + s:
            return f'{nm}+0x{v - b:x}'
    return f'0x{v:08x}'

KNOWN = {0xC0000005: 'ACCESS_VIOLATION', 0xC00000FF: 'BAD_FUNCTION_TABLE', 0xE06D7363: 'C++ exception',
         0xC0000025: 'NONCONTINUABLE_EXCEPTION', 0xC0000026: 'INVALID_DISPOSITION', 0xC0000409: 'STACK_BUFFER_OVERRUN',
         0xC00000FD: 'STACK_OVERFLOW', 0x80000003: 'BREAKPOINT', 0xC000001D: 'ILLEGAL_INSTRUCTION',
         0xC0000028: 'BAD_STACK', 0xC0000194: 'POSSIBLE_DEADLOCK', 0x406D1388: 'SetThreadName'}

rva, _ = streams[3]
n = struct.unpack_from('<I', d, rva)[0]
for i in range(n):
    o = rva + 4 + 48 * i
    tid, susp, pcls, prio, teb, sstart, ssize, srva, csize, crva = struct.unpack_from('<IIIIQQIIII', d, o)
    if only is not None and tid != only:
        continue
    stack = d[srva:srva + ssize]
    hits = []
    for off in range(0, ssize - 80, 4):
        code, flags, rec, addr, npar = struct.unpack_from('<IIIII', stack, off)
        if code in KNOWN and flags in (0, 1, 2, 8, 9, 0x10, 0x20, 0x40, 0x41, 0x60, 0x61) and npar <= 15:
            params = struct.unpack_from(f'<{npar}I', stack, off + 20) if npar else ()
            hits.append(f'  EXCEPTION_RECORD @0x{sstart + off:08x}: code 0x{code:08x} {KNOWN[code]} flags 0x{flags:x} '
                        f'next 0x{rec:08x} address {where(addr)} params [{", ".join(hex(p) for p in params)}]')
        cf = struct.unpack_from('<I', stack, off)[0]
        if (cf & 0xFFFFFF00) == 0x00200000 and (cf & 0xFF) in (1, 3, 7, 0xF, 0x17, 0x1F) and off + 0x48 <= ssize:
            regs = struct.unpack_from('<I13IIIII', stack, off)
            sp, lr, pc, cpsr = regs[14], regs[15], regs[16], regs[17]
            if sstart - 0x100000 <= sp < sstart + ssize + 0x100000 and (cpsr & 0x1F) in (0x10, 0x1F):
                r = ' '.join(f'r{k}={regs[1 + k]:08x}' for k in range(13))
                hits.append(f'  CONTEXT @0x{sstart + off:08x}: flags 0x{cf:08x} pc={where(pc)} lr={where(lr)} sp=0x{sp:08x} '
                            f'cpsr=0x{cpsr:08x}\n      {r}')
    print(f'tid {tid} (0x{tid:x}) stack 0x{sstart:08x}-0x{sstart + ssize:08x}: {len(hits)} hit(s)')
    for h in hits:
        print(h)
