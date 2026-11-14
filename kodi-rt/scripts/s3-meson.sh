#!/bin/bash
# kodi-rt Stage 3: build one meson library (static, /MT, rt2.4) for $ARCH (cross/arch.sh: arm32 by default) with
# cross/meson-$ARCH.ini, -j8, and install it. --wrap-mode=nodownload: a missing dependency fails instead of fetching a subproject from the network.
# Usage (Git Bash): bash scripts/s3-meson.sh <name> <source dir> [meson args...]
#   env PFX (default F:/kodi-rt/prefix/$ARCH): install prefix; dependencies are found through CMake configs in it
#   env EXTRA_PREFIX: more prefixes for -Dcmake_prefix_path (","-separated)
#   env LIBTYPE (default static): --default-library (libdvdnav is a DLL in Kodi's Windows build)
#   Build dir: $A_B3/<name> (recreated; arm32: F:/kodi-rt/build/s3/<name>). Log: $A_LOG3-<name>.log
set -u
source /f/kodi-rt/cross/arch.sh
export MSYS2_ARG_CONV_EXCL='*'
# rt2.4 first (meson's clang-cl detection runs a bare lld-link), then ninja and cmake (for method: 'cmake' dependencies)
export PATH="$A_RTP/bin:/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin:$PATH"
MESON=F:/kodi-rt/tools/pyenv/Scripts/meson.exe
NAME=$1; SRC=$2; shift 2
PFX=${PFX:-$A_PFX}
CPP="$PFX${EXTRA_PREFIX:+,$EXTRA_PREFIX}"
BD=$A_B3/$NAME
LOG=$A_LOG3-$NAME.log
rm -rf "$BD"
# pkg-config for dependency(): Strawberry Perl's pure-Perl pkg-config, looking ONLY at our prefixes' lib/pkgconfig.
# A per-build cross file (meson merges several), kept beside the build dir because setup recreates the build dir.
PCINI=$A_B3/$NAME-pkgconfig.ini
LIBDIRS="'$PFX/lib/pkgconfig'"
EP=${EXTRA_PREFIX:-}
for p in ${EP//,/ }; do LIBDIRS="$LIBDIRS, '$p/lib/pkgconfig'"; done
mkdir -p "$A_B3"
cat > "$PCINI" <<EOF
[binaries]
pkg-config = ['F:/kodi-rt/tools/strawberry-perl/perl/bin/perl.exe', 'F:/kodi-rt/tools/strawberry-perl/perl/bin/pkg-config']
[properties]
pkg_config_libdir = [$LIBDIRS]
EOF
{
  echo "[$NAME] $(date '+%T') setup: $*"
  "$MESON" setup "$BD" "$SRC" --cross-file "$A_MESON" --cross-file "$PCINI" --prefix "$PFX" --libdir lib \
    --buildtype release --default-library "${LIBTYPE:-static}" --wrap-mode=nodownload "-Dcmake_prefix_path=$CPP" "$@" \
    || { echo "[$NAME] SETUP FAILED"; exit 1; }
  echo "[$NAME] $(date '+%T') build"
  "$MESON" compile -C "$BD" -j 8 || { echo "[$NAME] BUILD FAILED"; exit 1; }
  echo "[$NAME] $(date '+%T') install"
  "$MESON" install -C "$BD" || { echo "[$NAME] INSTALL FAILED"; exit 1; }
  echo "[$NAME] DONE $(date '+%T')"
} > "$LOG" 2>&1
rc=$?
tail -3 "$LOG"
echo "[$NAME] warnings: $(grep -c 'warning:' "$LOG")"
exit $rc
