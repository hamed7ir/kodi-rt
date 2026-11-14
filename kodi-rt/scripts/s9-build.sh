#!/bin/bash
# kodi-rt Stage 9: build the x64 or x86 Kodi tree (configured by scripts/s9-configure.sh) with ninja -j8 -k 0.
# A full build outlasts an agent session's ~30 min background limit: start it DETACHED, e.g.
#   powershell -NoProfile -File scripts/launch-detached.ps1 -Shell git -Script /f/kodi-rt/scripts/s9-build.sh -ScriptArgs x64
# Log: logs/s9-build-<arch>.log. Status: logs/s9-build-<arch>.status ("RUNNING ..." while it runs, "DONE rc=N ...").
# Args after the arch go to ninja (e.g. a target name: kodi.exe).
set -u
export MSYS2_ARG_CONV_EXCL='*'
# flatc and JsonSchemaBuilder are ExternalProjects that run their own "cmake -G Ninja": ninja must be on PATH
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
A=${1:-x64}
[ $# -gt 0 ] && shift
case $A in x64|x86) ;; *) echo "arch must be x64 or x86"; exit 1 ;; esac
BD=F:/kodi-rt/build/s9/kodi-build-$A
JOBS=${JOBS:-8}
LOG=/f/kodi-rt/logs/s9-build-$A.log
ST=/f/kodi-rt/logs/s9-build-$A.status
echo "RUNNING since $(date '+%F %T') (bash pid $$)" > $ST
{
  echo "[s9-build $A] $(date '+%F %T') start: ninja -j $JOBS -k 0 $*"
  "$CMAKE" --build $BD -- -j $JOBS -k 0 "$@"
  rc=$?
  echo "[s9-build $A] $(date '+%F %T') end rc=$rc"
  echo "DONE rc=$rc at $(date '+%F %T')" > $ST
} > $LOG 2>&1
