# kodi-rt Stage 3 device tests, linked through the CMake packages the libraries installed into
# F:/kodi-rt/prefix/arm32 (the same find_package calls and imported targets Kodi's build will use in Stage 4).
# Build: bash scripts/s3-cmake.sh s3test F:/kodi-rt/tests/stage3   (installs nothing: no install rules)
cmake_minimum_required(VERSION 3.20)
project(s3test C CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)
set(OPENSSL_USE_STATIC_LIBS ON)
set(OPENSSL_ROOT_DIR ${CMAKE_INSTALL_PREFIX})
set(PCRE2_USE_STATIC_LIBS ON)

find_package(ZLIB REQUIRED)
find_package(sqlite3 CONFIG REQUIRED)
find_package(pcre2 CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(CURL CONFIG REQUIRED)
find_package(Freetype REQUIRED)
find_package(harfbuzz CONFIG REQUIRED)
find_package(fribidi CONFIG REQUIRED)
find_package(Iconv REQUIRED)
# libass's exported config (from Kodi's 01-win-CMakeLists.patch) links FriBidi::FriBidi, the target its own
# FindFriBidi creates, without looking it up itself; the consumer has to provide it (Stage 4 note for Kodi too).
add_library(FriBidi::FriBidi ALIAS fribidi::fribidi)
find_package(libass CONFIG REQUIRED)
find_package(lzo2 CONFIG REQUIRED)
find_package(zstd CONFIG REQUIRED)
find_package(brotli CONFIG REQUIRED)
find_package(fstrcmp CONFIG REQUIRED)
find_package(nghttp2 CONFIG REQUIRED)

add_executable(s3test-c s3test-c.c)
target_link_libraries(s3test-c PRIVATE ZLIB::ZLIB sqlite3::sqlite3 pcre2::pcre2-8-static OpenSSL::SSL OpenSSL::Crypto
  CURL::libcurl Freetype::Freetype harfbuzz::harfbuzz fribidi::fribidi Iconv::Iconv libass::libass lzo2::lzo_static_lib
  zstd::libzstd_static brotli::brotlienc brotli::brotlidec fstrcmp::fstrcmp nghttp2::nghttp2_static
  ws2_32 crypt32 advapi32 user32 bcrypt gdi32)  # gdi32: libass's DirectWrite provider (its config lists only dwrite)
target_compile_definitions(s3test-c PRIVATE PCRE2_STATIC)

find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(tinyxml CONFIG REQUIRED)
find_package(tinyxml2 CONFIG REQUIRED)
find_package(crossguid CONFIG REQUIRED)
find_package(taglib CONFIG REQUIRED)
find_package(exiv2 CONFIG REQUIRED)
find_package(flatbuffers CONFIG REQUIRED)

add_executable(s3test-cpp s3test-cpp.cpp)
target_link_libraries(s3test-cpp PRIVATE fmt::fmt spdlog::spdlog nlohmann_json::nlohmann_json tinyxml::tinyxml
  tinyxml2::tinyxml2 crossguid TagLib::tag Exiv2::exiv2lib ole32)
target_include_directories(s3test-cpp PRIVATE ${CMAKE_INSTALL_PREFIX}/include)
# flexbuffers' number parsing (util.h) needs ClassicLocale::instance_ from flatbuffers' compiled library when
# FLATBUFFERS_LOCALE_INDEPENDENT is 1 (base.h's MSVC default); Kodi's recipe doesn't build that library
# (FLATBUFFERS_BUILD_FLATLIB=OFF) and Kodi's generated code doesn't use util.h.
target_compile_definitions(s3test-cpp PRIVATE FLATBUFFERS_LOCALE_INDEPENDENT=0)
