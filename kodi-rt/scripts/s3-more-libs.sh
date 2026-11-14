#!/bin/bash
# kodi-rt Stage 3: the remaining CMake libraries with Kodi's own recipes (cmake/modules/Find<X>.cmake at bffa625c:
# CMAKE_ARGS, Windows EXTRA_ARGS and C_FLAGS, patches in order), static, rt2.4, into F:/kodi-rt/prefix/$ARCH
# (cross/arch.sh: arm32 by default, or ARCH=x64 / ARCH=x86).
# Where Kodi passes -DCMAKE_CXX_FLAGS=<Kodi's flags> (exiv2, effects11) that is left out: it would replace the
# toolchain's CMAKE_CXX_FLAGS_INIT, which carries the target and SDK pins; Kodi uses it to hand over its own flags.
# Usage (Git Bash): bash scripts/s3-more-libs.sh [name ...]   (default: all, in dependency order)
set -u
source /f/kodi-rt/cross/arch.sh
cd /f/kodi-rt || exit 1
S=$A_B3/src   # patched copies (scripts/s3-prep.sh)
T=/f/kodi-rt/src/xbmc/tools/depends/target
D=/f/kodi-rt/src/deps
DL=/f/kodi-rt/downloads/sources
PFX=$A_PFX
CXX20=(-DCMAKE_CXX_STANDARD=20 -DCMAKE_CXX_EXTENSIONS=OFF)
unpack() { [ -d "$D/$2" ] || tar -xf "$DL/$1" -C "$D" || { echo "unpack $1 failed"; exit 1; }; }
build() {
  case $1 in
    brotli)
      unpack brotli-1.2.0.tar.gz brotli-1.2.0
      bash scripts/s3-prep.sh brotli $D/brotli-1.2.0 $T/brotli/01-all-cmake-install-config.patch || return 1
      bash scripts/s3-cmake.sh brotli $S/brotli -DBROTLI_DISABLE_TESTS=ON -DBROTLI_BUILD_TOOLS=OFF ;;
    utfcpp)
      unpack utfcpp-4.0.6.tar.gz utfcpp-4.0.6
      bash scripts/s3-cmake.sh utfcpp F:/kodi-rt/src/deps/utfcpp-4.0.6 -DUMMYARGS=ON ;;
    taglib)
      unpack taglib-2.3.2.tar.gz taglib-2.3.2
      bash scripts/s3-prep.sh taglib $D/taglib-2.3.2 $T/taglib/001-cmake-pdb-debug.patch || return 1
      bash scripts/s3-cmake.sh taglib $S/taglib "${CXX20[@]}" -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
        -DBUILD_BINDINGS=OFF ;;
    exiv2)
      unpack exiv2-0.28.8.tar.gz exiv2-0.28.8
      bash scripts/s3-prep.sh exiv2 $D/exiv2-0.28.8 $T/exiv2/0001-WIN-lib-postfix.patch || return 1
      bash scripts/s3-cmake.sh exiv2 $S/exiv2 "${CXX20[@]}" -DEXIV2_ENABLE_WEBREADY=OFF \
        -DEXIV2_ENABLE_XMP=OFF -DEXIV2_ENABLE_CURL=OFF -DEXIV2_ENABLE_NLS=OFF -DEXIV2_BUILD_SAMPLES=OFF \
        -DEXIV2_BUILD_UNIT_TESTS=OFF -DEXIV2_ENABLE_VIDEO=OFF -DEXIV2_ENABLE_BMFF=ON -DEXIV2_ENABLE_BROTLI=ON \
        -DEXIV2_ENABLE_INIH=OFF -DEXIV2_ENABLE_FILESYSTEM_ACCESS=OFF -DEXIV2_BUILD_EXIV2_COMMAND=OFF \
        -DBUILD_WITH_CCACHE=OFF ;;
    flatbuffers)
      unpack flatbuffers-23.3.3.tar.gz flatbuffers-23.3.3
      bash scripts/s3-cmake.sh flatbuffers F:/kodi-rt/src/deps/flatbuffers-23.3.3 -DFLATBUFFERS_CODE_COVERAGE=OFF \
        -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_INSTALL=ON -DFLATBUFFERS_BUILD_FLATLIB=OFF \
        -DFLATBUFFERS_BUILD_FLATC=OFF -DFLATBUFFERS_BUILD_FLATHASH=OFF -DFLATBUFFERS_BUILD_GRPCTEST=OFF \
        -DFLATBUFFERS_BUILD_SHAREDLIB=OFF ;;
    effects11)
      unpack FX11-11.30.tar.gz FX11-aug2024
      bash scripts/s3-prep.sh effects11 $D/FX11-aug2024 $T/effects11/01-win-debugpostfix.patch \
        $T/effects11/02-win-cmake-config-installdir.patch || return 1
      # FX11 picks its architecture from VCPKG_TARGET_ARCHITECTURE, CMAKE_GENERATOR_PLATFORM or the VS platform; under
      # Ninja none is set and a 32-bit build counts as x86 (-msse2). DIRECTX_ARCH survives when nothing matches.
      bash scripts/s3-cmake.sh effects11 $S/effects11 -DDIRECTX_ARCH=$A_DXARCH ;;
    nghttp2)
      unpack nghttp2-1.69.0.tar.xz nghttp2-1.69.0
      bash scripts/s3-cmake.sh nghttp2 F:/kodi-rt/src/deps/nghttp2-1.69.0 -DENABLE_DEBUG=OFF -DENABLE_FAILMALLOC=OFF \
        -DENABLE_LIB_ONLY=ON -DENABLE_DOC=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_TESTING=OFF -DWITH_LIBXML2=OFF ;;
    zstd)
      unpack zstd-1.5.7.tar.gz zstd-1.5.7
      bash scripts/s3-cmake.sh zstd F:/kodi-rt/src/deps/zstd-1.5.7/build/cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_SHARED=OFF -DZSTD_LEGACY_SUPPORT=OFF -DZSTD_BUILD_PROGRAMS=OFF \
        -DZSTD_BUILD_TESTS=OFF && cp -f $PFX/lib/zstd_static.lib $PFX/lib/zstd.lib ;;  # curl's FindZstd (also in its installed config) looks for "zstd"
    curl)
      unpack curl-8.20.0.tar.xz curl-8.20.0
      # Kodi: C_FLAGS -DNGHTTP2_STATICLIB on Windows (injected, see cross/curl-kodirt.cmake), ZSTD_* passed explicitly
      # (curl runs its own FindZstd). BUILD_TESTING=OFF added here: the tests can't run in a cross build.
      bash scripts/s3-cmake.sh curl F:/kodi-rt/src/deps/curl-8.20.0 -DCMAKE_PROJECT_INCLUDE=F:/kodi-rt/cross/curl-kodirt.cmake \
        -DBUILD_CURL_EXE=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_LIBCURL_DOCS=OFF -DENABLE_CURL_MANUAL=OFF \
        -DCURL_DISABLE_TESTS=OFF -DBUILD_TESTING=OFF -DCURL_DISABLE_LDAP=ON -DCURL_DISABLE_LDAPS=ON \
        -DCURL_DISABLE_SMB=OFF -DCURL_USE_OPENSSL=ON -DOPENSSL_ROOT_DIR=$PFX -DOPENSSL_USE_STATIC_LIBS=ON \
        -DCURL_BROTLI=ON -DCURL_ZSTD=ON -DUSE_NGHTTP2=ON -DUSE_LIBIDN2=OFF -DCURL_USE_LIBSSH2=OFF -DCURL_USE_LIBPSL=OFF \
        -DCURL_USE_GSSAPI=OFF -DCURL_CA_FALLBACK=ON -DZSTD_INCLUDE_DIR=$PFX/include \
        -DZSTD_LIBRARY:STRING=$PFX/lib/zstd_static.lib ;;
    *) echo "unknown library $1"; return 1 ;;
  esac
}
LIST=(brotli utfcpp taglib exiv2 flatbuffers effects11 nghttp2 zstd curl)
[ $# -gt 0 ] && LIST=("$@")
fail=0
for l in "${LIST[@]}"; do build "$l" || { echo "### $l FAILED"; fail=1; }; done
[ $fail = 0 ] && echo "MORE LIBS DONE" || echo "MORE LIBS HAD FAILURES"
