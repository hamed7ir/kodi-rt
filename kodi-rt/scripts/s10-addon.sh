#!/bin/bash
# kodi-rt Stage 10: one of Kodi's binary add-ons (src/addons/<id>, its Piers branch), built against our Kodi's own
# add-on dev kit with rt2.4, static /MT, into build/s10/install-<arch>/<id> (the DLL, addon.xml and resources: the
# folder Kodi loads, drop-in for the kit's addons/).
# PACKAGE_ZIP=1 makes build_addon install the Windows layout (one folder per add-on) instead of lib/ + share/
# The dev kit is the one the arch's Kodi build writes (build/lib/kodi/KodiConfig.cmake + AddonHelpers.cmake,
# build/include/kodi), copied to build/s10/devkit-<arch> with PLATFORM_TAG set: Kodi only loads a binary add-on whose
# addon.xml <platform> it knows, and our Kodi accepts "windows-arm" on ARM32 (patch 0002).
# Libraries: prefix/<arch>-addons (scripts/s10-addon-deps.sh), then prefix/<arch>.
# Usage (Git Bash): bash scripts/s10-addon.sh <arm32|x64|x86> <addon-id> [extra cmake options]
#   Log: logs/s10-<addon-id>-<arch>.log
set -u
ARCH=${1:?usage: s10-addon.sh <arm32|x64|x86> <addon-id> [cmake options]}; ID=${2:?usage: s10-addon.sh <arch> <addon-id>}; shift 2
. /f/kodi-rt/cross/arch.sh
K=F:/kodi-rt
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
case $ARCH in
  arm32) KB=$K/build/s7/kodi-build-pgo; TAG=windows-arm ;;
  x64)   KB=$K/build/s9/kodi-build-x64; TAG=windows-x86_64 ;;
  x86)   KB=$K/build/s9/kodi-build-x86; TAG=windows-i686 ;;
