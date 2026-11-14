#!/bin/bash
# kodi-rt: build tools/rtprof/rtprof.c for ARM32 (the tablet) and x64 (server dry run).
# Usage (Git Bash): bash scripts/s6-rtprof.sh     Output: build/s6/rtprof/{arm32,x64}/rtprof.exe
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24c-cr/bin
O=F:/kodi-rt/build/s6/rtprof
rm -rf "$O"; mkdir -p "$O/arm32" "$O/x64"
"$RT/clang-cl.exe" @F:/kodi-rt/cross/arm32-msvc.rsp -MT -O2 -W3 -nologo -c F:/kodi-rt/tools/rtprof/rtprof.c \
  "-Fo$O/arm32/rtprof.obj" || { echo "COMPILE FAILED (arm32)"; exit 1; }
"$RT/lld-link.exe" -nologo "$O/arm32/rtprof.obj" @F:/kodi-rt/cross/arm32-link.rsp -out:"$O/arm32/rtprof.exe" \
  -subsystem:console -opt:ref kernel32.lib winmm.lib || { echo "LINK FAILED (arm32)"; exit 1; }
"$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -O2 -W3 -nologo -c F:/kodi-rt/tools/rtprof/rtprof.c \
  "-Fo$O/x64/rtprof.obj" || { echo "COMPILE FAILED (x64)"; exit 1; }
"$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo "$O/x64/rtprof.obj" "-Fe$O/x64/rtprof.exe" \
  -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp winmm.lib || { echo "LINK FAILED (x64)"; exit 1; }
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$O/arm32/rtprof.exe")" || exit 1
python -I F:/kodi-rt/scripts/check-imports.py "$RT/llvm-readobj.exe" F:/kodi-rt/results/stage0-run5/dlls \
  "$(cygpath -m "$O/arm32/rtprof.exe")" | tail -6
echo "RTPROF BUILD DONE"
