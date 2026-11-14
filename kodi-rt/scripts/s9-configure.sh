#!/bin/bash
# kodi-rt Stage 9: configure Kodi for desktop Windows x64 or x86 (cross/arch.sh: ARCH=x64 or ARCH=x86).
#   source: F:/kodi-rt/build/s9/kodi, a copy of the release source build/s7/kodi (patches 0001-0015, the update-4 edit
#           to 0013, the colorspace fix) plus two edits in reports/proposed-edits/: detours-optional.py (the D3D
#           driver hook is compiled out without Detours and the WDK, which this server has neither of) and
#           static-crt-nodefaultlib.py (/NODEFAULTLIB follows the static CRT, not the architecture). The fork's
#           series (release-docs/fork/series, scripts/s8-fork-series.sh) checks that it equals this tree.
#   build:  F:/kodi-rt/build/s9/kodi-build-$ARCH (recreated unless KEEP=1). Log: logs/s9-configure-$ARCH.log
# The options are scripts/s4-configure.sh's (see its comments) with Python as in scripts/py-kodi-configure.sh, for the
# x64/x86 prefix (scripts/s9-prefix.sh, FFmpeg by scripts/s9-ffmpeg.sh) and the toolchain file cross/$ARCH-rt24.cmake
# (rt2.4 f6e5f8e0). No PGO: the profile is an ARM32 device profile. Python: prefix/$ARCH/python when it is there
# (the Python stage builds it); without it Kodi is configured with ENABLE_PYTHON=OFF and the script says so.
# Usage (Git Bash): ARCH=x64 bash scripts/s9-configure.sh [extra cmake args]
set -u
source /f/kodi-rt/cross/arch.sh
[ "$ARCH" = arm32 ] && { echo "s9-configure.sh is for x64/x86 (ARM32: scripts/s4-configure.sh, s7-configure.sh)"; exit 1; }
export MSYS2_ARG_CONV_EXCL='*'
CMAKEDIR="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake"
CMAKE="$CMAKEDIR/CMake/bin/cmake.exe"
NINJA="$CMAKEDIR/Ninja/ninja.exe"
# ExternalProjects run their own "cmake -G Ninja": they need ninja on PATH
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
PFX=$A_PFX
SRC=F:/kodi-rt/build/s9/kodi
BD=F:/kodi-rt/build/s9/kodi-build-$ARCH
LOG=/f/kodi-rt/logs/s9-configure-$ARCH.log
export PKG_CONFIG_LIBDIR=$PFX/lib/pkgconfig
export PKG_CONFIG_PATH=
# the VS standard library list (see scripts/s4-configure.sh)
STDLIBS="kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib"
for f in share/Toolchain-Native.cmake bin/pkgconf.exe tools/TexturePacker/TexturePacker.exe; do
  [ -f "$SRC/project/BuildDependencies/tools/$f" ] || { echo "no $f in $SRC"; exit 1; }
done
for l in avcodec avfilter avformat avutil postproc swresample swscale; do
  [ -f "$PFX/lib/$l.lib" ] || { echo "no $PFX/lib/$l.lib (scripts/s9-ffmpeg.sh)"; exit 1; }
done
if [ -f $PFX/python/libs/python314.lib ]; then
  [ -f F:/kodi-rt/build/py/host/bin/swig.exe ] || { echo "no host swig: scripts/py-swig.sh"; exit 1; }
  PY=(-DENABLE_PYTHON=ON -DPYTHON_PATH=$PFX/python -DSWIG_EXECUTABLE=F:/kodi-rt/build/py/host/bin/swig.exe)
  echo "Python: $PFX/python"
else
  PY=(-DENABLE_PYTHON=OFF)
  echo "NOTE: no $PFX/python yet: configuring WITHOUT Python (ENABLE_PYTHON=OFF)"
fi
# x86 only: cross/kodi-rt-x86.cmake (C++/WinRT needs the coroutine feature macro that clang keeps off for x86 MSVC)
INC=(); [ "$ARCH" = x86 ] && INC=(-DCMAKE_PROJECT_kodi_INCLUDE=F:/kodi-rt/cross/kodi-rt-x86.cmake)
if [ "${KEEP:-0}" != 1 ]; then
  rm -rf "$BD"
  [ -e "$BD" ] && { echo "could not remove $BD"; exit 1; }
fi
{
  echo "[s9-configure $ARCH] $(date '+%F %T') start"
  "$CMAKE" -G Ninja -S "$SRC" -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=$A_TCFILE -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=10.0.26100.0 \
    -DDEPENDS_PATH=$PFX -DUSE_INTERNAL_LIBS=OFF -DENABLE_INTERNAL_CROSSGUID=OFF \
    -DWITH_FFMPEG=$PFX \
    "-DCMAKE_C_STANDARD_LIBRARIES=$STDLIBS" "-DCMAKE_CXX_STANDARD_LIBRARIES=$STDLIBS" \
    -DKODI_MIRROR=http://127.0.0.1:9/kodi-rt-no-downloads -DTARBALL_DIR=F:/kodi-rt/downloads/sources \
    -DMSYS_INSTALL_PATH=D:/MSYS2 \
    "-DFXC_EXECUTABLE=D:/Windows Kits/10/bin/10.0.26100.0/x86/fxc.exe" \
    "${PY[@]}" \
    -DENABLE_OPTICAL=OFF -DENABLE_AIRTUNES=OFF -DENABLE_PLIST=OFF -DENABLE_MDNS=OFF \
    -DENABLE_BLURAY=OFF -DENABLE_UDFREAD=OFF -DENABLE_XSLT=OFF -DENABLE_CEC=OFF -DENABLE_NFS=OFF \
    -DENABLE_MARIADBCLIENT=OFF -DENABLE_MYSQLCLIENT=OFF -DENABLE_MICROHTTPD=OFF \
    -DENABLE_LCMS2=OFF -DENABLE_DVDCSS=OFF -DENABLE_UPNP=OFF -DENABLE_TESTING=OFF \
    -DFFMPEG_LIBAVCODEC=$PFX/lib/avcodec.lib -DFFMPEG_LIBAVFILTER=$PFX/lib/avfilter.lib \
    -DFFMPEG_LIBAVFORMAT=$PFX/lib/avformat.lib -DFFMPEG_LIBAVUTIL=$PFX/lib/avutil.lib \
    -DFFMPEG_LIBPOSTPROC=$PFX/lib/postproc.lib -DFFMPEG_LIBSWRESAMPLE=$PFX/lib/swresample.lib \
    -DFFMPEG_LIBSWSCALE=$PFX/lib/swscale.lib \
    "${INC[@]}" "$@" || { echo "[s9-configure $ARCH] CONFIGURE FAILED $(date '+%T')"; exit 1; }
  echo "[s9-configure $ARCH] CONFIGURE DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
grep -E "^-- (Building|Found|Could NOT|Warning)|CMake (Error|Warning)|Building |[Pp]ython|SWIG|DETOURS" "$LOG" | head -60
tail -3 "$LOG"
grep -E "^FFMPEG_LIB[A-Z]+:FILEPATH|^ENABLE_PYTHON:|^ENABLE_DETOURS:" "$BD/CMakeCache.txt" 2>/dev/null
exit $rc
