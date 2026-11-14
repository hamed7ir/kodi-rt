#!/bin/bash
# kodi-rt Stage 10: Kodi's binary add-ons for ARM32 (Kodi's repository has Windows builds for x64, x86 and arm64 but
# none for 32-bit ARM; x64/x86 users install them from the repository). This script builds the libraries the
# add-ons need that the Kodi prefix doesn't have, static /MT with rt2.4, into prefix/<arch>-addons. URLs and sha256
# come from the add-ons' own depends/ files (Piers branches in src/addons); the archives go to
# downloads/sources/addons and are checked against that sha256 on every run.
#   pugixml      pvr.iptvsimple, inputstream.adaptive
#   dlfcn-win32  inputstream.adaptive (dlopen for Windows)
#   bento4       inputstream.adaptive (Kodi's Bento4 fork, MP4 parsing)
#   librtmp      inputstream.rtmp (rtmpdump v2.6, a git clone at the add-on's pinned revision)
#   libxml2      inputstream.ffmpegdirect (its FFmpeg's DASH demuxer), bz2: its FFmpeg's bzlib
#   lz4, libarchive  vfs.libarchive (with bz2, and LZO2, OpenSSL, xz, zlib from prefix/<arch>)
# zlib, liblzma, nlohmann/json and OpenSSL come from prefix/<arch> (Kodi's and the Python stage's builds).
# Usage (Git Bash): bash scripts/s10-addon-deps.sh <arm32|x64|x86> [pugixml dlfcn-win32 bento4 ...]
#   Log: logs/s10-addon-deps-<arch>.log
set -u
ARCH=${1:?usage: s10-addon-deps.sh <arm32|x64|x86> [dep ...]}; shift
. /f/kodi-rt/cross/arch.sh
WHAT=("$@"); [ ${#WHAT[@]} = 0 ] && WHAT=(pugixml dlfcn-win32 bento4)
K=F:/kodi-rt
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
PFX=$K/prefix/$ARCH-addons
AD=/f/kodi-rt/src/addons
DL=/f/kodi-rt/downloads/sources/addons
SRC=/f/kodi-rt/build/s10/src
LOG=/f/kodi-rt/logs/s10-addon-deps-$ARCH.log
mkdir -p "$DL" "$SRC"
[ -f "$DL/MANIFEST.tsv" ] || printf 'name\turl\tarchive\tbytes\tsha256\n' > "$DL/MANIFEST.tsv"

fetch() { # name depends-dir: the URL in <dir>/<name>.txt, checked against <dir>/<name>.sha256, unpacked into $SRC/<name>
  local name=$1 dd=$2 url want f got
  url=$(awk 'NR==1{print $2}' "$dd/$name.txt"); want=$(awk 'NR==1{print $1}' "$dd/$name.sha256")
  [ -n "$url" ] && [ -n "$want" ] || { echo "no URL or sha256 for $name in $dd"; return 1; }
  f=$DL/$name-$(basename "$url")
  if [ ! -f "$f" ]; then
    echo "download $url"
    curl -fsSL --max-time 600 -o "$f.part" "$url" && mv "$f.part" "$f" || { echo "download failed: $url"; rm -f "$f.part"; return 1; }
  fi
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "SHA256 MISMATCH $f: $got, want $want"; return 1; }
  echo "sha256 OK $(basename "$f")"
  grep -qF "$(basename "$f")" "$DL/MANIFEST.tsv" || printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$url" "$(basename "$f")" "$(stat -c %s "$f")" "$want" >> "$DL/MANIFEST.tsv"
  rm -rf "$SRC/$name" && mkdir -p "$SRC/$name" && tar -xf "$f" -C "$SRC/$name" --strip-components=1
}

# the arch's toolchain file roots every search in prefix/<arch>: a wrapper adds $PFX as a second root (the same file
# scripts/s10-addon.sh writes), and CMAKE_PREFIX_PATH names both roots so packages there are found (OpenSSL, zlib)
TCW=$K/build/s10/toolchain-$ARCH.cmake
mkdir -p /f/kodi-rt/build/s10
printf 'include(%s)\nlist(APPEND CMAKE_FIND_ROOT_PATH "%s")\nstring(APPEND CMAKE_C_FLAGS_INIT " -DNOMINMAX")\nstring(APPEND CMAKE_CXX_FLAGS_INIT " -DNOMINMAX")\n' \
  "$A_TCFILE" "$PFX" > "$TCW"
dep() { # name depends-dir [cmake options]: the way Kodi's add-on build handles a dependency (HandleDepends):
  # fetch and check it, apply the depends folder's patches (sorted), use its CMakeLists.txt if it has one, then
  # build with its flags.txt plus the options given
  local name=$1 dd=$2; shift 2
  fetch $name $dd || return 1
  local p; for p in $(ls "$dd"/*.patch 2>/dev/null | sort); do
    echo "patch $(basename "$p")"; patch -d "$SRC/$name" -p1 -N -i "$p" > /dev/null || { echo "patch failed: $p"; return 1; }
  done
  [ -f "$dd/CMakeLists.txt" ] && cp "$dd/CMakeLists.txt" "$SRC/$name/"
  cm $name $SRC/$name $(cat "$dd/flags.txt" 2>/dev/null) "$@"
}

cm() { # name source-dir cmake-options...: configure, build and install into $PFX (static: the add-on DLLs must not
  # need further DLLs; projects whose default is shared get BUILD_SHARED_LIBS=OFF)
  local name=$1 src=$2; shift 2
  local bd=$K/build/s10/deps-$ARCH-$name
  rm -rf "$bd"
  "$CMAKE" -G Ninja -S "$src" -B "$bd" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$TCW \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PFX -DCMAKE_PREFIX_PATH="$PFX;$A_PFX" \
    -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW "$@" &&
  "$CMAKE" --build "$bd" -- -j 8 && "$CMAKE" --install "$bd"
}

{
  echo "== kodi-rt add-on deps for $ARCH, $(date '+%Y-%m-%d %H:%M:%S'): ${WHAT[*]} -> $PFX"
  rc=0
  for w in "${WHAT[@]}"; do
    echo "-- $w"
    case $w in
      pugixml)
        fetch pugixml $AD/pvr.iptvsimple/depends/common/pugixml &&
        cm pugixml $SRC/pugixml -DBUILD_SHARED_LIBS=OFF -DPUGIXML_BUILD_TESTS=OFF -DCMAKE_INSTALL_LIBDIR=lib ;;
      dlfcn-win32)
        fetch dlfcn-win32 $AD/inputstream.adaptive/depends/windows/dlfcn-win32 &&
        cm dlfcn-win32 $SRC/dlfcn-win32 -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF ;;
      bento4)
        fetch bento4 $AD/inputstream.adaptive/depends/common/bento4 &&
        cm bento4 $SRC/bento4 -DBUILD_APPS=OFF -DCMAKE_INSTALL_INCLUDEDIR=include -DCMAKE_INSTALL_LIBDIR=lib ;;
      librtmp)
        # rtmpdump v2.6 at the add-on's pinned revision, cloned by its own depends CMake (FetchSource.cmake) with its
        # patches; built against OpenSSL and zlib from prefix/<arch>
        cm librtmp $AD/inputstream.rtmp/depends/windows/librtmp ;;
      libxml2)
        fetch libxml2 $AD/inputstream.ffmpegdirect/depends/common/libxml2 &&
        cm libxml2 $SRC/libxml2 $(cat $AD/inputstream.ffmpegdirect/depends/common/libxml2/flags.txt) ;;
      lz4)
        dep lz4 $AD/vfs.libarchive/depends/common/lz4 -DBUILD_STATIC_LIBS=ON ;;
      libarchive)
        # the add-on's Windows flags say WINDOWS_VERSION=WIN10; the tablet runs Windows RT 8.1
        dep libarchive $AD/vfs.libarchive/depends/windows/libarchive -DWINDOWS_VERSION=WIN8 ;;
      bz2)
        # bzip2 1.0.8 (Kodi's mirror) with the add-on's own CMakeLists.txt (bzip2 has none)
        fetch bz2 $AD/inputstream.ffmpegdirect/depends/common/bz2 &&
        cp $AD/inputstream.ffmpegdirect/depends/common/bz2/CMakeLists.txt $SRC/bz2/ &&
        cm bz2 $SRC/bz2 ;;
      *) echo "unknown dep $w"; false ;;
    esac
    r=$?; [ $r = 0 ] && echo "-- $w: OK" || { echo "-- $w: FAILED ($r)"; rc=1; }
  done
  [ $rc = 0 ] && echo "ADDON DEPS ($ARCH): OK" || echo "ADDON DEPS ($ARCH): FAILED"
} 2>&1 | tee "$LOG" | grep -E '^(==|--|download|sha256|SHA256|ADDON DEPS)|error|Error' | grep -v 'Error.cpp\|error.h'
