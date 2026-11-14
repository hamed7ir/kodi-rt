#!/bin/bash
# kodi-rt Stage 3: the small CMake libraries, each with Kodi's own recipe (cmake/modules/Find<X>.cmake at bffa625c:
# its CMAKE_ARGS, its Windows EXTRA_ARGS, and its patches in the listed order), static, rt2.4, into
# F:/kodi-rt/prefix/$ARCH (cross/arch.sh: arm32 by default, or ARCH=x64 / ARCH=x86). Kodi's CMAKE_CXX_STANDARD is 20
# and CMAKE_CXX_EXTENSIONS OFF (CompilerSettings.cmake:2-4).
# Usage (Git Bash): bash scripts/s3-small-libs.sh [name ...]   (default: all, in dependency order)
set -u
source /f/kodi-rt/cross/arch.sh
cd /f/kodi-rt || exit 1
S=$A_B3/src   # patched copies (scripts/s3-prep.sh)
T=/f/kodi-rt/src/xbmc/tools/depends/target
D=/f/kodi-rt/src/deps
DL=/f/kodi-rt/downloads/sources
CXX20=(-DCMAKE_CXX_STANDARD=20 -DCMAKE_CXX_EXTENSIONS=OFF)
unpack() { # archive dir
  [ -d "$D/$2" ] || tar -xf "$DL/$1" -C "$D" || { echo "unpack $1 failed"; exit 1; }
}
build() {
  case $1 in
    pcre2)
      unpack pcre2-10.47.tar.bz2 pcre2-10.47
      bash scripts/s3-prep.sh pcre2 $D/pcre2-10.47 $T/pcre2/001-all-enable_docs_pc.patch || return 1
      bash scripts/s3-cmake.sh pcre2 $S/pcre2 -DBUILD_STATIC_LIBS=ON -DPCRE2_STATIC_PIC=ON \
        -DPCRE2_BUILD_PCRE2_8=ON -DPCRE2_BUILD_PCRE2_16=OFF -DPCRE2_BUILD_PCRE2_32=OFF -DPCRE2_SUPPORT_UNICODE=ON \
        -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF -DENABLE_DOCS=OFF -DPCRE2_SUPPORT_JIT=ON ;;
    fmt)
      unpack fmt-12.1.0.tar.gz fmt-12.1.0
      bash scripts/s3-cmake.sh fmt F:/kodi-rt/src/deps/fmt-12.1.0 "${CXX20[@]}" -DFMT_DOC=OFF -DFMT_TEST=OFF \
        -DFMT_INSTALL=ON -DFMT_UNICODE=ON ;;
    spdlog)
      unpack spdlog-1.17.0.tar.gz spdlog-1.17.0
      bash scripts/s3-cmake.sh spdlog F:/kodi-rt/src/deps/spdlog-1.17.0 "${CXX20[@]}" -DSPDLOG_BUILD_EXAMPLE=OFF \
        -DSPDLOG_BUILD_TESTS=OFF -DSPDLOG_BUILD_BENCH=OFF -DSPDLOG_FMT_EXTERNAL=ON -DSPDLOG_WCHAR_SUPPORT=ON \
        -DSPDLOG_WCHAR_FILENAMES=ON ;;
    nlohmann_json)
      unpack json-3.12.0.tar.xz json
      bash scripts/s3-cmake.sh nlohmann_json F:/kodi-rt/src/deps/json -DJSON_BuildTests=OFF ;;
    crossguid)
      unpack crossguid-ca1bf4b810e2d188d04cb6286f957008ee1b7681.tar.gz crossguid-ca1bf4b810e2d188d04cb6286f957008ee1b7681
      bash scripts/s3-prep.sh crossguid $D/crossguid-ca1bf4b810e2d188d04cb6286f957008ee1b7681 \
        $T/crossguid/001-fix-unused-function.patch $T/crossguid/002-disable-Wall-error.patch \
        $T/crossguid/003-add-cstdint-include.patch $T/crossguid/004-cmake-install.patch || return 1
      bash scripts/s3-cmake.sh crossguid $S/crossguid -DCROSSGUID_TESTS=OFF -DDISABLE_WALL=ON ;;
    lzo2)
      unpack lzo-2.10.tar.gz lzo-2.10
      bash scripts/s3-prep.sh lzo2 $D/lzo-2.10 $T/liblzo2/001-all-enable_tests.patch $T/liblzo2/002-all-enable_docs.patch \
        $T/liblzo2/003-all-install_pkgconfig.patch $T/liblzo2/004-all-win_set_debug_postfix.patch \
        $T/liblzo2/005-all-win_set_compile_mp.patch $T/liblzo2/006-all-win_cmake_install.patch || return 1
      bash scripts/s3-cmake.sh lzo2 $S/lzo2 -DENABLE_STATIC=ON -DENABLE_SHARED=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.10 ;;
    tinyxml2)
      unpack tinyxml2-11.0.0.tar.gz tinyxml2-11.0.0
      bash scripts/s3-prep.sh tinyxml2 $D/tinyxml2-11.0.0 $T/tinyxml2/001-debug-pdb.patch || return 1
      bash scripts/s3-cmake.sh tinyxml2 $S/tinyxml2 "${CXX20[@]}" -Dtinyxml2_BUILD_TESTING=OFF \
        -Dtinyxml2_INSTALL_PKGCONFIG=OFF ;;
    *) echo "unknown library $1"; return 1 ;;
  esac
}
LIST=(pcre2 fmt spdlog nlohmann_json crossguid lzo2 tinyxml2)
[ $# -gt 0 ] && LIST=("$@")
fail=0
for l in "${LIST[@]}"; do build "$l" || { echo "### $l FAILED"; fail=1; }; done
[ $fail = 0 ] && echo "SMALL LIBS DONE" || echo "SMALL LIBS HAD FAILURES"
