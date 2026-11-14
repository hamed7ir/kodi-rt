#!/bin/bash
# kodi-rt: pycryptodome 3.23.0 (Kodi's pin) as Kodi's script.module.pycryptodome, per architecture:
#   - the Cryptodome package: lib/Crypto renamed to the separate namespace by scripts/pycd-rename.py (what setup.py
#     does when .separate_namespace exists, as Kodi's tools/depends build makes it). Kodi's depends patch
#     01-revert-ctype.pythonapi-use.patch is NOT applied: it is for Linux/Android, where ctypes.pythonapi (dlopen of
#     the main program) does not reach Python's symbols; on Windows ctypes.pythonapi is python314.dll (sys.dllhandle),
#     and the patch would only drop memoryview support (29 of pycryptodome's self-test files use memoryviews).
#     Kodi's own Windows builds take pycryptodome from separate prebuilt packages, not from tools/depends.
#   - its C modules: cross/cmake/pycryptodome (clang-cl /MT; 42 on x86/x64, 40 on ARM32), into lib/Cryptodome/...
#   - Kodi's addon.xml + icon.png (src/xbmc/addons/script.module.pycryptodome) and pycryptodome's LICENSE.rst
# Result: prefix/<arch>/kodi-addons/script.module.pycryptodome (drop-in for the kit's addons/ folder).
# Usage (Git Bash): bash scripts/pycd-build.sh <arm32|x64|x86>     Log: logs/pycd-<arch>.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
K=F:/kodi-rt
V=${1:-}
case $V in arm32|x64|x86) TC=$K/cross/$V-rt24.cmake ;; *) echo "usage: pycd-build.sh <arm32|x64|x86>"; exit 2 ;; esac
SRC=$K/src/deps/pycryptodome-3.23.0
KADDON=$K/src/xbmc/addons/script.module.pycryptodome
BD=/f/kodi-rt/build/pycd/$V
ADDON=/f/kodi-rt/prefix/$V/kodi-addons/script.module.pycryptodome
LOG=/f/kodi-rt/logs/pycd-$V.log
{
  set -e
  echo "[pycd-$V] $(date '+%F %T') start"
  rm -rf "$BD" "$ADDON"
  mkdir -p "$BD" "$ADDON/lib"
  python -I $K/scripts/pycd-rename.py "$SRC/lib/Crypto" "$(cygpath -m "$ADDON")/lib/Cryptodome"
  "$CMAKE" -G Ninja -S $K/cross/cmake/pycryptodome -B "$(cygpath -m "$BD")/build" -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=$TC -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DPYCD_SRC=$SRC \
    -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$ADDON")/lib"
  "$CMAKE" --build "$(cygpath -m "$BD")/build" -- -j 8
  "$CMAKE" --install "$(cygpath -m "$BD")/build"
  cp "$KADDON/addon.xml" "$KADDON/icon.png" "$ADDON/"
  cp "$SRC/LICENSE.rst" "$ADDON/LICENSE.rst"
  echo "[pycd-$V] DONE $(date '+%T'): $(find "$ADDON" -name '*.pyd' | wc -l) C modules, $(find "$ADDON" -name '*.py' | wc -l) .py files"
} > "$LOG" 2>&1
rc=$?
tail -2 "$LOG"
echo "[pycd-$V] warnings: $(grep -c 'warning:' "$LOG"), errors: $(grep -c 'error' "$LOG")"
exit $rc
