#!/bin/sh
# kodi-rt: cross/as-arm32.sh with rt2.4 0318206a (tc/rt24c-cr): the assembler for FFmpeg's GAS-syntax ARM .S files in
# the PGO builds (build/s7), so FFmpeg's C and assembly come from the same toolchain as Kodi.
exec "F:/kodi-rt/tc/rt24c-cr/bin/clang.exe" --target=armv7-pc-windows-msvc "$@"
