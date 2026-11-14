#!/bin/bash
# kodi-rt PGO: configure Kodi for the PGO builds, from the FROZEN source build/s7/kodi (a copy of build/s4/kodi taken
# 2026-11-13 11:4x: patches 0001-0015, the update-4 edit to 0013, the Python stage's state; the same tree as the update-4
# kodi.exe 6ba6d9fc...). Phase 2 must compile from the same path: the profile names static functions by source path.
#   PHASE=instr (default): build/s7/kodi-build-instr, IR instrumentation (cross/kodi-rt-pgo-instr.cmake), FFmpeg from
#                          prefix/arm32-ffinstr (scripts/s7-ffmpeg-instr.sh), periodic profile writer tools/pgo/pgoflush.c.
#   PHASE=use:             phase 2 (after the device profile): build/s7/kodi-build-pgo, cross/kodi-rt-pgo-use.cmake,
#                          FFmpeg from prefix/arm32-ffpgo.
# Everything else is scripts/s4-configure.sh plus scripts/py-kodi-configure.sh (Python on), so both phases compile the
# code of the normal build with its options. Nothing is written to build/s4 (the Python session's).
# Usage (Git Bash): PHASE=instr bash scripts/s7-configure.sh [extra cmake args]     Log: logs/s7-configure-<phase>.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKEDIR="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake"
CMAKE="$CMAKEDIR/CMake/bin/cmake.exe"
NINJA="$CMAKEDIR/Ninja/ninja.exe"
# ExternalProjects run their own "cmake -G Ninja": they need ninja on PATH
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
PHASE=${PHASE:-instr}
PFX=F:/kodi-rt/prefix/arm32
SRC=F:/kodi-rt/build/s7/kodi
RT=F:/kodi-rt/tc/rt24c-cr/bin
# phase 1 used rt2.4 0318206a (tc/rt24c-cr, the normal build's); phase 2 uses f6e5f8e0 (tc/rt24d-cr: 0033 + 0034
# fixed, IR passes unchanged, so phase 1's profile matches)
case $PHASE in
  instr) BD=F:/kodi-rt/build/s7/kodi-build-instr; INC=F:/kodi-rt/cross/kodi-rt-pgo-instr.cmake; FF=F:/kodi-rt/prefix/arm32-ffinstr
         TCF=F:/kodi-rt/cross/arm32-rt24.cmake ;;
  use)   BD=F:/kodi-rt/build/s7/kodi-build-pgo;   INC=F:/kodi-rt/cross/kodi-rt-pgo-use.cmake;   FF=F:/kodi-rt/prefix/arm32-ffpgo
         TCF=F:/kodi-rt/cross/arm32-rt24d.cmake ;;
  *) echo "PHASE must be instr or use"; exit 1 ;;
esac
LOG=/f/kodi-rt/logs/s7-configure-$PHASE.log
export PKG_CONFIG_LIBDIR=$PFX/lib/pkgconfig
export PKG_CONFIG_PATH=
# the VS standard library list (see scripts/s4-configure.sh)
STDLIBS="kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib"
for f in share/Toolchain-Native.cmake bin/pkgconf.exe tools/TexturePacker/TexturePacker.exe; do
  [ -f "$SRC/project/BuildDependencies/tools/$f" ] || { echo "no $f in $SRC"; exit 1; }
done
[ -f "$INC" ] || { echo "no $INC"; exit 1; }
for l in avcodec avfilter avformat avutil postproc swresample swscale; do
  [ -f "$FF/lib/$l.lib" ] || { echo "no $FF/lib/$l.lib"; exit 1; }
done
[ -f F:/kodi-rt/build/py/host/bin/swig.exe ] || { echo "no host swig: scripts/py-swig.sh"; exit 1; }
[ -f $PFX/python/libs/python314.lib ] || { echo "no ARM32 Python: scripts/py-build.sh arm32"; exit 1; }
if [ "$PHASE" = instr ]; then
  # the periodic profile writer, compiled WITHOUT instrumentation; cross/kodi-rt-pgo-instr.cmake links it as an object
  mkdir -p F:/kodi-rt/build/s7/pgoflush
  "$RT/clang-cl.exe" @F:/kodi-rt/cross/arm32-msvc.rsp -MT -O2 -W4 -c F:/kodi-rt/tools/pgo/pgoflush.c \
    -FoF:/kodi-rt/build/s7/pgoflush/pgoflush.obj || { echo "pgoflush.c failed"; exit 1; }
