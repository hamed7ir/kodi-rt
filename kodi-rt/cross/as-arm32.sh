#!/bin/sh
# kodi-rt: ASSEMBLER for FFmpeg's GAS-syntax ARM .S files (from ffmpeg-rt's cross/as-arm32.sh): clang's GCC driver
# with the integrated assembler, rt2.4 0549949d.
exec "F:/kodi-rt/tc/rt24b-cr/bin/clang.exe" --target=armv7-pc-windows-msvc "$@"
