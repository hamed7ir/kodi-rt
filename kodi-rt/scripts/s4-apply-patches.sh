#!/bin/bash
# kodi-rt Stage 4: a fresh, patched Kodi tree for the ARM32 build (the adb-rt pattern: numbered patches in
# F:/kodi-rt/patches applied by script, sources never edited in place).
#   1. git clone of src/xbmc (bffa625c) into build/s4/kodi (a clone, not cp: the tree has symlinks)
#   2. git apply patches/[0-9][0-9][0-9][0-9]-*.patch in order (each checked first)
#   3. host tools where Kodi looks for them under Ninja (recon row 14):
#      project/BuildDependencies/tools/tools/TexturePacker/  <- Kodi's prebuilt TexturePacker-win32-v141-20200105.7z
#      project/BuildDependencies/tools/share/Toolchain-Native.cmake <- cross/x64-host-rt24.cmake
#      project/BuildDependencies/tools/bin/pkgconf.exe <- scripts/s4-host-pkgconf.sh (Kodi's pkgconf pin, x64)
# Usage (Git Bash): bash scripts/s4-apply-patches.sh
set -u
cd /f/kodi-rt || exit 1
K=build/s4/kodi
[ "$(git -C src/xbmc rev-parse HEAD)" = bffa625cc84860f241772d87a654844b98bebb60 ] || { echo "src/xbmc is not at the pinned commit"; exit 1; }
[ -z "$(git -C src/xbmc status --porcelain)" ] || { echo "src/xbmc has local changes"; exit 1; }
rm -rf "$K"
[ -e "$K" ] && { echo "could not remove $K (is a shell's cwd inside it?)"; exit 1; }
git clone -q --no-hardlinks src/xbmc "$K" || exit 1
n=0
for p in patches/[0-9][0-9][0-9][0-9]-*.patch; do
  git -C "$K" apply --check "../../../$p" || { echo "PATCH DOES NOT APPLY: $p"; exit 1; }
  git -C "$K" apply "../../../$p" || { echo "PATCH FAILED: $p"; exit 1; }
  echo "applied $p"; n=$((n+1))
done
N=$K/project/BuildDependencies/tools
mkdir -p "$N/share" "$N/tools"
T=$(mktemp -d)
"/c/Program Files/7-Zip/7z.exe" x -o"$(cygpath -w "$T")" downloads/hosttools/TexturePacker-win32-v141-20200105.7z > /dev/null || exit 1
cp -r "$T"/TexturePacker-win32-v141-20200105/tools/TexturePacker "$N/tools/" && rm -rf "$T"
cp cross/x64-host-rt24.cmake "$N/share/Toolchain-Native.cmake"
ls -la "$N/tools/TexturePacker/" "$N/share/" | grep -E 'TexturePacker.exe|Toolchain-Native'
out=$(bash scripts/s4-host-pkgconf.sh) || { echo "$out"; exit 1; }
echo "$out" | tail -2
echo "$n patches applied; tree: $K ($(git -C "$K" diff --stat | tail -1))"
echo "APPLY DONE"
