if(MSVC)
  if(DEFINED ENV{MAXTHREADS})
    set(MP_FLAG "/MP$ENV{MAXTHREADS}")
  else()
    set(MP_FLAG "/MP")
  endif()
  set(CMAKE_C_FLAGS "/D_UNICODE /DUNICODE /utf-8 /DRPC_USE_NATIVE_WCHAR ${MP_FLAG} /DWIN32 /D_WINDOWS /W3 /Zi")
  set(CMAKE_C_FLAGS_DEBUG "/D_DEBUG /MDd /Ob0 /Od /RTC1 /D_ITERATOR_DEBUG_LEVEL=0")
  set(CMAKE_C_FLAGS_RELEASE "/MD /Ox /Ob2 /Oi /Ot /Oy /GL /DNDEBUG")
  if(CMAKE_SYSTEM_PROCESSOR STREQUAL arm)
    # kodi-rt: Windows ARM32 with clang-cl. The lines above would replace the toolchain file's flags
    # (--target, -vctoolsdir/-winsdkdir pins), so keep CMAKE_C_FLAGS_INIT in front. /MT: Windows RT 8.1
    # has no UCRT or VC runtime DLLs. No /GL (LTO is off until Kodi runs), no /MP (clang-cl ignores it).
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS_INIT} /D_UNICODE /DUNICODE /utf-8 /DRPC_USE_NATIVE_WCHAR /DWIN32 /D_WINDOWS /W3 /Zi")
    set(CMAKE_C_FLAGS_DEBUG "/D_DEBUG /MTd /Ob0 /Od /D_ITERATOR_DEBUG_LEVEL=0")
    set(CMAKE_C_FLAGS_RELEASE "/MT /Ox /Ob2 /Oi /Ot /Oy /DNDEBUG")
  endif()
endif()

if("$ENV{Platform}" STREQUAL "x86")
  string(APPEND CMAKE_C_FLAGS " /arch:SSE2")
endif()
