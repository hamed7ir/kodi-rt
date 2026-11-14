#!/bin/bash
# kodi-rt Stage 9: the x64 or x86 kit folder kit/kodi-rt-s9-<arch>/kodi, the installer's payload
# (installer/build-installer.ps1 -Flavor <arch>), the same layout as the ARM32 release kit's kodi folder
# (kit/kodi-rt-v1.0-arm32/kodi):
#   addons, media, system, userdata   Kodi's data from the build tree build/s9/kodi-build-<arch> (checked: equal to the
#                                     ARM32 kit's, same source and options), Textures.xbt included
#   system/python, python314._pth     Python's standard library from the ARM32 kit (pure Python, the same 3.14.10)
#   kodi.exe                          the build's (scripts/s9-build.sh)
#   dvdnav.dll                        prefix/<arch>/bin (scripts/s3-libdvd.sh)
#   python314.dll                     prefix/<arch>/python (the Python stage, with _ctypes), when Kodi was built with Python
#   script.module.pycryptodome, .pil  prefix/<arch>/kodi-addons (the Python stage: this arch's C modules) in place
#                                     of the build tree's empty stubs, with Python
# Checks: machine type of every program and C module (x64 0x8664, x86 0x14c), the data comparison (without
# pycryptodome and Pillow, which are per arch, and the ARM32-only binary add-ons), Python on/off matching the
# build. No portable_data (the installer leaves it out anyway). MANIFEST.txt with sha256 of every file.
# Usage (Git Bash): bash scripts/s9-package-kit.sh x64
set -u
A=${1:?usage: s9-package-kit.sh x64|x86}
case $A in x64) M=0x8664 ;; x86) M=0x14c ;; *) echo "arch must be x64 or x86"; exit 1 ;; esac
BD=/f/kodi-rt/build/s9/kodi-build-$A
ARMK=/f/kodi-rt/kit/kodi-rt-v1.0-arm32/kodi   # the ARM32 release kit (scripts/s8-package-release-arm32.sh)
PFX=/f/kodi-rt/prefix/$A
K=/f/kodi-rt/kit/kodi-rt-s9-$A
[ -f "$BD/kodi.exe" ] || { echo "no $BD/kodi.exe (scripts/s9-build.sh $A)"; exit 1; }
[ -f "$PFX/bin/dvdnav.dll" ] || { echo "no $PFX/bin/dvdnav.dll"; exit 1; }
py=$(grep -E '^ENABLE_PYTHON:' "$BD/CMakeCache.txt" | cut -d= -f2)
rm -rf "$K"; mkdir -p "$K/kodi" || exit 1
for d in addons media system userdata; do cp -r "$BD/$d" "$K/kodi/" || exit 1; done
# the build tree's data against the ARM32 kit's (system/python is Python's, portable_data the kit's own)
d=$(diff -rq -x python "$K/kodi/system" "$ARMK/system" 2>&1; for x in addons media userdata; do diff -rq -x script.module.pycryptodome -x script.module.pil -x inputstream.adaptive -x inputstream.ffmpegdirect -x inputstream.rtmp -x pvr.iptvsimple -x vfs.libarchive -x vfs.rar "$K/kodi/$x" "$ARMK/$x" 2>&1; done)
if [ -n "$d" ]; then echo "DATA DIFFERS FROM THE ARM32 KIT:"; echo "$d" | head -20; exit 1; fi
cp "$BD/kodi.exe" "$PFX/bin/dvdnav.dll" "$K/kodi/" || exit 1
progs=("$K/kodi/kodi.exe" "$K/kodi/dvdnav.dll")
if [ "$py" = ON ]; then
  [ -f "$PFX/python/python314.dll" ] || { echo "Kodi was built with Python but there is no $PFX/python/python314.dll"; exit 1; }
  cp "$PFX/python/python314.dll" "$ARMK/python314._pth" "$K/kodi/" || exit 1
  cp -r "$ARMK/system/python" "$K/kodi/system/" || exit 1
  progs+=("$K/kodi/python314.dll")
  ADDONS=$PFX/kodi-addons
  [ -f "$ADDONS/script.module.pycryptodome/lib/Cryptodome/__init__.py" ] || { echo "no pycryptodome in $ADDONS"; exit 1; }
  [ -f "$ADDONS/script.module.pil/lib/PIL/__init__.py" ] || { echo "no Pillow in $ADDONS"; exit 1; }
  for a in script.module.pycryptodome script.module.pil; do rm -rf "$K/kodi/addons/$a" && cp -r "$ADDONS/$a" "$K/kodi/addons/" || exit 1; done
  n1=$(find "$K/kodi/addons/script.module.pycryptodome" -name '*.pyd' | wc -l); n2=$(find "$K/kodi/addons/script.module.pil" -name '*.pyd' | wc -l)
  [ "$n1" -ge 40 ] && [ "$n2" -ge 4 ] || { echo "C modules: pycryptodome $n1, Pillow $n2"; exit 1; }
  mapfile -t mods < <(find "$K/kodi/addons/script.module.pycryptodome" "$K/kodi/addons/script.module.pil" -name '*.pyd')
  progs+=("${mods[@]}")
else
  echo "NOTE: Kodi was built WITHOUT Python (ENABLE_PYTHON=$py): no python314.dll in the kit"
fi
args=(); for p in "${progs[@]}"; do args+=("$(cygpath -m "$p")"); done
python -I F:/kodi-rt/scripts/check-machine.py --want=$M "${args[@]}" > /dev/null || { echo "not all $A"; exit 1; }
echo "$A: ${#progs[@]} programs and C modules, all machine $M"
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1)); kodi.exe sha256 $(sha256sum "$K/kodi/kodi.exe" | cut -c1-16)..."
echo "PACKAGE DONE"
