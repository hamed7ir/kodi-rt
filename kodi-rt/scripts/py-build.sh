#!/bin/bash
# kodi-rt Python stage: configure, build and install CPython 3.14.10 with cross/cmake/python3 (rt2.4 clang-cl, /MT).
#   freeze  x64 host: _freeze_module + the frozen-module headers in build/py/frozen (needed by the other two)
#   x64ref  x64 reference interpreter in build/py/x64-install, to run CPython's test suite on this server
#   arm32   the Surface RT build, installed to prefix/arm32/python (python314.dll, libs/, include/, Lib/, DLLs/)
#   x64     desktop x64 Windows, installed to prefix/x64/python (cross/x64-rt24.cmake, rt2.4 f6e5f8e0; deps prefix/x64)
#   x86     desktop x86 Windows, installed to prefix/x86/python (cross/x86-rt24.cmake; deps prefix/x86)
#           (x64/x86: for the original session's Kodi RT desktop builds; their prefixes come from scripts/s9-prefix.sh,
#           liblzma from scripts/py-deps.sh <arch>)
# Usage (Git Bash): bash scripts/py-build.sh <variant> [extra cmake -D options]   Log: logs/py-<variant>.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
V=$1; shift
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
K=F:/kodi-rt
SRC=$K/build/py/src/Python-3.14.10     # the patched copy (scripts/py-prepare-src.sh)
[ -f "$SRC/PCbuild/pythoncore.vcxproj" ] || { echo "run scripts/py-prepare-src.sh first"; exit 1; }
COMMON=(-DPY_SRC=$SRC -DPY_BZ2_DIR=$K/src/deps/bzip2-1.0.8
        -DPY_FROZEN_DIR=$K/build/py/frozen -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_DEFAULT_CMP0091=NEW)
case $V in
  freeze) TC=$K/cross/x64-host-rt24.cmake; OPTS=(-DPY_FREEZE_ONLY=ON); PFX=$K/build/py/freeze-install ;;
  x64ref) TC=$K/cross/x64-host-rt24.cmake; PFX=$K/build/py/x64-install
          OPTS=(-DPY_DEPS_PREFIX=$K/prefix/x64ref -DPY_WITH_SSL=OFF -DPY_WITH_ZSTD=OFF -DPY_WITH_CTYPES=OFF) ;;
  arm32)  TC=$K/cross/arm32-rt24.cmake; PFX=$K/prefix/arm32/python; OPTS=(-DPY_DEPS_PREFIX=$K/prefix/arm32)
          [ -f "$K/prefix/arm32/lib/libffi.lib" ] || { echo "prefix/arm32/lib/libffi.lib missing (scripts/py-deps.sh arm32 libffi)"; exit 1; } ;;
  x64|x86) TC=$K/cross/$V-rt24.cmake; PFX=$K/prefix/$V/python; OPTS=(-DPY_DEPS_PREFIX=$K/prefix/$V)
          for f in libssl.lib libcrypto.lib sqlite3.lib zs.lib lzma.lib libffi.lib; do
            [ -f "$K/prefix/$V/lib/$f" ] || { echo "prefix/$V/lib/$f missing"; exit 1; }
          done
          [ -f "$K/prefix/$V/lib/zstd_static.lib" ] || OPTS+=(-DPY_WITH_ZSTD=OFF) ;;
  *) echo "unknown variant $V"; exit 2 ;;
esac
BD=$K/build/py/$V
LOG=/f/kodi-rt/logs/py-$V.log
mkdir -p /f/kodi-rt/logs
{
  echo "[py-$V] $(date '+%F %T') configure ${OPTS[*]} $*"
  rm -rf "$BD"
  "$CMAKE" -G Ninja -S $K/cross/cmake/python3 -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$TC \
    -DCMAKE_INSTALL_PREFIX="$PFX" "${COMMON[@]}" "${OPTS[@]}" "$@" || { echo "[py-$V] CONFIGURE FAILED"; exit 1; }
  echo "[py-$V] $(date '+%T') build"
  "$CMAKE" --build "$BD" -- -j 8 -k 0 || { echo "[py-$V] BUILD FAILED"; exit 1; }
  if [ "$V" != freeze ]; then
    echo "[py-$V] $(date '+%T') install"
    rm -rf "$PFX"
    "$CMAKE" --install "$BD" > /dev/null || { echo "[py-$V] INSTALL FAILED"; exit 1; }
  fi
  echo "[py-$V] DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
tail -3 "$LOG"
echo "[py-$V] warnings: $(grep -c 'warning:' "$LOG"), errors: $(grep -c 'error:' "$LOG")"
exit $rc
