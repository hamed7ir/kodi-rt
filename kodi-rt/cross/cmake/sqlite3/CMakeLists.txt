# kodi-rt: SQLite 3.39.4 (Kodi's pin, the autoconf amalgamation) as a static library, built from sqlite3.c the way
# Kodi's depends builds it (tools/depends/target/sqlite3/Makefile: ./configure --disable-shared --enable-threadsafe,
# CFLAGS -DSQLITE_TEMP_STORE=3 -DSQLITE_DEFAULT_MMAP_SIZE=0x10000000), with the autoconf build's default features
# (configure.ac: math, fts4, fts5, rtree + geopoly on; fts3, session off). Kodi's SQLITE_ENABLE_COLUMN_METADATA goes in
# through CXXFLAGS, which never reach this C file, and Kodi's code doesn't use that API, so it stays off as there.
# Exports sqlite3::sqlite3 (what cmake/modules/FindSqlite3.cmake takes from find_package(sqlite3 CONFIG)).
# Configure with -DSQLITE_SRC=<the patched sqlite-autoconf-3390400 directory>.
cmake_minimum_required(VERSION 3.20)
project(sqlite3 VERSION 3.39.4 LANGUAGES C)
add_library(sqlite3 STATIC ${SQLITE_SRC}/sqlite3.c)
target_compile_definitions(sqlite3 PRIVATE SQLITE_TEMP_STORE=3 SQLITE_DEFAULT_MMAP_SIZE=0x10000000 SQLITE_THREADSAFE=1
  SQLITE_ENABLE_MATH_FUNCTIONS SQLITE_ENABLE_FTS4 SQLITE_ENABLE_FTS5 SQLITE_ENABLE_RTREE SQLITE_ENABLE_GEOPOLY)
target_include_directories(sqlite3 PUBLIC $<BUILD_INTERFACE:${SQLITE_SRC}> $<INSTALL_INTERFACE:include>)
install(TARGETS sqlite3 EXPORT sqlite3Targets ARCHIVE DESTINATION lib)
install(FILES ${SQLITE_SRC}/sqlite3.h ${SQLITE_SRC}/sqlite3ext.h DESTINATION include)
install(EXPORT sqlite3Targets FILE sqlite3-config.cmake NAMESPACE sqlite3:: DESTINATION lib/cmake/sqlite3)
include(CMakePackageConfigHelpers)
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/sqlite3-config-version.cmake VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/sqlite3-config-version.cmake DESTINATION lib/cmake/sqlite3)
