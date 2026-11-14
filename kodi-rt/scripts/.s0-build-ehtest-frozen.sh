#!/bin/bash
# kodi-rt Stage 0: build ehtest (tests/stage0/ehtest/ehtest.cpp) the way Kodi builds C++ on Windows
# (cmake/scripts/windows/CXXFlagOverrides.cmake + windows.cmake at xbmc bffa625c), /MT instead of /MD, no /GL:
#   arm32-rel  rt2.2  armv7-pc-windows-msvc  Release flags      -> the device
#   arm32-od   rt2.2  armv7-pc-windows-msvc  /Od /Ob0           -> the device
#   x86-rel    rt2.2  i686-pc-windows-msvc   Release flags      -> run here: expected output
#   x86-od     rt2.2  i686-pc-windows-msvc   /Od /Ob0           -> run here
#   x86-msvc   MSVC 14.44 cl.exe (Hostx64/x86) Release flags /Z7 -> run here: an independent compiler
# Run from Git Bash: nice -n 10 bash scripts/s0-build-ehtest.sh   (nice 10 = BELOW_NORMAL for native children)
# Arguments (optional): toolchain bin dir, output dir, extra clang-cl flags for the ARM32 builds only
# (e.g. "-mllvm -trap-unreachable"). Defaults: rt2.2, build/s0/ehtest, none.
set -u
export MSYS2_ARG_CONV_EXCL='*'
T=${1:-F:/cr/rt22-cr/bin}
S=F:/kodi-rt/tests/stage0/ehtest/ehtest.cpp
O=${2:-/f/kodi-rt/build/s0/ehtest}
read -r -a ARMX <<< "${3:-}"
VC="D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207"
SDK="D:/Windows Kits/10"
SV=10.0.19041.0
PIN=(-vctoolsdir "$VC" -winsdkdir "$SDK" -winsdkversion $SV)
# Kodi: CMAKE_CXX_FLAGS (minus /MP), ARCH_DEFINES, PLATFORM_DEFINES (NTDDI_WINBLUE / _WIN32_WINNT_WINBLUE), C++20
COMMON=(/nologo /D_UNICODE /DUNICODE /utf-8 /DRPC_USE_NATIVE_WCHAR /DWIN32 /D_WINDOWS /W3 /GR /EHsc /std:c++20
        /DTARGET_WINDOWS /DTARGET_WINDOWS_DESKTOP /D_WIN32_WINNT=0x0603 /DNTDDI_VERSION=0x06030000)
REL=(/MT /Ox /Ob2 /Oi /Ot /Oy /DNDEBUG)
OD=(/MT /Od /Ob0)

clang_build() { # name target vcarch dbgflag optflags...
  local name=$1 target=$2 arch=$3 dbg=$4; shift 4
  local d=$O/$name
  rm -rf "$d"; mkdir -p "$d"; cd "$d" || return 1
  "$T/clang-cl.exe" --target=$target "${PIN[@]}" "${COMMON[@]}" $dbg "$@" /c "$S" /Foehtest.obj > compile.log 2>&1 \
    || { echo "[$name] COMPILE FAILED"; cat compile.log; return 1; }
  local extra=""
  [ "$arch" = "x86" ] && extra="/SAFESEH:NO"
  "$T/lld-link.exe" /nologo /OUT:ehtest.exe /SUBSYSTEM:CONSOLE /DEBUG /PDB:ehtest.pdb /OPT:REF /INCREMENTAL:NO $extra \
    ehtest.obj "/LIBPATH:$VC/lib/$arch" "/LIBPATH:$SDK/Lib/$SV/ucrt/$arch" "/LIBPATH:$SDK/Lib/$SV/um/$arch" \
    kernel32.lib > link.log 2>&1 || { echo "[$name] LINK FAILED"; cat link.log; return 1; }
  echo "[$name] $(stat -c %s ehtest.exe) B, $(grep -c 'warning' compile.log) compile warnings, $(grep -c 'warning' link.log) link warnings"
}

msvc_build() { # name
  local name=$1 d=$O/$1
  rm -rf "$d"; mkdir -p "$d"; cd "$d" || return 1
  local CL="$VC/bin/Hostx64/x86/cl.exe" LINK="$VC/bin/Hostx64/x86/link.exe"
  local OLDPATH=$PATH
  export PATH="/d/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64:/d/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x86:$PATH"
  export INCLUDE="$VC/include;$SDK/Include/$SV/ucrt;$SDK/Include/$SV/um;$SDK/Include/$SV/shared"
  export LIB="$VC/lib/x86;$SDK/Lib/$SV/ucrt/x86;$SDK/Lib/$SV/um/x86"
  "$CL" "${COMMON[@]}" /Z7 "${REL[@]}" /c "$S" /Foehtest.obj > compile.log 2>&1 \
    || { echo "[$name] COMPILE FAILED"; cat compile.log; export PATH=$OLDPATH; return 1; }
  "$LINK" /nologo /OUT:ehtest.exe /SUBSYSTEM:CONSOLE /DEBUG /PDB:ehtest.pdb /OPT:REF /INCREMENTAL:NO /SAFESEH:NO \
    ehtest.obj kernel32.lib > link.log 2>&1 || { echo "[$name] LINK FAILED"; cat link.log; export PATH=$OLDPATH; return 1; }
  export PATH=$OLDPATH
  echo "[$name] $(stat -c %s ehtest.exe) B, $(grep -c 'warning' compile.log) compile warnings"
}

"$T/clang-cl.exe" --version | head -1
[ ${#ARMX[@]} -gt 0 ] && echo "extra ARM32 flags: ${ARMX[*]}"
clang_build arm32-rel armv7-pc-windows-msvc arm /Zi "${REL[@]}" "${ARMX[@]}" || exit 1
clang_build arm32-od  armv7-pc-windows-msvc arm /Zi "${OD[@]}" "${ARMX[@]}" || exit 1
clang_build x86-rel   i686-pc-windows-msvc  x86 /Zi "${REL[@]}" || exit 1
clang_build x86-od    i686-pc-windows-msvc  x86 /Zi "${OD[@]}"  || exit 1
msvc_build  x86-msvc || exit 1
echo "BUILD-EHTEST DONE"
