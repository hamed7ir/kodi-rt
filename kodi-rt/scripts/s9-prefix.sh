#!/bin/bash
# kodi-rt Stage 9: the dependency prefix F:/kodi-rt/prefix/$ARCH for one architecture (cross/arch.sh), built with the
# same Stage 2/3 scripts as ARM32, in dependency order:
#   zlib     s2-zlib.sh                       iconv  s3-libiconv.sh (MSYS2's bash, GNU make)
#   small    s3-small-libs.sh (pcre2 fmt spdlog nlohmann_json crossguid lzo2 tinyxml2)
#   more     s3-more-libs.sh without curl (brotli utfcpp taglib exiv2 flatbuffers effects11 nghttp2 zstd)
#   openssl  s3-openssl.cmd (x64/x86; cmd + nmake)  curl  s3-more-libs.sh curl
#   font     s3-font-libs.sh (freetype, harfbuzz, fribidi, libass)
#   hand     s3-hand-libs.sh (sqlite3 tinyxml fstrcmp)
#   dvd      s3-libdvd.sh (libdvdread, libdvdnav DLL)   dav1d  s2-dav1d.sh
# libiconv comes before exiv2 and libass: both find it (as in the ARM32 prefix). FFmpeg follows in s9-ffmpeg.sh.
# Usage (Git Bash): ARCH=x64 bash scripts/s9-prefix.sh [step ...]   (default: all steps; stops at the first failure)
# Summary: logs/s9-prefix-$ARCH.log. Each step's output: logs/s9-$ARCH-<step>.log; the libraries keep their own logs
# (logs/s3-$ARCH-<name>.log and so on).
set -u
source /f/kodi-rt/cross/arch.sh
[ "$ARCH" = arm32 ] && { echo "s9-prefix.sh is for x64/x86; the ARM32 prefix exists (Stage 2/3)"; exit 1; }
cd /f/kodi-rt || exit 1
LOG=/f/kodi-rt/logs/s9-prefix-$ARCH.log
STEPS=(zlib iconv small more openssl curl font hand dvd dav1d)
[ $# -gt 0 ] && STEPS=("$@")
say() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
last_has() { tail -2 "$1" 2>/dev/null | grep -q "$2"; }
run() { # step: returns 0 when the step's log ends with its DONE line
  local L=/f/kodi-rt/logs/s9-$ARCH-$1.log
  case $1 in
    zlib)    bash scripts/s2-zlib.sh > $L 2>&1; last_has $L 'ZLIB DONE' ;;
    iconv)   MSYSTEM=MSYS /d/MSYS2/usr/bin/bash.exe -l -c "ARCH=$ARCH bash /f/kodi-rt/scripts/s3-libiconv.sh" > $L 2>&1
             last_has $A_LOG3-libiconv.log 'LIBICONV DONE' ;;
    small)   bash scripts/s3-small-libs.sh > $L 2>&1; last_has $L 'SMALL LIBS DONE' ;;
    more)    bash scripts/s3-more-libs.sh brotli utfcpp taglib exiv2 flatbuffers effects11 nghttp2 zstd > $L 2>&1
             last_has $L 'MORE LIBS DONE' ;;
    openssl) MSYS2_ARG_CONV_EXCL='*' cmd.exe /c 'F:\kodi-rt\scripts\s3-openssl.cmd' $ARCH > $L 2>&1
             last_has /f/kodi-rt/logs/s3-$ARCH-openssl.log 'OPENSSL DONE' ;;
    curl)    bash scripts/s3-more-libs.sh curl > $L 2>&1; last_has $L 'MORE LIBS DONE' ;;
    font)    bash scripts/s3-font-libs.sh > $L 2>&1; last_has $L 'FONT LIBS DONE' ;;
    hand)    bash scripts/s3-hand-libs.sh > $L 2>&1; last_has $L 'HAND LIBS DONE' ;;
    dvd)     bash scripts/s3-libdvd.sh > $L 2>&1; last_has $L 'LIBDVD DONE' ;;
    dav1d)   bash scripts/s2-dav1d.sh > $L 2>&1; last_has $L 'DAV1D DONE' ;;
    *) echo "unknown step $1"; return 1 ;;
  esac
}
say "=== s9-prefix $ARCH: ${STEPS[*]} (prefix $A_PFX, toolchain $A_RT)"
for s in "${STEPS[@]}"; do
  say "--- $s"
  if run "$s"; then say "ok $s"; else say "FAILED $s (logs/s9-$ARCH-$s.log)"; say "S9 PREFIX $ARCH FAILED at $s"; exit 1; fi
done
say "S9 PREFIX $ARCH DONE"
