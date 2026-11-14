set(SOURCES Win32InterfaceForCLog.cpp)

set(HEADERS Win32InterfaceForCLog.h)

# Do not add SSE headers for ARM64 (kodi-rt: nor ARM32)
if(NOT CMAKE_GENERATOR_PLATFORM STREQUAL arm64 AND NOT CMAKE_SYSTEM_PROCESSOR STREQUAL arm)
  list(APPEND HEADERS gpu_memcpy_sse4.h
                      memcpy_sse2.h)
endif()

core_add_library(platform_win32_utils)
