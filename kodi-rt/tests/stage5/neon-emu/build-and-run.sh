#!/bin/bash
# kodi-rt: build and run the x64 bit-exactness test of libavcodec/arm/hevcdsp_mc10_neon.c (see test-mc10.c).
# The NEON file is compiled for x64 with include/arm_neon.h (scalar stand-in) and linked against the pure-C x64
# reference FFmpeg (build/s2/ffmpeg-x64ref/build). Usage (Git Bash): bash tests/stage5/neon-emu/build-and-run.sh
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24c-cr/bin
S=F:/kodi-rt/build/s2/ffmpeg-9.0.2-kodi
B=F:/kodi-rt/build/s2/ffmpeg-x64ref/build
T=F:/kodi-rt/tests/stage5/neon-emu
O=F:/kodi-rt/build/s5/neon-emu
mkdir -p /f/kodi-rt/build/s5/neon-emu
CF="@F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo -O2 -I$T/include -I$B -I$S -DHAVE_AV_CONFIG_H /std:c17 -Wno-unused-function"
"$RT/clang-cl.exe" $CF -c "$S/libavcodec/arm/hevcdsp_mc10_neon.c" "-Fo$O/mc10.obj" || { echo "BUILD FAILED (mc10)"; exit 1; }
"$RT/clang-cl.exe" $CF -c "$T/test-mc10.c" "-Fo$O/test.obj" || { echo "BUILD FAILED (test)"; exit 1; }
"$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo "$O/test.obj" "$O/mc10.obj" "$B/libavcodec/avcodec.lib" \
  "$B/libavutil/avutil.lib" "-Fe$O/test-mc10.exe" -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp bcrypt.lib \
  user32.lib ole32.lib || { echo "LINK FAILED"; exit 1; }
"$O/test-mc10.exe"
