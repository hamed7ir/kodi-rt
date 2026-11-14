#!/bin/bash
# kodi-rt: the ARM32 release kit folder kit/kodi-rt-v1.0-arm32/kodi (the installer's arm32 payload; the folder kept
# its v1.0 name, the setup carries the version): the PGO kit's
# kodi folder (kit/kodi-rt-stage6-pgo/kodi: Kodi's data, Python, presets) with
#   kodi.exe          the PGO + ThinLTO build from build/s7/kodi-build-pgo, relinked with the purple icon; it must have
#                     passed the ARM32 gate (GATELOG=logs/s8-gate-arm32.log bash scripts/s4-gate.sh build/s7/kodi-build-pgo: PASS)
#   addons, media,    Kodi's data from the same build tree (the skin's XML and Textures.xbt, media/splash.jpg =
#   system, userdata  branding/splash.jpg); system/python and the presets stay the base kit's
#   python314.dll     prefix/arm32/python (the Python stage: with _ctypes since 2026-11-14; check 9 of the same gate)
#   script.module.pycryptodome, script.module.pil   prefix/arm32/kodi-addons (the Python stage: pycryptodome's 40
#                     ARM32 C modules, Pillow's 4 with libjpeg-turbo/FreeType) in place of Kodi's empty stubs
# Checks: ARMNT (programs and the C modules), the gate log names this exe and this python314.dll, the kit's
# Lib/ctypes is the Python stage's, MANIFEST.txt with sha256 of every file.
# Usage (Git Bash): bash scripts/s8-package-release-arm32.sh
set -u
W=/f/kodi-rt
B=$W/kit/kodi-rt-stage6-pgo/kodi
K=$W/kit/kodi-rt-v1.0-arm32
EXE=$W/build/s7/kodi-build-pgo/kodi.exe
PYD=$W/prefix/arm32/python/python314.dll
ADDONS=$W/prefix/arm32/kodi-addons   # script.module.pycryptodome, script.module.pil (the Python stage)
GATE=$W/logs/s8-gate-arm32.log   # GATELOG=logs/s8-gate-arm32.log bash scripts/s4-gate.sh build/s7/kodi-build-pgo
tail -1 "$GATE" | grep -q "S4 GATE (server): PASS" || { echo "the ARM32 gate log does not end with PASS ($GATE)"; exit 1; }
grep -q "$(sha256sum "$EXE" | cut -d' ' -f1)" "$GATE" || { echo "the gate log is not for this kodi.exe"; exit 1; }
grep -q "$(sha256sum "$PYD" | cut -d' ' -f1)" "$GATE" || { echo "the gate log is not for this python314.dll (check 9)"; exit 1; }
[ -f "$ADDONS/script.module.pycryptodome/lib/Cryptodome/__init__.py" ] || { echo "no pycryptodome in $ADDONS"; exit 1; }
[ -f "$ADDONS/script.module.pil/lib/PIL/__init__.py" ] || { echo "no Pillow in $ADDONS"; exit 1; }
rm -rf "$K"; mkdir -p "$K" || exit 1
cp -r "$B" "$K/" || exit 1
rm -rf "$K/kodi/portable_data"
# Kodi's own data from the build tree (skin XML, Textures.xbt, splash: changed since the PGO kit); Python's
# system/python and the presets come from the base kit
BD=$W/build/s7/kodi-build-pgo
for d in addons media userdata; do rm -rf "$K/kodi/$d" && cp -r "$BD/$d" "$K/kodi/" || exit 1; done
( cd "$BD/system" && find . -type f ) | while read -r f; do mkdir -p "$K/kodi/system/$(dirname "$f")" && cp -f "$BD/system/$f" "$K/kodi/system/$f"; done
cp -f "$EXE" "$K/kodi/kodi.exe" || exit 1
# Python with _ctypes, and the real pycryptodome and Pillow over Kodi's stubs (addon.xml + icon only)
cp -f "$PYD" "$K/kodi/python314.dll" || exit 1
for a in script.module.pycryptodome script.module.pil; do rm -rf "$K/kodi/addons/$a" && cp -r "$ADDONS/$a" "$K/kodi/addons/" || exit 1; done
d=$(diff -rq -x __pycache__ "$K/kodi/system/python/Lib/ctypes" "$W/prefix/arm32/python/Lib/ctypes" 2>&1)
[ -z "$d" ] || { echo "the base kit's Lib/ctypes differs from the Python stage's:"; echo "$d" | head; exit 1; }
cmp -s "$K/kodi/media/splash.jpg" "$W/branding/splash.jpg" || { echo "the build tree's splash.jpg is not branding/splash.jpg"; exit 1; }
n1=$(find "$K/kodi/addons/script.module.pycryptodome" -name '*.pyd' | wc -l); n2=$(find "$K/kodi/addons/script.module.pil" -name '*.pyd' | wc -l)
[ "$n1" -ge 40 ] && [ "$n2" -ge 4 ] || { echo "C modules: pycryptodome $n1, Pillow $n2"; exit 1; }
mapfile -t mods < <(find "$K/kodi/addons/script.module.pycryptodome" "$K/kodi/addons/script.module.pil" -name '*.pyd' | while read -r f; do cygpath -m "$f"; done)
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/kodi/kodi.exe")" "$(cygpath -m "$K/kodi/dvdnav.dll")" \
  "$(cygpath -m "$K/kodi/python314.dll")" "${mods[@]}" > /dev/null || { echo "not all ARM32"; exit 1; }
echo "ARM32: kodi.exe, dvdnav.dll, python314.dll and ${#mods[@]} C modules (pycryptodome $n1, Pillow $n2)"
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1)); kodi.exe sha256 $(sha256sum "$K/kodi/kodi.exe" | cut -c1-16)..."
echo "PACKAGE DONE"
