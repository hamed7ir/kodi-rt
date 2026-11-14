"""decode-handler-map.py - show the two HandlerType entries of repro/handlers/h2-rt23-arm.obj, and what MSVC's
ARM32 runtime (16-byte HandlerType, ehdata.h:93-107) reads as entry 1.

Usage: python -I decode-handler-map.py h2-rt23-arm.obj [first_entry_offset=0x84] [stride=20]
The offsets come from `llvm-objdump -r`: the Type relocation of each entry is at entry+4, the Handler one at entry+12
(rt2.3: 0x88/0x90 and 0x9c/0xa4, so entry 0 is at 0x84 and entry 1 at 0x98). Relocated fields read as 0 in the .obj.
"""
import struct
import sys

path = sys.argv[1]
first = int(sys.argv[2], 0) if len(sys.argv) > 2 else 0x84
stride = int(sys.argv[3], 0) if len(sys.argv) > 3 else 20
data = open(path, 'rb').read()
nsec = struct.unpack_from('<H', data, 2)[0]
optsz = struct.unpack_from('<H', data, 16)[0]
for i in range(nsec):
    off = 20 + optsz + 40 * i
    name = data[off:off + 8].rstrip(b'\0').decode('latin1')
    size = struct.unpack_from('<I', data, off + 16)[0]
    ptr = struct.unpack_from('<I', data, off + 20)[0]
    if name != '.xdata' or size < first + 2 * stride:
        continue
    sec = data[ptr:ptr + size]
    for e in range(2):
        start = first + e * stride
        adj, dtype, dcatch, dhand = struct.unpack_from('<Iiii', sec, start)
        extra = ''
        if stride == 20:
            extra = ' dispFrame=0x%x' % struct.unpack_from('<I', sec, start + 16)[0]
        print('compiler entry %d @0x%x: adjectives=0x%x dispType=<reloc> dispCatchObj=%d dispOfHandler=<reloc>%s'
              % (e, start, adj, dcatch, extra))
    adj, dtype, dcatch, dhand = struct.unpack_from('<Iiii', sec, first + 16)
    print('MSVC ARM32 runtime view of entry 1 @0x%x: adjectives=0x%x dispType=%d (0 = catch(...)) '
          'dispCatchObj=0x%08x dispOfHandler=%d' % (first + 16, adj, dtype, dcatch & 0xffffffff, dhand))
    break
