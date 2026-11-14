#!/bin/bash
# kodi-rt Stage 2/3: fetch the source tarballs Kodi pins, from Kodi's mirror, and check each against the SHA512 in
# Kodi's own pin file (tools/depends/target/<dir>/<NAME>-VERSION, or the Makefile for tinyxml) at the pinned commit.
# Approved by Hamed on 2026-11-12: these versions (Kodi's VERSION pins), each checked against that file's SHA512.
# Usage (Git Bash): bash scripts/s2-fetch-sources.sh [target-dir ...]   (default: the Stage 2/3 list below)
# Output: F:/kodi-rt/downloads/sources/<archive>, and downloads/sources/MANIFEST.tsv (dir, version, archive, bytes,
# sha512 status). A file whose hash doesn't match is kept as <archive>.bad and the script exits 1.
set -u
K=/f/kodi-rt/src/xbmc
T=$K/tools/depends/target
D=/f/kodi-rt/downloads/sources
MIRROR=https://mirrors.kodi.tv/build-deps/sources
mkdir -p "$D"
[ "$(git -C $K rev-parse HEAD)" = bffa625cc84860f241772d87a654844b98bebb60 ] || { echo "xbmc is not at the pinned commit"; exit 1; }

# Stage 2: ffmpeg, dav1d, zlib. Stage 3: the required libraries of KODI-RT-RECON.md section 1, minus Cdio (v1 has
# ENABLE_OPTICAL=OFF), libdvdcss (ENABLE_DVDCSS=OFF) and Detours (dropped for ARM32).
LIST=(ffmpeg dav1d zlib
      libass crossguid curl brotli nghttp2 zstd exiv2 flatbuffers fmt freetype2 fribidi fstrcmp harfbuzz libiconv
      libdvdnav libdvdread liblzo2 openssl pcre2 nlohmann_json spdlog sqlite3 taglib utfcpp tinyxml tinyxml2 effects11)
[ $# -gt 0 ] && LIST=("$@")

pinfile() { # dir -> the file that holds the pin
  local f
  f=$(ls "$T/$1"/*-VERSION 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "$f"; return; }
  echo "$T/$1/Makefile"
}
var() { grep -m1 -E "^$1=" "$2" | cut -d= -f2- | tr -d '\r'; }
expand() { # replace $(LIBNAME) $(VERSION) $(SOURCE) until stable
  local s=$1 prev=""
  while [ "$s" != "$prev" ]; do
    prev=$s
    s=${s//\$(LIBNAME)/$LIBNAME}; s=${s//\$(VERSION)/$VERSION}; s=${s//\$(SOURCE)/$SOURCE}
  done
  echo "$s"
}

bad=0
[ -f "$D/MANIFEST.tsv" ] || printf 'dir\tversion\tarchive\tbytes\tsha512\n' > "$D/MANIFEST.tsv"
for dir in "${LIST[@]}"; do
  P=$(pinfile "$dir")
  LIBNAME=$(var LIBNAME "$P"); VERSION=$(var VERSION "$P"); SOURCE=$(var SOURCE "$P")
  [ -z "$SOURCE" ] && SOURCE='$(LIBNAME)-$(VERSION)'
  SOURCE=$(expand "$SOURCE"); ARCHIVE=$(expand "$(var ARCHIVE "$P")"); WANT=$(var SHA512 "$P")
  if [ -z "$LIBNAME" ] || [ -z "$VERSION" ] || [ -z "$ARCHIVE" ] || [ ${#WANT} -ne 128 ]; then
    echo "[$dir] incomplete pin in $P (LIBNAME=$LIBNAME VERSION=$VERSION ARCHIVE=$ARCHIVE SHA512 ${#WANT} chars)"; bad=1; continue
  fi
  F=$D/$ARCHIVE
  if [ -f "$F" ] && [ "$(sha512sum "$F" | cut -d' ' -f1)" = "$WANT" ]; then
    echo "[$dir] $ARCHIVE already here, hash OK"; continue
  fi
  curl --proto '=https' --tlsv1.2 -fLsS --retry 5 --retry-connrefused -o "$F.part" "$MIRROR/$ARCHIVE" \
    || { echo "[$dir] download FAILED: $MIRROR/$ARCHIVE"; rm -f "$F.part"; bad=1; continue; }
  GOT=$(sha512sum "$F.part" | cut -d' ' -f1)
  if [ "$GOT" = "$WANT" ]; then
    mv "$F.part" "$F"
    printf '%s\t%s\t%s\t%s\t%s\n' "$dir" "$VERSION" "$ARCHIVE" "$(stat -c %s "$F")" OK >> "$D/MANIFEST.tsv"
    echo "[$dir] $ARCHIVE $(stat -c %s "$F") B, sha512 OK"
  else
    mv "$F.part" "$F.bad"
    printf '%s\t%s\t%s\t%s\t%s\n' "$dir" "$VERSION" "$ARCHIVE" "$(stat -c %s "$F.bad")" "MISMATCH got $GOT" >> "$D/MANIFEST.tsv"
    echo "[$dir] $ARCHIVE sha512 MISMATCH (kept as $ARCHIVE.bad)"; bad=1
  fi
done
[ $bad = 0 ] && echo "FETCH OK (${#LIST[@]} entries)" || { echo "FETCH HAD ERRORS"; exit 1; }