esac
DK=$K/build/s10/devkit-$ARCH
SRC=$K/src/addons/$ID
BD=$K/build/s10/$ID-$ARCH
INST=$K/build/s10/install-$ARCH
LOG=/f/kodi-rt/logs/s10-$ID-$ARCH.log
[ -f "$SRC/CMakeLists.txt" ] || { echo "no $SRC"; exit 1; }
[ -f "$KB/build/lib/kodi/KodiConfig.cmake" ] || { echo "no Kodi dev kit in $KB (configure Kodi first)"; exit 1; }
{
  echo "== kodi-rt add-on $ID for $ARCH ($(git -C "$SRC" rev-parse --short=12 HEAD)), $(date '+%Y-%m-%d %H:%M:%S')"
  # the dev kit, refreshed when the Kodi build's copy is newer
  if [ ! -f "$DK/lib/kodi/KodiConfig.cmake" ] || [ "$KB/build/lib/kodi/KodiConfig.cmake" -nt "$DK/lib/kodi/KodiConfig.cmake" ]; then
    rm -rf "$DK" && mkdir -p "$DK/lib" "$DK/include" &&
    cp -r "$KB/build/lib/kodi" "$DK/lib/" && cp -r "$KB/build/include/kodi" "$DK/include/" &&
    sed -i "s|$KB/build|$DK|g; s|^set(PLATFORM_TAG )\$|set(PLATFORM_TAG $TAG)|" "$DK/lib/kodi/KodiConfig.cmake" || exit 1
    grep -q "^set(PLATFORM_TAG $TAG)" "$DK/lib/kodi/KodiConfig.cmake" || { echo "PLATFORM_TAG not set in the dev kit"; exit 1; }
    echo "dev kit: $DK (PLATFORM_TAG $TAG)"
  fi
  # the arch's toolchain file roots every search in prefix/<arch>: add prefix/<arch>-addons as a second root.
  # NOMINMAX as in Kodi's own build (cmake/scripts/windows/ArchSetup.cmake): code that includes <windows.h> before the
  # dev kit's headers (inputstream.adaptive's CDM adapter) would otherwise break std::min/std::max in them
  # inputstream.ffmpegdirect links its own FFmpeg (scripts/s10-ffmpeg.sh), whose libraries have the same names as
  # Kodi's in prefix/<arch>: its prefix becomes the FIRST root, so it wins
  FIRST=; EXTRA=()
  case $ID in
    inputstream.ffmpegdirect) FIRST=$K/prefix/$ARCH-ffmpegdirect; EXTRA=(-DFFMPEG_PATH=$FIRST)
      [ -f "/f/kodi-rt/prefix/$ARCH-ffmpegdirect/lib/avformat.lib" ] || { echo "no FFmpeg in $FIRST (scripts/s10-ffmpeg.sh)"; exit 1; } ;;
  esac
  TCW=$K/build/s10/toolchain-$ARCH.cmake
  printf 'include(%s)\nlist(APPEND CMAKE_FIND_ROOT_PATH "%s")\nstring(APPEND CMAKE_C_FLAGS_INIT " -DNOMINMAX")\nstring(APPEND CMAKE_CXX_FLAGS_INIT " -DNOMINMAX")\n' \
    "$A_TCFILE" "$K/prefix/$ARCH-addons" > "$TCW"
  [ -n "$FIRST" ] && printf 'list(PREPEND CMAKE_FIND_ROOT_PATH "%s")\n' "$FIRST" >> "$TCW"
  # system libraries: static OpenSSL (inputstream.rtmp, .ffmpegdirect) also needs crypt32 (certificate store) and
  # advapi32 (CryptoAPI, event log), libarchive bcrypt (CNG); the linker drops the ones an add-on doesn't use
  SYSLIBS="kernel32.lib user32.lib advapi32.lib crypt32.lib ws2_32.lib bcrypt.lib"
  # kodi-rt's fixes to the add-on (patches-addons/<id>/*.patch), on the clone reset to its pinned commit
  git -C "$SRC" checkout -q -- . && git -C "$SRC" clean -fdq || exit 1
  for p in $(ls /f/kodi-rt/patches-addons/$ID/*.patch 2>/dev/null | sort); do
    git -C "$SRC" apply --whitespace=nowarn "$p" && echo "patch: $(basename "$p")" || { echo "patch failed: $p"; exit 1; }
  done
  rm -rf "$BD"
  "$CMAKE" -G Ninja -S "$SRC" -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$TCW \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DKodi_DIR=$DK/lib/kodi \
    -DCMAKE_PREFIX_PATH="${FIRST:+$FIRST;}$K/prefix/$ARCH-addons;$A_PFX" -DCMAKE_INSTALL_PREFIX=$INST -DBUILD_TESTING=OFF \
    -DCMAKE_C_STANDARD_LIBRARIES="$SYSLIBS" -DCMAKE_CXX_STANDARD_LIBRARIES="$SYSLIBS" \
    -DPACKAGE_ZIP=1 "${EXTRA[@]}" "$@" &&
  "$CMAKE" --build "$BD" -- -j 8 && rm -rf "$INST/$ID" && "$CMAKE" --install "$BD" || { echo "ADDON $ID ($ARCH): FAILED"; exit 1; }
  dll=$(ls "$INST/$ID"/*.dll 2>/dev/null | head -1)
  [ -n "$dll" ] || { echo "ADDON $ID ($ARCH): no DLL installed"; exit 1; }
  grep -o '<platform>[^<]*</platform>' "$INST/$ID/addon.xml"
  echo "installed: $INST/$ID ($(ls "$INST/$ID" | tr '\n' ' ')); $(basename "$dll") $(stat -c %s "$dll") bytes"
  echo "ADDON $ID ($ARCH): OK"
} 2>&1 | tee "$LOG" | grep -E '^(==|dev kit|patch|installed|<platform>|ADDON)|error:|FAILED' | grep -v 'Error.cpp'
exit ${PIPESTATUS[0]}
