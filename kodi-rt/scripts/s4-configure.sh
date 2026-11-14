#!/bin/bash
# kodi-rt Stage 4: configure Kodi for Windows ARM32 (Windows RT 8.1) with rt2.4.
#   source:  F:/kodi-rt/build/s4/kodi        (patched tree from scripts/s4-apply-patches.sh)
#   build:   F:/kodi-rt/build/s4/kodi-build  (recreated)
#   log:     F:/kodi-rt/logs/s4-configure.log
# Usage (Git Bash): bash scripts/s4-configure.sh [extra cmake args]
#
# Choices (plan §3 Stage 4; reports/KODI-RT-RECON.md):
#  - Ninja + cross/arm32-rt24.cmake (the VS generator can't run here and has no ARM32 clang toolset: recon §4).
#  - CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=10.0.26100.0: Kodi's SDK floor check reads it, and only the VS generator
#    sets it (recon row 3). 26100 is the header SDK of the toolchain file.
#  - Every library from prefix/arm32 (Stages 2-3), none built by Kodi: DEPENDS_PATH=<prefix> (patch 0001 makes it
#    overridable), USE_INTERNAL_LIBS=OFF (every dependent_option ENABLE_INTERNAL_* defaults OFF), and
#    ENABLE_INTERNAL_CROSSGUID=OFF (a plain option, default ON).
#  - FFmpeg: -DWITH_FFMPEG=<prefix>; patch 0004 keeps Kodi's MSYS2 FFmpeg build job out. libpostproc IS linked
#    (Kodi's default), not -DDISABLE_FFMPEG_SOURCE_PLUGINS=ON as the plan suggests: our FFmpeg uses Kodi's options,
#    so avfilter has the pp filter, which needs libpostproc (measured: pp_* undefined in avfilter.lib(vf_pp.o)).
#  - KODI_MIRROR points nowhere and TARBALL_DIR at our sha512-checked downloads/sources: nothing is downloaded.
#    The only ExternalProject expected is the host flatc (flatbuffers-23.3.3.tar.gz, from TARBALL_DIR, hash checked by
#    ExternalProject) and JsonSchemaBuilder (in-tree source), both built with
#    project/BuildDependencies/tools/share/Toolchain-Native.cmake (= cross/x64-host-rt24.cmake).
#  - pkg-config (Kodi's FindLibDvdRead/Nav take dvdread/dvdnav only from pkg-config on Windows): Kodi's own pinned
#    pkgconf, which its FindPkgConfig takes from NATIVEPREFIX/bin (scripts/s4-host-pkgconf.sh builds it there; Kodi
#    refuses Strawberry Perl's wrapper on purpose). PKG_CONFIG_LIBDIR = the prefix's lib/pkgconfig only.
#  - MSYS_INSTALL_PATH: FindMsys is a required tool on Windows (only the FFmpeg build job uses it).
#  - FXC from the 26100 SDK (FindEffectsCompiler looks in bin/x86 of the registry's SDK folder, which has none).
#  - v1 switches off (recon §1): Python, optical, AirTunes, plist, mDNS, Blu-ray, udfread, XSLT, CEC, NFS,
#    MariaDB/MySQL, microhttpd, LCMS2, libdvdcss, UPnP, tests. NOT SMB: on Windows "SmbClient" is the native Win32 SMB
#    (no library; FindSmbClient only defines HAS_FILESYSTEM_SMB), and Win32SMBDirectory.cpp, always built, needs it
#    (measured: CServiceBroker::GetWSDiscovery undefined with -DENABLE_SMBCLIENT=OFF).
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKEDIR="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake"
CMAKE="$CMAKEDIR/CMake/bin/cmake.exe"
NINJA="$CMAKEDIR/Ninja/ninja.exe"
# ExternalProjects run their own "cmake -G Ninja": they need ninja on PATH
export PATH="/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
PFX=F:/kodi-rt/prefix/arm32
SRC=F:/kodi-rt/build/s4/kodi
BD=F:/kodi-rt/build/s4/kodi-build
LOG=/f/kodi-rt/logs/s4-configure.log
export PKG_CONFIG_LIBDIR=$PFX/lib/pkgconfig
export PKG_CONFIG_PATH=
# Toolchain bug 0032 is fixed in rt2.4 0318206a (tc/rt24c-cr, the toolchain file's). The interim it needed with
# 0549949d (cross/kodi-rt-interim-0032.cmake) is off by default now; KODIRT_0032_WORKAROUND=1 would add it again.
INTERIM=
[ "${KODIRT_0032_WORKAROUND:-0}" = 1 ] && INTERIM=-DCMAKE_PROJECT_kodi_INCLUDE=F:/kodi-rt/cross/kodi-rt-interim-0032.cmake
# CMake 3.31 gives clang-cl only "kernel32.lib user32.lib" as standard libraries. Kodi's VS-generator build gets
# Visual Studio's default list, and Kodi relies on it (gdi32 for WinSystemWin32.cpp and libass's DirectWrite fonts:
# measured, undefined GDI symbols at the first link). The VS list, without ODBC:
STDLIBS="kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib"
for f in share/Toolchain-Native.cmake bin/pkgconf.exe tools/TexturePacker/TexturePacker.exe; do
  [ -f "$SRC/project/BuildDependencies/tools/$f" ] || { echo "no $f: run scripts/s4-apply-patches.sh first"; exit 1; }
done
rm -rf "$BD"
[ -e "$BD" ] && { echo "could not remove $BD"; exit 1; }
{
  echo "[s4-configure] $(date '+%F %T') start"
  "$CMAKE" -G Ninja -S "$SRC" -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=F:/kodi-rt/cross/arm32-rt24.cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=10.0.26100.0 \
    -DDEPENDS_PATH=$PFX -DUSE_INTERNAL_LIBS=OFF -DENABLE_INTERNAL_CROSSGUID=OFF \
    -DWITH_FFMPEG=$PFX \
    "-DCMAKE_C_STANDARD_LIBRARIES=$STDLIBS" "-DCMAKE_CXX_STANDARD_LIBRARIES=$STDLIBS" \
    -DKODI_MIRROR=http://127.0.0.1:9/kodi-rt-no-downloads -DTARBALL_DIR=F:/kodi-rt/downloads/sources \
    -DMSYS_INSTALL_PATH=D:/MSYS2 \
    "-DFXC_EXECUTABLE=D:/Windows Kits/10/bin/10.0.26100.0/x86/fxc.exe" \
    -DENABLE_PYTHON=OFF -DENABLE_OPTICAL=OFF -DENABLE_AIRTUNES=OFF -DENABLE_PLIST=OFF -DENABLE_MDNS=OFF \
    -DENABLE_BLURAY=OFF -DENABLE_UDFREAD=OFF -DENABLE_XSLT=OFF -DENABLE_CEC=OFF -DENABLE_NFS=OFF \
    -DENABLE_MARIADBCLIENT=OFF -DENABLE_MYSQLCLIENT=OFF -DENABLE_MICROHTTPD=OFF \
    -DENABLE_LCMS2=OFF -DENABLE_DVDCSS=OFF -DENABLE_UPNP=OFF -DENABLE_TESTING=OFF \
    $INTERIM "$@" || { echo "[s4-configure] CONFIGURE FAILED $(date '+%T')"; exit 1; }
  echo "[s4-configure] CONFIGURE DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
grep -E "^-- (Building|Found|Could NOT|Warning)|CMake (Error|Warning)|Building " "$LOG" | head -80
tail -3 "$LOG"
exit $rc
