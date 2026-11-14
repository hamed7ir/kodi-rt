# kodi-rt: pycryptodome 3.23.0's C modules (Kodi's pin) for Windows ARM32, x86 and x64, built the way its setup.py
# would (module list from setup.py, scripts/pycd-gen-modules.py -> modules.cmake; macros from compiler_opt.py), but
# with clang-cl and /MT. Each module is a plain DLL named <module>.pyd that pycryptodome opens with ctypes
# (Crypto/Util/_raw_api.py); NO_CPYTHON_MODULE leaves out the dummy PyInit (and Python.h), so they import nothing
# from python314.dll. Installed as <prefix>/Cryptodome/<subpackage>/<module>.pyd (Kodi's "separate namespace" build:
# tools/depends/target/pythonmodule-pycryptodome touches .separate_namespace).
#   compiler_opt.py on these targets: HAVE_STDINT_H, PYCRYPTO_LITTLE_ENDIAN, SYS_BITS, LTC_NO_ASM; x86/x64 also
#   HAVE_INTRIN_H + USE_SSE2, and _raw_aesni (-maes) / _ghash_clmul (-mpclmul -mssse3, HAVE_WMMINTRIN_H,
#   HAVE_TMMINTRIN_H); ARM32 has neither intrinsic set, so those two modules are left out (as compiler_opt.py does).
#   No HAVE_UINT128 (as with MSVC; x64 uses _umul128).
cmake_minimum_required(VERSION 3.20)
project(pycryptodome C)

set(PYCD_SRC "" CACHE PATH "pycryptodome source tree (src/deps/pycryptodome-3.23.0)")
if(NOT EXISTS "${PYCD_SRC}/src/common.h")
  message(FATAL_ERROR "PYCD_SRC=${PYCD_SRC} is not a pycryptodome source tree")
endif()
include(${CMAKE_CURRENT_SOURCE_DIR}/modules.cmake)

if(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm")
  set(_x86 OFF)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^([xX]86|i[3-6]86|AMD64|x86_64|x64)$")
  set(_x86 ON)
else()
  message(FATAL_ERROR "unsupported CMAKE_SYSTEM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR}")
endif()
math(EXPR _bits "8 * ${CMAKE_SIZEOF_VOID_P}")

set(_defs HAVE_STDINT_H PYCRYPTO_LITTLE_ENDIAN SYS_BITS=${_bits} LTC_NO_ASM NO_CPYTHON_MODULE _CRT_SECURE_NO_WARNINGS)
if(_x86)
  list(APPEND _defs HAVE_INTRIN_H USE_SSE2)
endif()

set(_built)
foreach(entry IN LISTS PYCD_MODULES)
  string(REPLACE "|" ";" f "${entry}")
  list(GET f 0 path)
  list(GET f 1 srcs)
  list(GET f 2 incs)
  get_filename_component(sub ${path} DIRECTORY)
  get_filename_component(mod ${path} NAME)
  if(NOT _x86 AND mod MATCHES "^(_raw_aesni|_ghash_clmul)$")
    continue()
  endif()
  string(REPLACE "," ";" srcs "${srcs}")
  string(REPLACE "," ";" incs "${incs}")
  list(TRANSFORM srcs PREPEND ${PYCD_SRC}/)
  list(TRANSFORM incs PREPEND ${PYCD_SRC}/)
  set(tgt ${sub}_${mod})
  add_library(${tgt} SHARED ${srcs})
  target_include_directories(${tgt} PRIVATE ${incs})
  target_compile_definitions(${tgt} PRIVATE ${_defs})
  target_compile_options(${tgt} PRIVATE /Zi -Wno-unused-parameter -Wno-unused-function -Wno-sign-compare
                         -Wno-unused-variable -Wno-missing-braces)
  if(mod STREQUAL "_raw_aesni")
    target_compile_options(${tgt} PRIVATE -maes)
  elseif(mod STREQUAL "_ghash_clmul")
    target_compile_options(${tgt} PRIVATE -mpclmul -mssse3)
    target_compile_definitions(${tgt} PRIVATE HAVE_WMMINTRIN_H HAVE_TMMINTRIN_H)
  endif()
  target_link_options(${tgt} PRIVATE /DEBUG:FULL /OPT:REF /OPT:ICF)
  set_target_properties(${tgt} PROPERTIES OUTPUT_NAME ${mod} PREFIX "" SUFFIX ".pyd")
  install(FILES $<TARGET_FILE:${tgt}> DESTINATION Cryptodome/${sub})     # the DLL only (no import library)
  list(APPEND _built ${sub}/${mod})
endforeach()
list(LENGTH _built _n)
message(STATUS "pycryptodome: ${_n} modules for ${CMAKE_SYSTEM_PROCESSOR}")
