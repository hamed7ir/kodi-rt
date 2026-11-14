# kodi-rt PGO phase 2: Kodi with the device profile and ThinLTO (scripts/s7-configure.sh PHASE=use, toolchain file
# cross/arm32-rt24d.cmake = rt2.4 f6e5f8e0), included by project(kodi) through CMAKE_PROJECT_kodi_INCLUDE.
#  - C/C++ only (not RC/ASM): -fprofile-use with build/s7/prof/kodi-20261113.profdata (phase 1's device run,
#    results/s7-pgo-run1), -flto=thin, -mllvm -pgso=false (code the profile never ran keeps -O2 instead of size
#    optimization), and the profile warnings for unprofiled or changed functions off (Chromium's set).
#  - Link: lld-link does the ThinLTO codegen for Kodi and the bitcode FFmpeg libraries (prefix/arm32-ffpgo) with 8
#    backend jobs (the server's -j8 rule) and a cache for relinks; -pgso=false for the backend too, where the loop
#    optimizations run.
# try_compile checks don't see directory options, so the configuration equals the normal build's.
set(_KODIRT_PROFDATA F:/kodi-rt/build/s7/prof/kodi-20261113.profdata)
add_compile_options(
  "$<$<COMPILE_LANGUAGE:C,CXX>:-fprofile-use=${_KODIRT_PROFDATA}>"
  "$<$<COMPILE_LANGUAGE:C,CXX>:-flto=thin>"
  "$<$<COMPILE_LANGUAGE:C,CXX>:-mllvm>"
  "$<$<COMPILE_LANGUAGE:C,CXX>:-pgso=false>"
  "$<$<COMPILE_LANGUAGE:C,CXX>:-Wno-profile-instr-unprofiled>"
  "$<$<COMPILE_LANGUAGE:C,CXX>:-Wno-profile-instr-out-of-date>"
  "$<$<COMPILE_LANGUAGE:C,CXX>:-Wno-backend-plugin>")
add_link_options(/opt:lldltojobs=8 /lldltocache:F:/kodi-rt/build/s7/ltocache /mllvm:-pgso=false)
