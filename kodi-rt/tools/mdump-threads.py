#!/usr/bin/env python3
# kodi-rt: list the threads of an ARM32 Windows minidump: thread id, stack range, and pc/lr/sp from each thread's
# saved context (as module+RVA for the given module). Shows which thread's stack holds a given address.
# Usage: python -I mdump-threads.py <crash.dmp> <module name, e.g. kodi.exe> [address to locate, hex]
import struct, sys

path, modname = sys.argv[1], sys.argv[2].lower()
find = int(sys.argv[3], 16) if len(sys.argv) > 3 else None
d = open(path, 'rb').read()
sig, ver, nstreams, dir_rva = struct.unpack_from('<IIII', d, 0)
streams = {}
for i in range(nstreams):
    st, size, rva = struct.unpack_from('<III', d, dir_rva + 12 * i)
    streams[st] = (rva, size)
rva, _ = streams[4]
n = struct.unpack_from('<I', d, rva)[0]
base = size = None
for i in range(n):
    o = rva + 4 + 108 * i
    mbase, msize, csum, ts, name_rva = struct.unpack_from('<QIIII', d, o)
    nlen = struct.unpack_from('<I', d, name_rva)[0]
    if d[name_rva + 4:name_rva + 4 + nlen].decode('utf-16-le').lower().endswith(modname):
        base, size = mbase, msize
def where(v):
    return f'{modname}+0x{v - base:x}' if base is not None and base <= v < base + size else f'0x{v:08x}'
erva, _ = streams[6]
etid = struct.unpack_from('<I', d, erva)[0]
rva, _ = streams[3]
n = struct.unpack_from('<I', d, rva)[0]
for i in range(n):
    # MINIDUMP_THREAD: ThreadId, SuspendCount, PriorityClass, Priority, Teb(8), Stack(MEMORY_DESCRIPTOR 16), Context(8)
    o = rva + 4 + 48 * i
    tid, susp, pcls, prio, teb, sstart, ssize, srva, csize, crva = struct.unpack_from('<IIIIQQIIII', d, o)
    regs = struct.unpack_from('<I13IIIII', d, crva)
    sp, lr, pc = regs[14], regs[15], regs[16]
    mark = '  <- exception stream thread' if tid == etid else ''
    hit = ''
    if find is not None and sstart <= find < sstart + ssize:
        hit = f'  <- stack holds 0x{find:08x}'
    print(f'tid {tid:5d} (0x{tid:x}) stack 0x{sstart:08x}-0x{sstart + ssize:08x} sp=0x{sp:08x} pc={where(pc)} lr={where(lr)}{mark}{hit}')
