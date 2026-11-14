#!/bin/sh
# kodi-rt: TARGET C/C++ compiler for FFmpeg's configure (from ffmpeg-rt's cross/cc-arm32.sh). clang-cl, MSVC ABI,
# ARM32, static CRT (-MT), rt2.4 0549949d, SDK headers 10.0.26100.0. The @rsp carries -vctoolsdir etc. (values with
# spaces). Never pass that rsp via --extra-cflags: configure feeds --extra-cflags to the assembler too.
exec "F:/kodi-rt/tc/rt24b-cr/bin/clang-cl.exe" "@F:/kodi-rt/cross/arm32-msvc.rsp" -MT "$@"
