# kodi-rt PGO phase 1: the INSTRUMENTED Kodi (scripts/s7-configure.sh PHASE=instr), included by project(kodi) through
# CMAKE_PROJECT_kodi_INCLUDE.
#  - IR-level instrumentation (-fprofile-generate, as Venetium's chrome_pgo_phase=1) for every C and C++ file of the
#    kodi project. The host tools (flatc, JsonSchemaBuilder: ExternalProjects with their own toolchain file) and
#    CMake's try_compile checks don't see directory options, so the configuration equals the normal build's.
#  - Link: the clang runtime folder (clang_rt.profile-arm.lib; the objects ask for it by /DEFAULTLIB and lld-link also
#    finds it by itself) and the periodic profile writer tools/pgo/pgoflush.c (compiled by s7-configure.sh), passed as
#    an object so its CRT initializer is kept. kodi.exe is the only executable or DLL the kodi project links.
add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-fprofile-generate>)
add_link_options(-libpath:F:/kodi-rt/tc/rt24c-cr/lib/clang/23/lib/windows F:/kodi-rt/build/s7/pgoflush/pgoflush.obj)

# Toolchain bug 0034 (reports/toolchain/HANDOFF.md): with /Zi AND -fprofile-generate, a catch funclet's catchret
# continuation (movw/movt r0) can land inside its SEH epilogue and the assembler stops ("Incorrect size for ...
# epilogue"). The first instrumented build hit it in one file of 1693. Those files keep their counters and lose only
# their debug info (/clang:-g0 after /Zi); the profile is the same. Applied at the end of the top-level CMakeLists,
# when the targets exist. Pairs: target, source file under xbmc/.
set(KODIRT_0034_FILES
  cores xbmc/cores/FFmpeg.cpp
)
function(kodirt_0034_nodebug)
  set(_l ${KODIRT_0034_FILES})
  while(_l)
    list(POP_FRONT _l _target _file)
    set_source_files_properties(${CMAKE_SOURCE_DIR}/${_file} TARGET_DIRECTORY ${_target}
                                PROPERTIES COMPILE_OPTIONS "/clang:-g0")
    message(STATUS "kodi-rt 0034 workaround: ${_file} (target ${_target}) without debug info")
  endwhile()
endfunction()
cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL kodirt_0034_nodebug)
