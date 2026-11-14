# kodi-rt: TinyXML 2.6.2 (Kodi's repackaged tinyxml-2.6.2_2) as a static library. Kodi's package builds it with
# -DTIXML_USE_STL (its configure.ac:33), and cmake/modules/FindTinyXML.cmake adds TIXML_USE_STL to its target on
# Windows, so both sides agree. FindTinyXML looks for tinyxml.h and a library named tinyxml (find_path/find_library).
# Configure with -DTINYXML_SRC=<tinyxml-2.6.2_2 directory>.
cmake_minimum_required(VERSION 3.20)
project(tinyxml VERSION 2.6.2 LANGUAGES CXX)
add_library(tinyxml STATIC ${TINYXML_SRC}/src/tinystr.cpp ${TINYXML_SRC}/src/tinyxml.cpp
  ${TINYXML_SRC}/src/tinyxmlerror.cpp ${TINYXML_SRC}/src/tinyxmlparser.cpp)
target_compile_definitions(tinyxml PUBLIC TIXML_USE_STL)
target_include_directories(tinyxml PUBLIC $<BUILD_INTERFACE:${TINYXML_SRC}/include> $<INSTALL_INTERFACE:include>)
install(TARGETS tinyxml EXPORT tinyxmlTargets ARCHIVE DESTINATION lib)
install(FILES ${TINYXML_SRC}/include/tinyxml.h ${TINYXML_SRC}/include/tinystr.h DESTINATION include)
install(EXPORT tinyxmlTargets FILE tinyxml-config.cmake NAMESPACE tinyxml:: DESTINATION lib/cmake/tinyxml)
