# kodi-rt: libffi 3.5.2 as a static library for Windows ARM32, x86 and x64, for CPython's _ctypes (Kodi's pin,
# src/deps/libffi-3.5.2). libffi itself builds with autotools; on Windows its msvcc.sh (and CPython's
# PCbuild/prepare_libffi.bat) compile the C files with cl and run the assembly through "cl -EP", then armasm, ml or
# ml64. This project does the same with clang-cl (the toolchain file's compiler) and the MSVC assemblers:
#   ARM32  src/arm/ffi.c   + src/arm/sysv_msvc_arm32.S (armasm, Microsoft's Windows ARM32 port; PROLOG_PUSH and
#          NESTED_ENTRY give its functions .pdata/.xdata)
#   x86    src/x86/ffi.c   + src/x86/sysv_intel.S      (ml -safeseh)
#   x64    src/x86/ffiw64.c + src/x86/win64_intel.S    (ml64)
# Headers: ffi.h from include/ffi.h.in, ffitarget.h from src/<arch>, fficonfig.h hand-written (this folder).
# Consumers define FFI_STATIC_BUILD (ffi.h: no dllimport). Installs lib/libffi.lib, include/ffi.h, include/ffitarget.h.
cmake_minimum_required(VERSION 3.20)
project(libffi C)

set(FFI_SRC "" CACHE PATH "libffi source tree (src/deps/libffi-3.5.2)")
set(FFI_MSVC_BIN "" CACHE PATH "MSVC bin/Hostx64 folder (arm/armasm.exe, x86/ml.exe, x64/ml64.exe)")
set(FFI_ARM_SDK_SHARED "" CACHE PATH "ARM32: Windows SDK include/shared folder with ksarm.h, kxarm.h (SDK 10.0.19041; 26100 has none)")
if(NOT EXISTS "${FFI_SRC}/include/ffi.h.in")
  message(FATAL_ERROR "FFI_SRC=${FFI_SRC} is not a libffi source tree")
endif()

if(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm")
  set(TARGET ARM)
  set(_archdir arm)
  set(_csrc src/arm/ffi.c)
  set(_asmsrc src/arm/sysv_msvc_arm32.S)
  set(_assembler "${FFI_MSVC_BIN}/arm/armasm.exe")
  set(_asmargs -nologo -g -oldit)             # msvcc.sh's armasm options
  set(_asmout -o)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^([xX]86|i[3-6]86)$")
  set(TARGET X86_WIN32)
  set(_archdir x86)
  set(_csrc src/x86/ffi.c)
  set(_asmsrc src/x86/sysv_intel.S)
  set(_assembler "${FFI_MSVC_BIN}/x86/ml.exe")
  set(_asmargs -nologo -safeseh -c)
  set(_asmout -Fo)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|x86_64|x64)$")
  set(TARGET X86_WIN64)
  set(_archdir x86)
  set(_csrc src/x86/ffiw64.c)
  set(_asmsrc src/x86/win64_intel.S)
  set(_assembler "${FFI_MSVC_BIN}/x64/ml64.exe")
  set(_asmargs -nologo -c)
  set(_asmout -Fo)
else()
  message(FATAL_ERROR "unsupported CMAKE_SYSTEM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR}")
endif()
if(NOT EXISTS "${_assembler}")
  message(FATAL_ERROR "assembler not found: ${_assembler}")
endif()

# headers (ffi.h.in's @VARS@, as configure would set them for MSVC: long double == double, no trampoline table)
set(VERSION 3.5.2)
set(FFI_VERSION_STRING 3.5.2)
set(FFI_VERSION_NUMBER 30502)
set(HAVE_LONG_DOUBLE 0)
set(HAVE_LONG_DOUBLE_VARIANT 0)
set(FFI_EXEC_TRAMPOLINE_TABLE 0)
set(_inc ${CMAKE_BINARY_DIR}/include)
configure_file(${FFI_SRC}/include/ffi.h.in ${_inc}/ffi.h @ONLY)
configure_file(${FFI_SRC}/src/${_archdir}/ffitarget.h ${_inc}/ffitarget.h COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/fficonfig.h ${_inc}/fficonfig.h COPYONLY)
set(_incs ${_inc} ${FFI_SRC}/include ${FFI_SRC}/src/${_archdir})

# the assembly: preprocess with the C compiler (the toolchain's flags give the target and the SDK includes, where
# armasm's ksarm.h lives), then assemble
get_filename_component(_asmname ${_asmsrc} NAME_WE)
set(_pp ${CMAKE_BINARY_DIR}/${_asmname}.asm)
set(_obj ${CMAKE_BINARY_DIR}/${_asmname}.obj)
separate_arguments(_cflags WINDOWS_COMMAND "${CMAKE_C_FLAGS}")
set(_ppincs)
foreach(d ${_incs})
  list(APPEND _ppincs -I${d})
endforeach()
if("${TARGET}" STREQUAL "ARM")
  if(NOT EXISTS "${FFI_ARM_SDK_SHARED}/ksarm.h")
    message(FATAL_ERROR "ARM32 needs FFI_ARM_SDK_SHARED with ksarm.h (got '${FFI_ARM_SDK_SHARED}')")
  endif()
  list(APPEND _ppincs -I${FFI_ARM_SDK_SHARED})   # only for the assembly: last, after libffi's own folders
endif()
add_custom_command(OUTPUT ${_obj}
  COMMAND ${CMAKE_C_COMPILER} ${_cflags} /nologo /EP /P /Fi${_pp} /TC -DFFI_STATIC_BUILD ${_ppincs} ${FFI_SRC}/${_asmsrc}
  COMMAND ${_assembler} ${_asmargs} ${_asmout}${_obj} ${_pp}
  DEPENDS ${FFI_SRC}/${_asmsrc} ${_inc}/ffi.h ${_inc}/ffitarget.h ${_inc}/fficonfig.h
  COMMENT "libffi: ${_asmsrc} -> ${_asmname}.obj"
  VERBATIM)

add_library(libffi STATIC
  ${FFI_SRC}/src/prep_cif.c ${FFI_SRC}/src/types.c ${FFI_SRC}/src/raw_api.c ${FFI_SRC}/src/java_raw_api.c
  ${FFI_SRC}/src/closures.c ${FFI_SRC}/src/tramp.c ${FFI_SRC}/${_csrc} ${_obj})
target_include_directories(libffi PRIVATE ${_incs})
target_compile_definitions(libffi PRIVATE FFI_STATIC_BUILD _CRT_SECURE_NO_WARNINGS)
target_compile_options(libffi PRIVATE /Zi -Wno-unused-parameter -Wno-sign-compare -Wno-deprecated-declarations)
set_target_properties(libffi PROPERTIES OUTPUT_NAME libffi)

install(TARGETS libffi ARCHIVE DESTINATION lib)
install(FILES ${_inc}/ffi.h ${_inc}/ffitarget.h DESTINATION include)
