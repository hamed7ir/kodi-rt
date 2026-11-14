#!/bin/sh
# kodi-rt PGO phase 2: TARGET C compiler for FFmpeg with the device profile and ThinLTO (scripts/s7-ffmpeg-pgo.sh).
# rt2.4 f6e5f8e0 (tc/rt24d-cr; its IR passes equal 0318206a's, which instrumented phase 1, so the profile matches).
#  -fprofile-use: build/s7/prof/kodi-20261113.profdata (llvm-profdata merge of results/s7-pgo-run1's raw profile)
#  -flto=thin:    the objects are bitcode; lld-link does the codegen when it links kodi.exe
#  -pgso=false:   code the profile never ran keeps -O2 instead of size optimization (the profile covers DXVA H.264 and
#                 x265 at skiploopfilter 48; software H.264, the HEVC loop filter etc. were not run)
#  -Wno-profile-*: functions without, or with changed, profile data are expected (Chromium's set)
exec "F:/kodi-rt/tc/rt24d-cr/bin/clang-cl.exe" "@F:/kodi-rt/cross/arm32-msvc.rsp" -MT \
  -fprofile-use=F:/kodi-rt/build/s7/prof/kodi-20261113.profdata -flto=thin -mllvm -pgso=false \
  -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -Wno-backend-plugin "$@"
