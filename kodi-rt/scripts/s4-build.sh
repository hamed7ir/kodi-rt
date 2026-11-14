#!/bin/bash
# kodi-rt Stage 4: build Kodi (build/s4/kodi-build, configured by scripts/s4-configure.sh) with ninja -j8.
# A full build outlasts an agent session's ~30 min background limit, so start it DETACHED (Normal priority; no Venetium
# build running, Hamed 2026-11-12):
#   powershell -NoProfile -File scripts/launch-detached.ps1 -Script /f/kodi-rt/scripts/s4-build.sh -Shell git
# -k 0: keep going after errors, so one pass lists every file that fails.
# Log: logs/s4-build.log. Status: logs/s4-build.status ("RUNNING ..." while it runs, then "DONE rc=N ...").
# Args are passed to ninja (e.g. a target name: kodi.exe).
set -u
export MSYS2_ARG_CONV_EXCL='*'
# flatc and JsonSchemaBuilder are ExternalProjects that run their own "cmake -G Ninja": ninja must be on PATH
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
LOG=/f/kodi-rt/logs/s4-build.log
ST=/f/kodi-rt/logs/s4-build.status
echo "RUNNING since $(date '+%F %T') (bash pid $$)" > $ST
{
  echo "[s4-build] $(date '+%F %T') start: ninja -j 8 -k 0 $*"
  "$CMAKE" --build F:/kodi-rt/build/s4/kodi-build -- -j 8 -k 0 "$@"
  rc=$?
  echo "[s4-build] $(date '+%F %T') end rc=$rc"
  echo "DONE rc=$rc at $(date '+%F %T')" > $ST
} > $LOG 2>&1
