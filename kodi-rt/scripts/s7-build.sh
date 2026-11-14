#!/bin/bash
# kodi-rt PGO: build the s7 Kodi tree of one phase (configured by scripts/s7-configure.sh) with ninja -j8 -k 0.
# A full build outlasts an agent session's ~30 min background limit: start it DETACHED (Normal priority while no
# Venetium build runs, Hamed 2026-11-12):
#   powershell -NoProfile -File scripts/launch-detached.ps1 -Script /f/kodi-rt/scripts/s7-build.sh -Shell git -ScriptArgs instr
# Log: logs/s7-build-<phase>.log. Status: logs/s7-build-<phase>.status ("RUNNING ..." while it runs, "DONE rc=N ...").
# Args after the phase go to ninja (e.g. a target name: kodi.exe).
set -u
export MSYS2_ARG_CONV_EXCL='*'
# flatc and JsonSchemaBuilder are ExternalProjects that run their own "cmake -G Ninja": ninja must be on PATH
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
PHASE=${1:-instr}
[ $# -gt 0 ] && shift
case $PHASE in
  instr) BD=F:/kodi-rt/build/s7/kodi-build-instr ;;
  use)   BD=F:/kodi-rt/build/s7/kodi-build-pgo ;;
  *) echo "phase must be instr or use"; exit 1 ;;
esac
JOBS=${JOBS:-8}
LOG=/f/kodi-rt/logs/s7-build-$PHASE.log
ST=/f/kodi-rt/logs/s7-build-$PHASE.status
echo "RUNNING since $(date '+%F %T') (bash pid $$)" > $ST
{
  echo "[s7-build $PHASE] $(date '+%F %T') start: ninja -j $JOBS -k 0 $*"
  "$CMAKE" --build $BD -- -j $JOBS -k 0 "$@"
  rc=$?
  echo "[s7-build $PHASE] $(date '+%F %T') end rc=$rc"
  echo "DONE rc=$rc at $(date '+%F %T')" > $ST
} > $LOG 2>&1
