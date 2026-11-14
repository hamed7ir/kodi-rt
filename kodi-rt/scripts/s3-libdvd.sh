#!/bin/bash
# kodi-rt Stage 3: libdvdread 7.0.1 and libdvdnav 7.0.0 the way Kodi's Windows build makes them
# (cmake/modules/FindLibDvdRead.cmake, FindLibDvdNav.cmake at bffa625c):
#   libdvdread: static, C flags -D_XBMC (Kodi's code paths in dvd_reader.c), patches 01 02 (all) + 03 04 05 06 08 (win),
#               -Denable_docs=false, no libdvdcss (v1 has ENABLE_DVDCSS=OFF).
#   libdvdnav:  SHARED on Windows (Kodi loads it at run time: DllDvdNav.h, DECLARE_DLL_WRAPPER(DllDvdNav,
#               DLL_PATH_LIBDVDNAV)), C flags -DWIN32_LEAN_AND_MEAN, patches 01-win-uwpcompat 02-win-remove-lib-version,
#               -Denable_docs=false -Denable_examples=false, linked against the static libdvdread.
#   Kodi gives libdvdnav the static libdvdread through pkg-config; meson here can't use Strawberry Perl's pkg-config,
#   so libdvdnav gets the same patched libdvdread as its own meson fallback subproject (its meson.build:84
#   dependency('dvdread', fallback: 'libdvdread'); libdvdread's src/meson.build overrides 'dvdread'), static, -D_XBMC.
# Usage (Git Bash): bash scripts/s3-libdvd.sh   (for $ARCH, cross/arch.sh: arm32 by default, or ARCH=x64 / ARCH=x86)
set -u
source /f/kodi-rt/cross/arch.sh
cd /f/kodi-rt || exit 1
T=/f/kodi-rt/src/xbmc/tools/depends/target
D=/f/kodi-rt/src/deps
R=$T/libdvdread
bash scripts/s3-prep.sh libdvdread $D/libdvdread-7.0.1 $R/01-all-disableopendir.patch $R/02-all-disablesymlink.patch \
  $R/03-win-add_defines.patch $R/04-win-uwp_compat.patch $R/05-win-remove_stat.patch $R/06-win-remove_config_h.patch \
  $R/08-win-ssize_t.patch || exit 1
# -Wno-error=implicit-function-declaration: dvd_reader.c:671 calls close() without <io.h>; MSVC (Kodi's Windows
# compiler) only warns, clang 23 rejects it by default (measured). The implicit int close() matches the real one.
DVDREAD_CARGS="['-D_XBMC', '-Wno-error=implicit-function-declaration']"
bash scripts/s3-meson.sh libdvdread $A_B3/src/libdvdread -Denable_docs=false -Dlibdvdcss=disabled \
  "-Dc_args=$DVDREAD_CARGS" || exit 1
bash scripts/s3-prep.sh libdvdnav $D/libdvdnav-7.0.0 $T/libdvdnav/01-win-uwpcompat.patch \
  $T/libdvdnav/02-win-remove-lib-version.patch || exit 1
mkdir -p $A_B3/src/libdvdnav/subprojects
cp -r $A_B3/src/libdvdread $A_B3/src/libdvdnav/subprojects/libdvdread || exit 1
# Each project gets its own C flags with add_project_arguments in these BUILD COPIES (src/deps stays pristine):
# meson applies the top project's -Dc_args to subprojects too and ignored -Dlibdvdread:c_args (measured), and
# WIN32_LEAN_AND_MEAN in libdvdread hides struct timeval (dvd_reader.c:90). Inserted after "cc = meson.get_compiler".
N=$A_B3/src/libdvdnav
sed -i "0,/^cc = meson.get_compiler('c')/s//cc = meson.get_compiler('c')\nadd_project_arguments('-DWIN32_LEAN_AND_MEAN', language: 'c')  # kodi-rt: FindLibDvdNav.cmake C_FLAGS/" $N/meson.build
sed -i "0,/^cc = meson.get_compiler('c')/s//cc = meson.get_compiler('c')\nadd_project_arguments(['-D_XBMC', '-Wno-error=implicit-function-declaration'], language: 'c')  # kodi-rt: FindLibDvdRead.cmake C_FLAGS/" $N/subprojects/libdvdread/meson.build
grep -c 'kodi-rt: FindLibDvd' $N/meson.build $N/subprojects/libdvdread/meson.build
LIBTYPE=shared bash scripts/s3-meson.sh libdvdnav $A_B3/src/libdvdnav -Denable_docs=false \
  -Denable_examples=false --force-fallback-for=dvdread \
  -Dlibdvdread:default_library=static -Dlibdvdread:enable_docs=false -Dlibdvdread:libdvdcss=disabled || exit 1
echo "LIBDVD DONE"
