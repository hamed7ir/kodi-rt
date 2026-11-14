# kodi-rt: Pillow 12.0.0's C extension modules (Kodi's pin) for Windows ARM32, x86 and x64, with the features of Kodi's
# own tools/depends build (target/pythonmodule-pil: jpeg, zlib, freetype with raqm on harfbuzz + fribidi; jpeg2000,
# webp, imagequant, tiff, xcb and lcms disabled). Source lists come from setup.py (scripts/pil-gen-sources.py ->
# sources.cmake), the defines from its build_extensions(). clang-cl /MT; each module is a real CPython extension
# (<module>.pyd linking python314.lib), installed as <prefix>/PIL/<module>.pyd:
#   _imaging       core + decoders/encoders; HAVE_LIBJPEG (libjpeg-turbo 3.1.4.1, scripts/py-deps.sh <arch> jpeg),
#                  HAVE_LIBZ (the prefix's zlib, zs.lib)
#   _imagingft     FreeType text; raqm vendored in Pillow (src/thirdparty/raqm), on the prefix's HarfBuzz and FriBidi
#                  (HAVE_RAQM, HAVE_FRIBIDI_SYSTEM; static FriBidi needs FRIBIDI_LIB_STATIC)
#   _imagingmath, _imagingmorph   no libraries
# Not built: _imagingtk (needs tkinter, which this Python leaves out), _imagingcms, _webp, _avif (disabled by Kodi /
# no library).
cmake_minimum_required(VERSION 3.20)
project(pillow C)

set(PIL_SRC "" CACHE PATH "Pillow source tree (src/deps/pillow-12.0.0)")
set(PIL_PYTHON "" CACHE PATH "the target's Python install (prefix/<arch>/python: include/, libs/python314.lib)")
set(PIL_DEPS_PREFIX "" CACHE PATH "the target's prefix (jpeg-static.lib, zs.lib, freetype.lib, harfbuzz.lib, fribidi.lib)")
foreach(f ${PIL_SRC}/src/_imaging.c ${PIL_PYTHON}/include/Python.h ${PIL_PYTHON}/libs/python314.lib
          ${PIL_DEPS_PREFIX}/lib/jpeg-static.lib ${PIL_DEPS_PREFIX}/lib/zs.lib ${PIL_DEPS_PREFIX}/lib/freetype.lib
          ${PIL_DEPS_PREFIX}/lib/harfbuzz.lib ${PIL_DEPS_PREFIX}/lib/fribidi.lib)
  if(NOT EXISTS ${f})
    message(FATAL_ERROR "missing ${f}")
  endif()
endforeach()
include(${CMAKE_CURRENT_SOURCE_DIR}/sources.cmake)
file(STRINGS ${PIL_SRC}/src/PIL/_version.py _v REGEX "^__version__")
string(REGEX MATCH "\"([^\"]+)\"" _m "${_v}")
set(PILLOW_VERSION ${CMAKE_MATCH_1})
message(STATUS "Pillow ${PILLOW_VERSION} for ${CMAKE_SYSTEM_PROCESSOR}")

list(TRANSFORM PIL_IMAGING_SOURCES PREPEND ${PIL_SRC}/)
list(TRANSFORM PIL_MODE_SOURCES PREPEND ${PIL_SRC}/)

set(_opts /Zi -Wno-unused-parameter -Wno-sign-compare -Wno-unused-function -Wno-unused-variable
          -Wno-deprecated-declarations -Wno-missing-field-initializers)

add_library(pil_imaging_mode STATIC ${PIL_MODE_SOURCES})
target_include_directories(pil_imaging_mode PRIVATE ${PIL_PYTHON}/include ${PIL_SRC}/src/libImaging)
target_compile_options(pil_imaging_mode PRIVATE ${_opts})

function(pil_module name)
  add_library(${name} MODULE ${ARGN})
  target_include_directories(${name} PRIVATE ${PIL_PYTHON}/include ${PIL_SRC}/src/libImaging ${PIL_SRC}/src)
  target_compile_definitions(${name} PRIVATE _CRT_SECURE_NO_WARNINGS)
  target_compile_options(${name} PRIVATE ${_opts})
  # pyconfig.h asks for python314.lib by name (#pragma comment): give the linker its folder too
  target_link_options(${name} PRIVATE /DEBUG:FULL /OPT:REF /OPT:ICF /LIBPATH:${PIL_PYTHON}/libs)
  target_link_libraries(${name} PRIVATE ${PIL_PYTHON}/libs/python314.lib)
  set_target_properties(${name} PROPERTIES PREFIX "" SUFFIX ".pyd")
  install(FILES $<TARGET_FILE:${name}> DESTINATION PIL)
endfunction()

pil_module(_imaging ${PIL_IMAGING_SOURCES})
target_compile_definitions(_imaging PRIVATE HAVE_LIBJPEG HAVE_LIBZ "PILLOW_VERSION=\"${PILLOW_VERSION}\"")
target_include_directories(_imaging PRIVATE ${PIL_DEPS_PREFIX}/include)
target_link_libraries(_imaging PRIVATE pil_imaging_mode ${PIL_DEPS_PREFIX}/lib/jpeg-static.lib
                      ${PIL_DEPS_PREFIX}/lib/zs.lib kernel32 user32 gdi32)

pil_module(_imagingft ${PIL_SRC}/src/_imagingft.c ${PIL_SRC}/src/thirdparty/raqm/raqm.c)
target_compile_definitions(_imagingft PRIVATE HAVE_RAQM HAVE_FRIBIDI_SYSTEM FRIBIDI_LIB_STATIC)
target_include_directories(_imagingft PRIVATE ${PIL_DEPS_PREFIX}/include/freetype2
                           ${PIL_DEPS_PREFIX}/include/harfbuzz ${PIL_DEPS_PREFIX}/include/fribidi ${PIL_DEPS_PREFIX}/include)
target_link_libraries(_imagingft PRIVATE pil_imaging_mode ${PIL_DEPS_PREFIX}/lib/freetype.lib
                      ${PIL_DEPS_PREFIX}/lib/harfbuzz.lib ${PIL_DEPS_PREFIX}/lib/fribidi.lib)

pil_module(_imagingmath ${PIL_SRC}/src/_imagingmath.c)
pil_module(_imagingmorph ${PIL_SRC}/src/_imagingmorph.c)
