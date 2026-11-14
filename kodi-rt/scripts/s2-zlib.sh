#!/bin/bash
# kodi-rt Stage 2: zlib 1.3.2 (Kodi's pin), static, /MT, rt2.4, into F:/kodi-rt/prefix/$ARCH (cross/arch.sh: arm32
# by default, or ARCH=x64 / ARCH=x86).
# CMake + Ninja with cross/arm32-rt24.cmake (as the tgcalls kit's build-zlib.sh, without its ZLIB_WINAPI: Kodi and
# FFmpeg call zlib with the default convention). FFmpeg's configure with Kodi's patch 007 links "z.lib", so the
# static library (zs.lib) is also installed as z.lib.
# Run from Git Bash: nice -n 10 bash scripts/s2-zlib.sh   (ARCH=x64 bash scripts/s2-zlib.sh for x64)
set -u
source /f/kodi-rt/cross/arch.sh
export MSYS2_ARG_CONV_EXCL='*'
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
SRC=F:/kodi-rt/src/deps/zlib-1.3.2
BD=F:/kodi-rt/build/s2/zlib-$ARCH
PFX=$A_PFX
JOBS=${JOBS:-8}
rm -rf "$BD"
"$CMAKE" -G Ninja -S "$SRC" -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" \
  -DCMAKE_TOOLCHAIN_FILE=$A_TCFILE -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PFX" \
  -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON -DZLIB_BUILD_TESTING=OFF || { echo "ZLIB CONFIGURE FAILED"; exit 1; }
"$CMAKE" --build "$BD" -- -j "$JOBS" || { echo "ZLIB BUILD FAILED"; exit 1; }
"$CMAKE" --install "$BD" || { echo "ZLIB INSTALL FAILED"; exit 1; }
L=$(ls "$PFX"/lib/zs.lib "$PFX"/lib/zlibstatic.lib 2>/dev/null | head -1)
[ -n "$L" ] || { echo "no static zlib in $PFX/lib"; ls "$PFX/lib"; exit 1; }
cp -f "$L" "$PFX/lib/z.lib"
echo "installed $(basename "$L") and z.lib"
echo "ZLIB DONE"
