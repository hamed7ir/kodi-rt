# kodi-rt: injected with -DCMAKE_PROJECT_INCLUDE into the libass build (Kodi's 01-win-CMakeLists.patch etc.).
# 1. libass's own FindFriBidi (from Kodi's patch) uses the library without fribidi.pc, so FRIBIDI_LIB_STATIC
#    (needed for the static fribidi, see fribidi-static.cmake) is added here.
# 2. Kodi's 02-win-dwrite-fontload.patch passes a 'const wchar_t **' where DirectWrite's C interface takes
#    'const void **' (ass_directwrite.c:898, IDWriteFontFile_GetReferenceKey). MSVC, which Kodi's Windows build uses,
#    only warns; clang 23 rejects incompatible pointer types in C by default (measured, no -Werror involved). The
#    conversion is harmless for this out-parameter, so keep it a warning, as in Kodi's build.
add_compile_definitions(FRIBIDI_LIB_STATIC)
add_compile_options(-Wno-error=incompatible-pointer-types)
