#!/bin/bash
# kodi-rt Python stage: turn Python on in the existing Kodi build tree (build/s4/kodi-build, configured by
# scripts/s4-configure.sh), in place, so objects that HAS_PYTHON doesn't touch are kept.
#   -DENABLE_PYTHON=ON, -DPYTHON_PATH=prefix/arm32/python (Kodi's FindPython: Python3_ROOT_DIR; headers in include/,
#   python314.lib in libs/), -DSWIG_EXECUTABLE=build/py/host/bin/swig.exe (scripts/py-swig.sh).
# Usage (Git Bash): bash scripts/py-kodi-configure.sh [extra -D options]    Log: logs/py-kodi-configure.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKEDIR="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake"
CMAKE="$CMAKEDIR/CMake/bin/cmake.exe"
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
PFX=F:/kodi-rt/prefix/arm32
BD=F:/kodi-rt/build/s4/kodi-build
LOG=/f/kodi-rt/logs/py-kodi-configure.log
export PKG_CONFIG_LIBDIR=$PFX/lib/pkgconfig
export PKG_CONFIG_PATH=
[ -f "$BD/CMakeCache.txt" ] || { echo "no configured build tree: run scripts/s4-configure.sh first"; exit 1; }
[ -f F:/kodi-rt/build/py/host/bin/swig.exe ] || { echo "no host swig: run scripts/py-swig.sh first"; exit 1; }
[ -f $PFX/python/libs/python314.lib ] || { echo "no ARM32 Python: run scripts/py-build.sh arm32 first"; exit 1; }
{
  echo "[py-kodi-configure] $(date '+%F %T') start"
  "$CMAKE" -S F:/kodi-rt/build/s4/kodi -B "$BD" -DENABLE_PYTHON=ON -DPYTHON_PATH=$PFX/python \
    -DSWIG_EXECUTABLE=F:/kodi-rt/build/py/host/bin/swig.exe "$@" \
    || { echo "[py-kodi-configure] CONFIGURE FAILED $(date '+%T')"; exit 1; }
  echo "[py-kodi-configure] CONFIGURE DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
grep -E -i "python|swig|CMake (Error|Warning)" "$LOG" | head -40
tail -3 "$LOG"
exit $rc
