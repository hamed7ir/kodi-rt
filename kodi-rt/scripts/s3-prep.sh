#!/bin/bash
# kodi-rt Stage 3: make a patched copy of an extracted source tree, applying Kodi's patches in the order given
# (the order Kodi's Find module lists them). src/deps/<dir> stays pristine; the copy is $A_B3/src/<name>
# (cross/arch.sh; arm32: build/s3/src/<name>, x64: build/s3-x64/src/<name>).
# Usage (Git Bash): bash scripts/s3-prep.sh <name> <source dir> [patch file ...]
set -u
source /f/kodi-rt/cross/arch.sh
NAME=$1; SRC=$2; shift 2
D=$A_B3/src/$NAME
rm -rf "$D"; mkdir -p "$(dirname "$D")"; cp -r "$SRC" "$D" || exit 1
for p in "$@"; do
  out=$(patch -p1 -d "$D" -i "$p" -N -r - 2>&1); rc=$?
  echo "== $(basename "$p")"; echo "$out" | grep -E 'Hunk|FAILED|reject|Reversed|offset|fuzz' | sed 's/^/   /' | head -10
  [ $rc -eq 0 ] || { echo "$out" | tail -5; echo "PATCH FAILED: $(basename "$p")"; exit 1; }
  echo "$out" | grep -qiE 'FAILED|reject|Reversed' && { echo "PATCH NOT CLEAN: $(basename "$p")"; exit 1; }
done
echo "prepared $D ($# patches)"
