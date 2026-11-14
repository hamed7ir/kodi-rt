#!/bin/bash
# kodi-rt Stage 3: the text libraries, static, rt2.4, for $ARCH (cross/arch.sh: arm32 by default, or ARCH=x64 /
# ARCH=x86), in this order:
#   freetype-nohb  freetype 2.14.2 without harfbuzz (zlib, bzip2, png, brotli off, as Kodi's FindFreetype)
#   harfbuzz       harfbuzz 14.2.0 with that freetype (Kodi's FindHarfBuzz), headers in include/, libraries in lib/
#   freetype       freetype again, now with the static harfbuzz (FT_REQUIRE_HARFBUZZ), replacing freetype-nohb
#   fribidi        fribidi 1.0.17 (meson) with Kodi's 01-win-gen-tab.patch; its meson build exports no CMake config,
#                  so the static library is copied to fribidi.lib and scripts/s3-cmake-config.py writes one
#                  (fribidi::fribidi, FRIBIDI_LIB_STATIC)
#   libass         libass 0.17.5 with Kodi's four Windows patches (01-win-CMakeLists.patch makes it a CMake build),
#                  cross/libass-kodirt.cmake injected (explains why), ARCH as Kodi's FindASS passes it
# For ARM32 these ran as single commands on 2026-11-12 (logs/s3-<name>.log); this script repeats those commands.
# Usage (Git Bash): bash scripts/s3-font-libs.sh [name ...]   (default: all, in that order)
set -u
source /f/kodi-rt/cross/arch.sh
cd /f/kodi-rt || exit 1
T=/f/kodi-rt/src/xbmc/tools/depends/target
D=/f/kodi-rt/src/deps
FT=F:/kodi-rt/src/deps/freetype-2.14.2
build() {
  case $1 in
    freetype-nohb)
      bash scripts/s3-cmake.sh freetype-nohb $FT -DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON \
        -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON ;;
    harfbuzz)
      bash scripts/s3-cmake.sh harfbuzz F:/kodi-rt/src/deps/harfbuzz-14.2.0 -DHB_HAVE_FREETYPE=ON -DHB_BUILD_GPU=OFF \
        -DCMAKE_INSTALL_INCLUDEDIR=include -DCMAKE_INSTALL_LIBDIR=lib ;;
    freetype)
      bash scripts/s3-cmake.sh freetype $FT -DFT_REQUIRE_HARFBUZZ=ON -DFT_DYNAMIC_HARFBUZZ=OFF -DFT_DISABLE_BZIP2=ON \
        -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_ZLIB=ON ;;
    fribidi)
      bash scripts/s3-prep.sh fribidi $D/fribidi-1.0.17 $T/fribidi/01-win-gen-tab.patch || return 1
      bash scripts/s3-meson.sh fribidi $A_B3/src/fribidi -Ddocs=false -Dtests=false -Dbin=false || return 1
      cp -f $A_PFX/lib/libfribidi.a $A_PFX/lib/fribidi.lib || return 1
      python -I scripts/s3-cmake-config.py --prefix $A_PFX --package fribidi --target fribidi::fribidi --version 1.0.17 \
        --lib lib/fribidi.lib --include include/fribidi --define FRIBIDI_LIB_STATIC ;;
    libass)
      bash scripts/s3-prep.sh libass $D/libass-0.17.5 $T/libass/01-win-CMakeLists.patch $T/libass/02-win-dwrite-fontload.patch \
        $T/libass/03-win-dwrite-prevent-ass_set_fonts_dir.patch $T/libass/04-win-nullcheck-shared_hdc.patch || return 1
      bash scripts/s3-cmake.sh libass $A_B3/src/libass -DARCH=$A_LIBASSARCH -DNATIVEPREFIX=F:/kodi-rt/prefix/native \
        -DCMAKE_PROJECT_INCLUDE=F:/kodi-rt/cross/libass-kodirt.cmake ;;
    *) echo "unknown library $1"; return 1 ;;
  esac
}
LIST=(freetype-nohb harfbuzz freetype fribidi libass)
[ $# -gt 0 ] && LIST=("$@")
fail=0
for l in "${LIST[@]}"; do build "$l" || { echo "### $l FAILED"; fail=1; break; }; done
[ $fail = 0 ] && echo "FONT LIBS DONE" || echo "FONT LIBS HAD FAILURES"
