# kodi-rt CMake toolchain for PGO phase 2: cross/arm32-rt24.cmake with rt2.4 f6e5f8e0 (tc/rt24d-cr: 0033 + 0034 fixed).
# Based on the tgcalls kit's tc/arm32-rt21.cmake (from hamed7ir/adb-rt's arm32-clang-cl.cmake), moved to rt2.4.
#  - -vctoolsdir/-winsdkdir/-winsdkversion PIN the toolset and SDK: MSVC 14.44 is the last toolset with ARM32
#    (14.51 #errors in vadefs.h). Headers from SDK 10.0.26100.0, import libraries from 10.0.19041.0 (the last SDK
#    with ARM32 libs): Hamed's decision of 2026-11-12, the same split as Venetium's ARM32 build.
#  - CMAKE_SYSTEM_PROCESSOR is lowercase "arm" (some projects match "(arm|aarch64)" case-sensitively for NEON).
#  - Static CRT (/MT).
#  - Never pass flags through an env CFLAGS: it breaks CMake's MSVC architecture detection (handoff trap 9).
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_SYSTEM_VERSION 10.0)

# rt2.4 with 0032 fixed (0318206a, from the llvm-rt session 2026-11-12) since Stage 4; Stages 2-3's prefix libraries
# were built with rt2.4 0549949d (tc/rt24b-cr), which the meson/autotools/OpenSSL wrappers in cross/ still name.
set(_RT "F:/kodi-rt/tc/rt24d-cr/bin")
set(_VCTOOLS "D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207")
set(_WINSDK "D:/Windows Kits/10")
set(_SDKINC "10.0.26100.0")
set(_SDKLIB "10.0.19041.0")

set(CMAKE_C_COMPILER   "${_RT}/clang-cl.exe")
set(CMAKE_CXX_COMPILER "${_RT}/clang-cl.exe")
set(CMAKE_ASM_COMPILER "${_RT}/clang.exe")
set(CMAKE_AR           "${_RT}/llvm-lib.exe")
set(CMAKE_LINKER       "${_RT}/lld-link.exe")
set(CMAKE_RC_COMPILER  "${_RT}/llvm-rc.exe")
set(CMAKE_MT           "${_RT}/llvm-mt.exe")

set(_PIN "--target=armv7-pc-windows-msvc -vctoolsdir \"${_VCTOOLS}\" -winsdkdir \"${_WINSDK}\" -winsdkversion ${_SDKINC}")
set(CMAKE_C_FLAGS_INIT   "${_PIN}")
# /EHsc: CMake 3.31 gives clang-cl "/DWIN32 /D_WINDOWS" but no /EHsc, so C++ was built with exceptions OFF (measured:
# spdlog failed "cannot use 'throw' with exceptions disabled", fmt silently switched to its no-exceptions mode).
# Kodi compiles with /EHsc; every C++ library must too.
# C++/WinRT: the 26100 SDK's base.h (2.0.250303.5) #errors on _M_ARM. cross/cppwinrt-arm32/winrt/base.h is that file
# with the 10.0.19041.0 version's three ARM32 branches restored (scripts/s4-cppwinrt-arm32.py); -imsvc folders are
# searched before the SDK's, so "winrt/base.h" resolves to it. Kodi uses C++/WinRT for audio device enumeration.
set(CMAKE_CXX_FLAGS_INIT "${_PIN} /EHsc -imsvc F:/kodi-rt/cross/cppwinrt-arm32")
set(CMAKE_ASM_FLAGS_INIT "--target=armv7-pc-windows-msvc")
# Resource scripts: CMake preprocesses .rc files with clang-cl (cmake_llvm_rc) using only the RC flags, without the
# -vctoolsdir/-winsdkdir pins above, so give it the include folders directly (both clang-cl -E and llvm-rc take -I).
set(CMAKE_RC_FLAGS_INIT "-I \"${_VCTOOLS}/include\" -I \"${_WINSDK}/Include/${_SDKINC}/um\" -I \"${_WINSDK}/Include/${_SDKINC}/shared\" -I \"${_WINSDK}/Include/${_SDKINC}/ucrt\"")

set(_LIBPATHS "/libpath:\"${_VCTOOLS}/lib/arm\" /libpath:\"${_WINSDK}/Lib/${_SDKLIB}/ucrt/arm\" /libpath:\"${_WINSDK}/Lib/${_SDKLIB}/um/arm\"")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_LIBPATHS}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_LIBPATHS}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_LIBPATHS}")

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
cmake_policy(SET CMP0091 NEW)
# A project whose cmake_minimum_required is below 3.15 leaves CMP0091 unset, i.e. OLD: it ignores
# CMAKE_MSVC_RUNTIME_LIBRARY and puts /MD into CMAKE_<LANG>_FLAGS_<CONFIG> (measured: harfbuzz, crossguid, lzo2).
# Setting CMAKE_POLICY_DEFAULT_CMP0091 here is too late (cmake_minimum_required has already run when the toolchain
# file is read; measured). Pass -DCMAKE_POLICY_DEFAULT_CMP0091=NEW on the cmake command line (scripts/s3-cmake.sh does),
# and check the result with scripts/check-crt.py.

set(CMAKE_FIND_ROOT_PATH "F:/kodi-rt/prefix/arm32")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
