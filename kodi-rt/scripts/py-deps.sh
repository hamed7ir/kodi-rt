#!/bin/bash
# kodi-rt Python stage: the libraries CPython links that the Kodi prefix does not have yet, static and /MT, with
# rt2.4 and their own CMake builds.
#   arm32   xz (liblzma) into prefix/arm32
#   x64ref  xz, zlib and sqlite3 (the Stage 2/3 recipes) into prefix/x64ref, for the x64 reference interpreter
#   x64|x86 xz (liblzma) into prefix/x64 or prefix/x86 (desktop targets; the rest of those prefixes is the original
#           session's scripts/s9-prefix.sh)
# Usage (Git Bash): bash scripts/py-deps.sh <arm32|x64ref|x64|x86>     Log: logs/py-deps-<variant>.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
K=F:/kodi-rt
V=$1
case $V in
  arm32)  TC=$K/cross/arm32-rt24.cmake; PFX=$K/prefix/arm32 ;;
  x64ref) TC=$K/cross/x64-host-rt24.cmake; PFX=$K/prefix/x64ref ;;
  x64|x86) TC=$K/cross/$V-rt24.cmake; PFX=$K/prefix/$V ;;
  *) echo "unknown variant $V"; exit 2 ;;
esac
LOG=/f/kodi-rt/logs/py-deps-$V.log
cm() { # name source-dir cmake-options...
  local name=$1 src=$2; shift 2
  local bd=$K/build/py/deps-$V-$name
  rm -rf "$bd"
  "$CMAKE" -G Ninja -S "$src" -B "$bd" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$TC \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PFX -DCMAKE_POLICY_DEFAULT_CMP0091=NEW "$@"
  "$CMAKE" --build "$bd" -- -j 8
  "$CMAKE" --install "$bd"
}
{
  set -e
  cm xz $K/src/deps/xz-5.8.3 -DBUILD_SHARED_LIBS=OFF -DXZ_NLS=OFF -DXZ_DOC=OFF -DXZ_TOOL_XZ=OFF -DXZ_TOOL_XZDEC=OFF \
    -DXZ_TOOL_LZMADEC=OFF -DXZ_TOOL_LZMAINFO=OFF -DXZ_TOOL_SCRIPTS=OFF
  if [ $V = x64ref ]; then
    cm zlib $K/src/deps/zlib-1.3.2 -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON -DZLIB_BUILD_TESTING=OFF
    cm sqlite3 $K/cross/cmake/sqlite3 -DSQLITE_SRC=$K/build/s3/src/sqlite3
  fi
  echo "PY DEPS $V DONE"
} > "$LOG" 2>&1
rc=$?
tail -2 "$LOG"; ls $PFX/lib | grep -i "lzma\|zs.lib\|sqlite3"
exit $rc