fi
# KEEP=1: reconfigure the existing tree in place (objects kept). Needed after a change to the include file: Kodi's
# FindPython.cmake deletes PYTHON_PATH from the cache once used, so ninja's own CMake re-run fails with
# "PYTHON enabled but not found" (measured 2026-11-13); this script passes it again.
if [ "${KEEP:-0}" != 1 ]; then
  rm -rf "$BD"
  [ -e "$BD" ] && { echo "could not remove $BD"; exit 1; }
fi
{
  echo "[s7-configure $PHASE] $(date '+%F %T') start"
  "$CMAKE" -G Ninja -S "$SRC" -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=$TCF -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=10.0.26100.0 \
    -DDEPENDS_PATH=$PFX -DUSE_INTERNAL_LIBS=OFF -DENABLE_INTERNAL_CROSSGUID=OFF \
    -DWITH_FFMPEG=$PFX \
    "-DCMAKE_C_STANDARD_LIBRARIES=$STDLIBS" "-DCMAKE_CXX_STANDARD_LIBRARIES=$STDLIBS" \
    -DKODI_MIRROR=http://127.0.0.1:9/kodi-rt-no-downloads -DTARBALL_DIR=F:/kodi-rt/downloads/sources \
    -DMSYS_INSTALL_PATH=D:/MSYS2 \
    "-DFXC_EXECUTABLE=D:/Windows Kits/10/bin/10.0.26100.0/x86/fxc.exe" \
    -DENABLE_PYTHON=ON -DPYTHON_PATH=$PFX/python -DSWIG_EXECUTABLE=F:/kodi-rt/build/py/host/bin/swig.exe \
    -DENABLE_OPTICAL=OFF -DENABLE_AIRTUNES=OFF -DENABLE_PLIST=OFF -DENABLE_MDNS=OFF \
    -DENABLE_BLURAY=OFF -DENABLE_UDFREAD=OFF -DENABLE_XSLT=OFF -DENABLE_CEC=OFF -DENABLE_NFS=OFF \
    -DENABLE_MARIADBCLIENT=OFF -DENABLE_MYSQLCLIENT=OFF -DENABLE_MICROHTTPD=OFF \
    -DENABLE_LCMS2=OFF -DENABLE_DVDCSS=OFF -DENABLE_UPNP=OFF -DENABLE_TESTING=OFF \
    -DCMAKE_PROJECT_kodi_INCLUDE=$INC \
    -DFFMPEG_LIBAVCODEC=$FF/lib/avcodec.lib -DFFMPEG_LIBAVFILTER=$FF/lib/avfilter.lib \
    -DFFMPEG_LIBAVFORMAT=$FF/lib/avformat.lib -DFFMPEG_LIBAVUTIL=$FF/lib/avutil.lib \
    -DFFMPEG_LIBPOSTPROC=$FF/lib/postproc.lib -DFFMPEG_LIBSWRESAMPLE=$FF/lib/swresample.lib \
    -DFFMPEG_LIBSWSCALE=$FF/lib/swscale.lib \
    "$@" || { echo "[s7-configure $PHASE] CONFIGURE FAILED $(date '+%T')"; exit 1; }
  echo "[s7-configure $PHASE] CONFIGURE DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
grep -E "^-- (Building|Found|Could NOT|Warning)|CMake (Error|Warning)|Building |[Pp]ython|SWIG" "$LOG" | head -60
tail -3 "$LOG"
grep -E "^FFMPEG_LIB[A-Z]+:FILEPATH|^ENABLE_PYTHON:" "$BD/CMakeCache.txt" 2>/dev/null
exit $rc
