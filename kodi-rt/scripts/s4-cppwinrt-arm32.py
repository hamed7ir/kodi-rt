# kodi-rt Stage 4: an ARM32-capable C++/WinRT base.h for the 10.0.26100.0 SDK headers.
# C++/WinRT 2.0.250303.5 (SDK 26100) dropped 32-bit ARM: its base.h #errors on _M_ARM in three places. The
# 10.0.19041.0 SDK's C++/WinRT (2.0.190x) still had ARM32 there, but can't be used instead: it includes
# <experimental/coroutine>, which MSVC 14.44's STL refuses for clang, and Kodi's AsyncHelpers.h needs the newer
# winrt::impl::is_sta_thread (both measured). So: copy the 26100 base.h unchanged except for those three spots, which
# get the 19041 version's ARM32 code back:
#   1. WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER for _M_ARM: __dmb(_ARM_BARRIER_ISH)       (19041 base.h:5180-5181)
#   2. interlocked_read_32 for _M_ARM: __iso_volatile_load32 + that barrier                (19041 base.h:5194-5197)
#   3. the SLIST_HEADER zero-initialization check accepts _M_ARM                           (19041 base.h:5316)
# The copy keeps CPPWINRT_VERSION, so the SDK's projection headers (which include "winrt/base.h" and check the version)
# work with it. The toolchain file puts F:/kodi-rt/cross/cppwinrt-arm32 first among the system include folders (-imsvc
# comes before the SDK's own), so "winrt/base.h" resolves to this copy. The SDK itself is not changed.
# Usage: python -I scripts/s4-cppwinrt-arm32.py
import hashlib, os

SRC = r'D:\Windows Kits\10\Include\10.0.26100.0\cppwinrt\winrt\base.h'
OUT = r'F:\kodi-rt\cross\cppwinrt-arm32\winrt\base.h'
s = open(SRC, encoding='utf-8', newline='').read()
print('source', SRC, 'sha256', hashlib.sha256(s.encode('utf-8')).hexdigest())
assert '#define CPPWINRT_VERSION "2.0.250303.5"' in s, 'unexpected C++/WinRT version'
nl = '\r\n' if '\r\n' in s else '\n'

def edit(old, new):
    global s
    old, new = old.replace('\n', nl), new.replace('\n', nl)
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'expected 1 match, found {n}:\n{old}')
    s = s.replace(old, new)

edit('#elif defined _M_ARM64\n#define WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER (__dmb(_ARM64_BARRIER_ISH));\n#endif\n',
     '#elif defined _M_ARM64\n#define WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER (__dmb(_ARM64_BARRIER_ISH));\n'
     '#elif defined _M_ARM // kodi-rt: ARM32, as in the 10.0.19041.0 SDK\'s C++/WinRT\n'
     '#define WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER (__dmb(_ARM_BARRIER_ISH));\n#endif\n')
edit('        int32_t const result = __iso_volatile_load32(reinterpret_cast<int32_t const volatile*>(target));\n'
     '#endif\n'
     '        WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER\n'
     '        return result;\n'
     '#else\n'
     '#error Unsupported architecture\n',
     '        int32_t const result = __iso_volatile_load32(reinterpret_cast<int32_t const volatile*>(target));\n'
     '#endif\n'
     '        WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER\n'
     '        return result;\n'
     '#elif defined _M_ARM // kodi-rt: ARM32, as in the 10.0.19041.0 SDK\'s C++/WinRT\n'
     '        int32_t const result = __iso_volatile_load32(reinterpret_cast<int32_t const volatile*>(target));\n'
     '        WINRT_IMPL_INTERLOCKED_READ_MEMORY_BARRIER\n'
     '        return result;\n'
     '#else\n'
     '#error Unsupported architecture\n')
edit('#if !defined _M_IX86 && !defined _M_X64 && !defined _M_ARM64\n#error Unsupported architecture: verify that zero-initialization of SLIST_HEADER is still safe\n',
     '#if !defined _M_IX86 && !defined _M_X64 && !defined _M_ARM && !defined _M_ARM64 // kodi-rt: + _M_ARM (as 19041)\n'
     '#error Unsupported architecture: verify that zero-initialization of SLIST_HEADER is still safe\n')
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8', newline='').write(s)
print('wrote', OUT, 'sha256', hashlib.sha256(s.encode('utf-8')).hexdigest())
