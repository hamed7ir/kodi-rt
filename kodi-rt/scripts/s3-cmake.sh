#!/bin/bash
# kodi-rt Stage 3: build one CMake library (static, /MT, rt2.4) for $ARCH (cross/arch.sh: arm32 by default) with
# cross/$ARCH-rt24.cmake + Ninja, -j8, and install it. Usage (Git Bash): bash scripts/s3-cmake.sh <name> <source dir> [cmake args...]
#   env PFX (default F:/kodi-rt/prefix/$ARCH): install prefix, also put first on CMAKE_PREFIX_PATH
#   env EXTRA_PREFIX: more prefixes for CMAKE_PREFIX_PATH (";"-separated)
#   Build dir: $A_B3/<name> (recreated; arm32: F:/kodi-rt/build/s3/<name>). Log: $A_LOG3-<name>.log
#   (arm32: F:/kodi-rt/logs/s3-<name>.log; x64: build/s3-x64, logs/s3-x64-<name>.log)
# -DCMAKE_POLICY_DEFAULT_CMP0091=NEW: a project whose cmake_minimum_required is below 3.15 otherwise gets CMP0091 OLD,
# ignores CMAKE_MSVC_RUNTIME_LIBRARY and compiles /MD (measured: harfbuzz, crossguid, lzo2). The default must exist
# before cmake_minimum_required runs, so it has to be given here; set in the toolchain file it is too late (measured).
set -u
source /f/kodi-rt/cross/arch.sh
export MSYS2_ARG_CONV_EXCL='*'
NAME=$1; SRC=$2; shift 2
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
PFX=${PFX:-$A_PFX}
PP="$PFX${EXTRA_PREFIX:+;$EXTRA_PREFIX}"
BD=$A_B3/$NAME
LOG=$A_LOG3-$NAME.log
rm -rf "$BD"
{
  echo "[$NAME] $(date '+%T') configure: $*"
  "$CMAKE" -G Ninja -S "$SRC" -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=$A_TCFILE -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PFX" "-DCMAKE_PREFIX_PATH=$PP" -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW "$@" || { echo "[$NAME] CONFIGURE FAILED"; exit 1; }
  echo "[$NAME] $(date '+%T') build"
  "$CMAKE" --build "$BD" -- -j 8 || { echo "[$NAME] BUILD FAILED"; exit 1; }
  echo "[$NAME] $(date '+%T') install"
  "$CMAKE" --install "$BD" || { echo "[$NAME] INSTALL FAILED"; exit 1; }
  echo "[$NAME] DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
tail -3 "$LOG"
echo "[$NAME] warnings: $(grep -c 'warning:' "$LOG")"
exit $rc
