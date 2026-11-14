# kodi-rt: fstrcmp 0.7.D001 (Kodi's pin) as a static library. Its own build is autotools (Kodi's depends:
# ./configure, make lib/libfstrcmp.la); this builds the same library (every lib/*.c, as Makefile.in's libfstrcmp
# objects) with a config.h written for MSVC (cross/cmake/fstrcmp/config.h). Exports fstrcmp::fstrcmp, which
# cmake/modules/FindFstrcmp.cmake takes from find_package(fstrcmp CONFIG).
# Configure with -DFSTRCMP_SRC=<fstrcmp-0.7.D001 directory>.
cmake_minimum_required(VERSION 3.20)
project(fstrcmp VERSION 0.7 LANGUAGES C)
file(GLOB _srcs ${FSTRCMP_SRC}/lib/*.c)
# program_name.c (POSIX readlink) and version_print.c serve only fstrcmp's command-line program: nothing else in lib/
# uses them, fstrcmp.h does not declare them, and Kodi calls only fstrcmp() (3 call sites).
list(FILTER _srcs EXCLUDE REGEX "/(program_name|version_print)\\.c$")
add_library(fstrcmp STATIC ${_srcs})
# the sources include <lib/config.h>, <lib/ac/...>: the package root and a folder holding lib/config.h
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/cfg/lib)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h ${CMAKE_CURRENT_BINARY_DIR}/cfg/lib/config.h COPYONLY)
target_include_directories(fstrcmp PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/cfg ${FSTRCMP_SRC})
target_include_directories(fstrcmp INTERFACE $<INSTALL_INTERFACE:include>)
target_compile_definitions(fstrcmp PRIVATE _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_WARNINGS)
install(TARGETS fstrcmp EXPORT fstrcmpTargets ARCHIVE DESTINATION lib)
install(FILES ${FSTRCMP_SRC}/lib/fstrcmp.h DESTINATION include)
install(EXPORT fstrcmpTargets FILE fstrcmp-config.cmake NAMESPACE fstrcmp:: DESTINATION lib/cmake/fstrcmp)
include(CMakePackageConfigHelpers)
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/fstrcmp-config-version.cmake VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/fstrcmp-config-version.cmake DESTINATION lib/cmake/fstrcmp)
