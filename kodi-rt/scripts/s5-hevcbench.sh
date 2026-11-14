#!/bin/bash
# kodi-rt Stage 5: build tests/stage5/hevcbench/hevcbench.c (decode speed outside Kodi), for ARM32 against the FFmpeg
#   build directory build/s2/ffmpeg-arm32 (the build with the 10-bit HEVC NEON code, not yet installed into the
#   prefix), and for x64 against the pure-C reference build (for the server dry run).
# Usage (Git Bash): bash scripts/s5-hevcbench.sh     Output: build/s5/hevcbench/{arm32,x64}/hevcbench.exe
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24c-cr/bin
SRC=F:/kodi-rt/build/s2/ffmpeg-9.0.2-kodi
PFX=F:/kodi-rt/prefix/arm32
O=F:/kodi-rt/build/s5/hevcbench
rm -rf "$O"; mkdir -p "$O/arm32" "$O/x64"

B=F:/kodi-rt/build/s2/ffmpeg-arm32
"$RT/clang-cl.exe" @F:/kodi-rt/cross/arm32-msvc.rsp -MT -O2 -W3 -nologo -c F:/kodi-rt/tests/stage5/hevcbench/hevcbench.c \
  "-Fo$O/arm32/hevcbench.obj" "-I$B" "-I$SRC" || { echo "COMPILE FAILED (arm32)"; exit 1; }
"$RT/lld-link.exe" -nologo "$O/arm32/hevcbench.obj" "$B/libavformat/avformat.lib" "$B/libavcodec/avcodec.lib" \
  "$B/libswresample/swresample.lib" "$B/libavutil/avutil.lib" "$PFX/lib/libdav1d.lib" "$PFX/lib/z.lib" \
  @F:/kodi-rt/cross/arm32-link.rsp -out:"$O/arm32/hevcbench.exe" -subsystem:console -opt:ref \
  ole32.lib user32.lib ws2_32.lib bcrypt.lib kernel32.lib || { echo "LINK FAILED (arm32)"; exit 1; }

X=F:/kodi-rt/build/s2/ffmpeg-x64ref/build
"$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -O2 -W3 -nologo -c F:/kodi-rt/tests/stage5/hevcbench/hevcbench.c \
  "-Fo$O/x64/hevcbench.obj" "-I$X" "-I$SRC" || { echo "COMPILE FAILED (x64)"; exit 1; }
"$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo "$O/x64/hevcbench.obj" "$X/libavformat/avformat.lib" \
  "$X/libavcodec/avcodec.lib" "$X/libswresample/swresample.lib" "$X/libavutil/avutil.lib" "-Fe$O/x64/hevcbench.exe" \
  -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp ole32.lib user32.lib ws2_32.lib bcrypt.lib \
  || { echo "LINK FAILED (x64)"; exit 1; }
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$O/arm32/hevcbench.exe")" || exit 1
python -I F:/kodi-rt/scripts/check-imports.py "$RT/llvm-readobj.exe" F:/kodi-rt/results/stage0-run5/dlls \
  "$(cygpath -m "$O/arm32/hevcbench.exe")" | tail -8
echo "HEVCBENCH BUILD DONE"
