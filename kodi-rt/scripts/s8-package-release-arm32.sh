#!/bin/bash
# kodi-rt v1.0: the ARM32 release kit folder kit/kodi-rt-v1.0-arm32/kodi (the installer's arm32 payload): the PGO kit's
# kodi folder (kit/kodi-rt-stage6-pgo/kodi: Kodi's data, Python, presets) with
#   kodi.exe          the PGO + ThinLTO build from build/s7/kodi-build-pgo, relinked with the purple icon; it must have
#                     passed the ARM32 gate (GATELOG=logs/s8-gate-arm32.log bash scripts/s4-gate.sh build/s7/kodi-build-pgo: PASS)
#   media/splash.jpg  branding/splash.jpg (the banner says "v. 23.0 - ALPHA 1")
# Checks: ARMNT, the gate log names this exe, MANIFEST.txt with sha256 of every file.
# Usage (Git Bash): bash scripts/s8-package-release-arm32.sh
set -u
W=/f/kodi-rt
B=$W/kit/kodi-rt-stage6-pgo/kodi
K=$W/kit/kodi-rt-v1.0-arm32
EXE=$W/build/s7/kodi-build-pgo/kodi.exe
GATE=$W/logs/s8-gate-arm32.log   # GATELOG=logs/s8-gate-arm32.log bash scripts/s4-gate.sh build/s7/kodi-build-pgo
tail -1 "$GATE" | grep -q "S4 GATE (server): PASS" || { echo "the ARM32 gate log does not end with PASS ($GATE)"; exit 1; }
grep -q "$(sha256sum "$EXE" | cut -d' ' -f1)" "$GATE" || { echo "the gate log is not for this kodi.exe"; exit 1; }
rm -rf "$K"; mkdir -p "$K" || exit 1
cp -r "$B" "$K/" || exit 1
rm -rf "$K/kodi/portable_data"
cp -f "$EXE" "$K/kodi/kodi.exe" && cp -f "$W/branding/splash.jpg" "$K/kodi/media/splash.jpg" || exit 1
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/kodi/kodi.exe")" "$(cygpath -m "$K/kodi/dvdnav.dll")" \
  "$(cygpath -m "$K/kodi/python314.dll")" || { echo "not all ARM32"; exit 1; }
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1)); kodi.exe sha256 $(sha256sum "$K/kodi/kodi.exe" | cut -c1-16)..."
echo "PACKAGE DONE"
