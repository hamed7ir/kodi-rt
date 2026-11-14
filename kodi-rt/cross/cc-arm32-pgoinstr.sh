#!/bin/sh
# kodi-rt PGO phase 1: TARGET C compiler for the INSTRUMENTED FFmpeg (scripts/s7-ffmpeg-instr.sh). cross/cc-arm32.sh
# with rt2.4 0318206a (tc/rt24c-cr, Kodi's toolchain, which ships clang_rt.profile-arm.lib) and IR-level
# instrumentation (-fprofile-generate, as Venetium's chrome_pgo_phase=1). Every object asks for
# clang_rt.profile-arm.lib by /DEFAULTLIB; lld-link finds it in tc/rt24c-cr/lib/clang/23/lib/windows (the s7 scripts
# also pass that -libpath). Never put -fprofile-generate into --extra-cflags: configure feeds those to the assembler.
exec "F:/kodi-rt/tc/rt24c-cr/bin/clang-cl.exe" "@F:/kodi-rt/cross/arm32-msvc.rsp" -MT -fprofile-generate "$@"
