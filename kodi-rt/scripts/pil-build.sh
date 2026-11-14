#!/bin/bash
# kodi-rt: Pillow 12.0.0 (Kodi's pin) as Kodi's script.module.pil, per architecture:
#   - its C modules: cross/cmake/pillow (clang-cl /MT; _imaging with libjpeg-turbo + zlib, _imagingft with FreeType
#     and raqm on HarfBuzz + FriBidi, _imagingmath, _imagingmorph), linked against prefix/<arch>/python
#   - the PIL package (src/PIL, as the wheel has it), Kodi's addon.xml + icon.png (src/xbmc/addons/script.module.pil)
#   - LICENSE (Pillow's) and NOTICE.txt (the libraries linked into the modules, with their licences)
# Needs: prefix/<arch>/python (scripts/py-build.sh), prefix/<arch>/lib/jpeg-static.lib (scripts/py-deps.sh <arch> jpeg).
# Result: prefix/<arch>/kodi-addons/script.module.pil (drop-in for the kit's addons/ folder).
# Usage (Git Bash): bash scripts/pil-build.sh <arm32|x64|x86>     Log: logs/pil-<arch>.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
K=F:/kodi-rt
V=${1:-}
case $V in arm32|x64|x86) TC=$K/cross/$V-rt24.cmake ;; *) echo "usage: pil-build.sh <arm32|x64|x86>"; exit 2 ;; esac
SRC=$K/src/deps/pillow-12.0.0
KADDON=$K/src/xbmc/addons/script.module.pil
BD=$K/build/pil/$V
ADDON=/f/kodi-rt/prefix/$V/kodi-addons/script.module.pil
LOG=/f/kodi-rt/logs/pil-$V.log
{
  set -e
  echo "[pil-$V] $(date '+%F %T') start"
  rm -rf "$(cygpath -u "$BD")" "$ADDON"
  mkdir -p "$ADDON/lib"
  cp -r "$SRC/src/PIL" "$ADDON/lib/PIL"
  find "$ADDON/lib/PIL" -name __pycache__ -prune -exec rm -rf {} +
  "$CMAKE" -G Ninja -S $K/cross/cmake/pillow -B "$BD" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$TC \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DPIL_SRC=$SRC -DPIL_PYTHON=$K/prefix/$V/python \
    -DPIL_DEPS_PREFIX=$K/prefix/$V -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$ADDON")/lib"
  "$CMAKE" --build "$BD" -- -j 8
  "$CMAKE" --install "$BD"
  cp "$KADDON/addon.xml" "$KADDON/icon.png" "$ADDON/"
  cp "$SRC/LICENSE" "$ADDON/LICENSE"
  cp $K/cross/cmake/pillow/NOTICE.txt "$ADDON/NOTICE.txt"
  echo "[pil-$V] DONE $(date '+%T'): $(find "$ADDON" -name '*.pyd' | wc -l) C modules, $(find "$ADDON" -name '*.py' | wc -l) .py files"
} > "$LOG" 2>&1
rc=$?
tail -2 "$LOG"
echo "[pil-$V] warnings: $(grep -c 'warning:' "$LOG"), errors: $(grep -c ' error' "$LOG")"
exit $rc
