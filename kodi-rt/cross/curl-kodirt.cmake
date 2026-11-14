# kodi-rt: injected with -DCMAKE_PROJECT_INCLUDE into the curl build. cmake/modules/FindCurl.cmake gives curl
# C_FLAGS -DNGHTTP2_STATICLIB on Windows (the static nghttp2 is not dllimport) and links crypt32.lib.
# (-DCMAKE_C_FLAGS would replace the toolchain's CMAKE_C_FLAGS_INIT, dropping its target and SDK pins.)
add_compile_definitions(NGHTTP2_STATICLIB)
link_libraries(crypt32)
