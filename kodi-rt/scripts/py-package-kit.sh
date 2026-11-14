#!/bin/bash
# kodi-rt Python stage: assemble a Python device kit (default kit/kodi-rt-python-run3) and zip it into C:\handoff.
#   kit/<KNAME>/{run-python.cmd,run-python-dbgrun.cmd,README.txt} are written by hand. This adds python\ (python.exe,
#   python314.dll, the full Lib\ with its tests and DLLs\ = _ctypes_test.pyd, from prefix/arm32/python; no headers,
#   libs or pdb), script.module.pycryptodome\ and script.module.pil\ (prefix/arm32/kodi-addons: scripts/pycd-build.sh,
#   scripts/pil-build.sh), tests\ (smoke, pycryptodome and Pillow tests, tests\pil-assets, regrtest list),
#   bin\dbgrun.exe and MANIFEST.txt, converts the kit's own .cmd/.txt files to CRLF, zips.
#   (Run 1, 2026-11-13, had no DLLs and no add-ons; run 2 had no Pillow.)
# Usage (Git Bash): [KNAME=... ZNAME=...] bash scripts/py-package-kit.sh [--dryrun-x64]
#   --dryrun-x64: build build/py/kit-dryrun/<KNAME> from the desktop x64 build (prefix/x64/python, prefix/x64/kodi-addons)
#   and the x64 dbgrun instead, to run the kit's scripts on this server.
set -u
KNAME=${KNAME:-kodi-rt-python-run3}; ZNAME=${ZNAME:-kodi-rt-python-run3-20261114}
K=/f/kodi-rt
KSRC=$K/kit/$KNAME
DRY=""
[ "${1:-}" = --dryrun-x64 ] && DRY=1
if [ -n "$DRY" ]; then KD=$K/build/py/kit-dryrun/$KNAME; A=x64; DBG=$K/tools/dbgrun/x64/dbgrun.exe
else KD=$KSRC; A=arm32; DBG=$K/tools/dbgrun/arm32/dbgrun.exe; fi
PYSRC=$K/prefix/$A/python
ADDON=$K/prefix/$A/kodi-addons/script.module.pycryptodome
PILADDON=$K/prefix/$A/kodi-addons/script.module.pil
[ -f "$PYSRC/DLLs/_ctypes_test.pyd" ] || { echo "no $PYSRC/DLLs/_ctypes_test.pyd (a Python built with ctypes)"; exit 1; }
[ -d "$ADDON/lib/Cryptodome" ] || { echo "no $ADDON (scripts/pycd-build.sh $A)"; exit 1; }
[ -f "$PILADDON/lib/PIL/_imaging.pyd" ] || { echo "no $PILADDON (scripts/pil-build.sh $A)"; exit 1; }
mkdir -p "$KD"
[ "$KD" != "$KSRC" ] && cp "$KSRC/run-python.cmd" "$KSRC/run-python-dbgrun.cmd" "$KSRC/README.txt" "$KD/"
rm -rf "$KD/python" "$KD/script.module.pycryptodome" "$KD/script.module.pil" "$KD/tests" "$KD/bin" "$KD/MANIFEST.txt" "$KD"/results*
mkdir -p "$KD/python" "$KD/tests" "$KD/bin"
cp "$PYSRC/python.exe" "$PYSRC/python314.dll" "$KD/python/" || exit 1
cp -r "$PYSRC/Lib" "$PYSRC/DLLs" "$KD/python/" || exit 1
cp -r "$ADDON" "$PILADDON" "$KD/" || exit 1
find "$KD/python/Lib" "$KD/script.module.pycryptodome" "$KD/script.module.pil" -name __pycache__ -prune -exec rm -rf {} +
cp $K/tests/python/kodirt_smoke.py $K/tests/python/kodirt_crypto.py $K/tests/python/kodirt_pil.py \
   $K/tests/python/regrtest-device.txt "$KD/tests/" || exit 1
cp -r $K/tests/python/pil-assets "$KD/tests/" || exit 1
cp "$DBG" "$KD/bin/dbgrun.exe" || exit 1
if [ -z "$DRY" ]; then
  mapfile -t bins < <(find "$KD/python" "$KD/script.module.pycryptodome" "$KD/script.module.pil" "$KD/bin" -name '*.exe' -o -name '*.dll' -o -name '*.pyd' | while read -r f; do cygpath -m "$f"; done)
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "${bins[@]}" > "$K/logs/py-kit-machine.txt" \
    || { grep -v "^OK" "$K/logs/py-kit-machine.txt"; echo "not all ARM32"; exit 1; }
  echo "ARM32: ${#bins[@]} binaries"
fi
for f in run-python.cmd run-python-dbgrun.cmd README.txt tests/regrtest-device.txt; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$KD/$f")"
done
( cd "$KD" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$KD/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$KD/MANIFEST.txt")"
echo "kit: $KD ($(find "$KD" -type f | wc -l) files, $(du -sh "$KD" | cut -f1))"
if [ -z "$DRY" ]; then
  Z=C:/handoff/$ZNAME.zip
  [ -e "$Z" ] && { echo "$Z exists already; not overwriting"; exit 1; }
  ( cd $K/kit && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=9 "$Z" "$KNAME" > /dev/null ) || { echo "zip failed"; exit 1; }
  ( cd /c/handoff && sha256sum "$ZNAME.zip" > "$ZNAME.zip.sha256" )
  ls -la "/c/handoff/$ZNAME.zip"*; cat "/c/handoff/$ZNAME.zip.sha256"
fi
echo "PACKAGE DONE"
