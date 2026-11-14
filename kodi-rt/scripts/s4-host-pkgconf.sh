#!/bin/bash
# kodi-rt Stage 4: Kodi's host pkgconf, built for x64 with rt2.4 and installed where Kodi looks for it.
# On Windows, Kodi's cmake/modules/buildtools/FindPkgConfig.cmake takes pkgconf (or pkg-config) >= its pin
# (tools/depends/native/pkgconf/PKGCONF-VERSION: 2.5.1) from NATIVEPREFIX/bin, and otherwise builds it at configure time
# with a bare "cmake" call (NMake, the default compiler: neither exists here). It avoids Strawberry Perl's pkg-config on
# purpose. So build that pin the way its recipe does (meson, -Dtests=disabled), with cross/meson-x64-native.ini, static.
#   source:  downloads/sources/pkgconf-2.5.1.tar.gz (sha512 checked against the pin by scripts/s2-fetch-sources.sh)
#   install: build/s4/kodi/project/BuildDependencies/tools (= Kodi's NATIVEPREFIX) -> bin/pkgconf.exe
# Usage (Git Bash): bash scripts/s4-host-pkgconf.sh   (scripts/s4-apply-patches.sh runs it)
set -u
export MSYS2_ARG_CONV_EXCL='*'
export PATH="/f/kodi-rt/tc/rt24c-cr/bin:/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
cd /f/kodi-rt || exit 1
MESON=F:/kodi-rt/tools/pyenv/Scripts/meson.exe
PIN=src/xbmc/tools/depends/native/pkgconf/PKGCONF-VERSION
VER=$(grep -m1 '^VERSION=' $PIN | cut -d= -f2 | tr -d '\r'); WANT=$(grep -m1 '^SHA512=' $PIN | cut -d= -f2 | tr -d '\r')
TGZ=downloads/sources/pkgconf-$VER.tar.gz
[ "$(sha512sum $TGZ | cut -d' ' -f1)" = "$WANT" ] || { echo "$TGZ: missing or sha512 mismatch"; exit 1; }
W=build/s4/host
NP=F:/kodi-rt/build/s4/kodi/project/BuildDependencies/tools
LOG=/f/kodi-rt/logs/s4-host-pkgconf.log
# the archive (GitHub tag export) unpacks to pkgconf-pkgconf-<ver>/
S=$W/$(tar -tzf $TGZ | head -1 | cut -d/ -f1)
rm -rf "$S" $W/pkgconf-build; mkdir -p $W
tar -xzf $TGZ -C $W || exit 1
{
  "$MESON" setup $W/pkgconf-build "$S" --native-file F:/kodi-rt/cross/meson-x64-native.ini \
    --prefix=$NP --libdir=lib --bindir=bin --buildtype=release --default-library=static -Dtests=disabled \
    && "$MESON" compile -C $W/pkgconf-build && "$MESON" install -C $W/pkgconf-build
} > $LOG 2>&1 || { tail -20 $LOG; echo "PKGCONF BUILD FAILED"; exit 1; }
GOT=$("$NP/bin/pkgconf.exe" --version | tr -d '\r')
[ "$GOT" = "$VER" ] || { echo "pkgconf.exe --version says '$GOT', want $VER"; exit 1; }
echo "pkgconf $GOT -> $NP/bin/pkgconf.exe"
echo "PKGCONF DONE"
