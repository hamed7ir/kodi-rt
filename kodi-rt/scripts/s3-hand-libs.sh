#!/bin/bash
# kodi-rt Stage 3: the libraries without a usable build system here, through kodi-rt's own small CMake projects in
# cross/cmake/<lib>/ (each explains which Kodi recipe it follows): sqlite3, tinyxml, fstrcmp. Static, rt2.4, for $ARCH
# (cross/arch.sh: arm32 by default, or ARCH=x64 / ARCH=x86).
# Usage (Git Bash): bash scripts/s3-hand-libs.sh [name ...]
set -u
source /f/kodi-rt/cross/arch.sh
cd /f/kodi-rt || exit 1
T=/f/kodi-rt/src/xbmc/tools/depends/target
D=/f/kodi-rt/src/deps
build() {
  case $1 in
    sqlite3)
      bash scripts/s3-prep.sh sqlite3 $D/sqlite-autoconf-3390400 $T/sqlite3/sqlite3.c.patch || return 1
      bash scripts/s3-cmake.sh sqlite3 F:/kodi-rt/cross/cmake/sqlite3 -DSQLITE_SRC=$A_B3/src/sqlite3 ;;
    tinyxml)
      bash scripts/s3-cmake.sh tinyxml F:/kodi-rt/cross/cmake/tinyxml -DTINYXML_SRC=F:/kodi-rt/src/deps/tinyxml-2.6.2_2 ;;
    fstrcmp)
      bash scripts/s3-cmake.sh fstrcmp F:/kodi-rt/cross/cmake/fstrcmp -DFSTRCMP_SRC=F:/kodi-rt/src/deps/fstrcmp-0.7.D001 ;;
    *) echo "unknown library $1"; return 1 ;;
  esac
}
LIST=(sqlite3 tinyxml fstrcmp)
[ $# -gt 0 ] && LIST=("$@")
fail=0
for l in "${LIST[@]}"; do build "$l" || { echo "### $l FAILED"; fail=1; }; done
[ $fail = 0 ] && echo "HAND LIBS DONE" || echo "HAND LIBS HAD FAILURES"
