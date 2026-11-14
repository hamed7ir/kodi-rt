#!/bin/bash
# kodi-rt Python stage: assemble the device kit kit/kodi-rt-python-run1 and zip it into C:\handoff.
#   kit/<KNAME>/{run-python.cmd,run-python-dbgrun.cmd,README.txt} are written by hand. This adds python\ (python.exe,
#   python314.dll and the full Lib\ with its tests, from prefix/arm32/python; no headers, libs or pdb), tests\ (the smoke
#   test and the regrtest list), bin\dbgrun.exe and MANIFEST.txt, converts the kit's own .cmd/.txt files to CRLF, zips.
# Usage (Git Bash): bash scripts/py-package-kit.sh [--dryrun-x64]
#   --dryrun-x64: build build/py/kit-dryrun/<KNAME> with the x64 reference interpreter and the x64 dbgrun instead,
#   to run the kit's scripts on this server.
set -u
KNAME=${KNAME:-kodi-rt-python-run1}; ZNAME=${ZNAME:-kodi-rt-python-run1-20261113}
K=/f/kodi-rt
KSRC=$K/kit/$KNAME
DRY=""
[ "${1:-}" = --dryrun-x64 ] && DRY=1
if [ -n "$DRY" ]; then KD=$K/build/py/kit-dryrun/$KNAME; PYSRC=$K/build/py/x64-install; DBG=$K/tools/dbgrun/x64/dbgrun.exe
else KD=$KSRC; PYSRC=$K/prefix/arm32/python; DBG=$K/tools/dbgrun/arm32/dbgrun.exe; fi
mkdir -p "$KD"
[ "$KD" != "$KSRC" ] && cp "$KSRC/run-python.cmd" "$KSRC/run-python-dbgrun.cmd" "$KSRC/README.txt" "$KD/"
rm -rf "$KD/python" "$KD/tests" "$KD/bin" "$KD/MANIFEST.txt" "$KD"/results*
mkdir -p "$KD/python" "$KD/tests" "$KD/bin"
cp "$PYSRC/python.exe" "$PYSRC/python314.dll" "$KD/python/" || exit 1
cp -r "$PYSRC/Lib" "$KD/python/" || exit 1
mkdir -p "$KD/python/DLLs"
find "$KD/python/Lib" -name __pycache__ -prune -exec rm -rf {} +
cp $K/tests/python/kodirt_smoke.py $K/tests/python/regrtest-device.txt "$KD/tests/" || exit 1
cp "$DBG" "$KD/bin/dbgrun.exe" || exit 1
if [ -z "$DRY" ]; then
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$KD/python/python.exe")" \
    "$(cygpath -m "$KD/python/python314.dll")" "$(cygpath -m "$KD/bin/dbgrun.exe")" || { echo "not all ARM32"; exit 1; }
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
