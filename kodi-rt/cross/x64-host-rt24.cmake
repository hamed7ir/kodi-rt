# kodi-rt CMake toolchain for HOST tools (x64, run on the build server during Kodi's build: flatc,
# JsonSchemaBuilder). Kodi uses ${NATIVEPREFIX}/share/Toolchain-Native.cmake for them when it exists
# (cmake/modules/buildtools/FindJsonSchemaBuilder.cmake:68-70, FindFlatC.cmake:55-56); scripts/s4-apply-patches.sh
# copies this file there. rt2.4 clang-cl for x86_64-pc-windows-msvc, MSVC 14.44, SDK 10.0.26100.0 (it has x64 libs).
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

set(_RT "F:/kodi-rt/tc/rt24c-cr/bin")
set(_VCTOOLS "D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207")
set(_WINSDK "D:/Windows Kits/10")
set(_SDK "10.0.26100.0")

set(CMAKE_C_COMPILER   "${_RT}/clang-cl.exe")
set(CMAKE_CXX_COMPILER "${_RT}/clang-cl.exe")
set(CMAKE_AR           "${_RT}/llvm-lib.exe")
set(CMAKE_LINKER       "${_RT}/lld-link.exe")
set(CMAKE_RC_COMPILER  "${_RT}/llvm-rc.exe")
set(CMAKE_MT           "${_RT}/llvm-mt.exe")

set(_PIN "--target=x86_64-pc-windows-msvc -vctoolsdir \"${_VCTOOLS}\" -winsdkdir \"${_WINSDK}\" -winsdkversion ${_SDK}")
set(CMAKE_C_FLAGS_INIT   "${_PIN}")
set(CMAKE_CXX_FLAGS_INIT "${_PIN} /EHsc")
set(CMAKE_RC_FLAGS_INIT "-I \"${_VCTOOLS}/include\" -I \"${_WINSDK}/Include/${_SDK}/um\" -I \"${_WINSDK}/Include/${_SDK}/shared\" -I \"${_WINSDK}/Include/${_SDK}/ucrt\"")

set(_LIBPATHS "/libpath:\"${_VCTOOLS}/lib/x64\" /libpath:\"${_WINSDK}/Lib/${_SDK}/ucrt/x64\" /libpath:\"${_WINSDK}/Lib/${_SDK}/um/x64\"")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_LIBPATHS}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_LIBPATHS}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_LIBPATHS}")

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
