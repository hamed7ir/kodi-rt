# kodi-rt: injected with -DCMAKE_PROJECT_INCLUDE into builds that use the STATIC fribidi from F:/kodi-rt/prefix/arm32
# without its pkg-config file (libass's own FindFriBidi). On _WIN32 fribidi-common.h declares the API dllimport unless
# FRIBIDI_LIB_STATIC is defined (fribidi.pc's Cflags carry it). Kodi builds fribidi as a DLL on Windows; kodi-rt
# builds everything static. (-DCMAKE_C_FLAGS would replace the toolchain's CMAKE_C_FLAGS_INIT, dropping its pins.)
add_compile_definitions(FRIBIDI_LIB_STATIC)
