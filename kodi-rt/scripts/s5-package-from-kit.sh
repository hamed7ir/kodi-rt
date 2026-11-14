#!/bin/bash
# kodi-rt Stage 5: a FULL kit made from an earlier full kit (its kodi\ data folders and bin\), a newer GATED kodi.exe,
#   kit/portable-data/advancedsettings.xml, and the hand-written files in kit/$KNAME (run scripts, README). For builds
#   whose data folders did not change (C++-only patches since the base kit), without the build tree. Checks the base
#   kit against its MANIFEST first. Text files get CRLF; MANIFEST.txt; zip into C:\handoff.
# Usage (Git Bash):
#   BASE=kodi-rt-stage5-run4 KNAME=kodi-rt-stage5-run6 ZNAME=kodi-rt-stage5-run6-20261113 \
#   GATED=/f/kodi-rt/results/stage5-kit6/bin bash scripts/s5-package-from-kit.sh
set -u
BASE=${BASE:?set BASE}; KNAME=${KNAME:?set KNAME}; ZNAME=${ZNAME:?set ZNAME}; GATED=${GATED:?set GATED}
B=/f/kodi-rt/kit/$BASE
K=/f/kodi-rt/kit/$KNAME
( cd "$GATED" && sha256sum -c --quiet SHA256SUMS.txt ) || { echo "$GATED does not match its SHA256SUMS"; exit 1; }
( cd "$B" && tr -d '\r' < MANIFEST.txt | sha256sum -c --quiet - ) || { echo "$B does not match its MANIFEST.txt"; exit 1; }
n_manifest=$(tr -d '\r' < "$B/MANIFEST.txt" | grep -c .)
n_files=$(cd "$B" && find . -type f ! -name MANIFEST.txt | wc -l)
[ "$n_manifest" = "$n_files" ] || { echo "$B has $n_files files, its MANIFEST lists $n_manifest"; exit 1; }
for f in run-kodi.cmd run-kodi-dbgrun.cmd README.txt; do [ -f "$K/$f" ] || { echo "missing $K/$f"; exit 1; }; done
rm -rf "$K/kodi" "$K/bin" "$K/MANIFEST.txt"
cp -r "$B/kodi" "$B/bin" "$K/" || exit 1
cp "$GATED/kodi.exe" "$K/kodi/kodi.exe" || exit 1
cp /f/kodi-rt/kit/portable-data/advancedsettings.xml "$K/kodi/portable_data/userdata/advancedsettings.xml" || exit 1
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/kodi/kodi.exe")" \
  "$(cygpath -m "$K/kodi/dvdnav.dll")" "$(cygpath -m "$K/bin/dbgrun.exe")" || { echo "not all ARM32"; exit 1; }
for f in run-kodi.cmd run-kodi-dbgrun.cmd README.txt kodi/portable_data/userdata/advancedsettings.xml; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/$f")"
  python -I -c "import sys; d=open(sys.argv[1],'rb').read(); c=d.count(b'\r\n'); n=d.count(b'\n'); print(sys.argv[1].split('/')[-1], 'CRLF', c, 'of', n, 'lines'); sys.exit(0 if c==n and n>0 else 1)" "$(cygpath -m "$K/$f")" || { echo "CRLF conversion failed"; exit 1; }
done
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1))"
Z=C:/handoff/$ZNAME.zip
[ -e "$Z" ] && { echo "$Z exists already; not overwriting"; exit 1; }
( cd /f/kodi-rt/kit && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=9 "$Z" "$KNAME" > /dev/null ) || { echo "zip failed"; exit 1; }
( cd /c/handoff && sha256sum "$ZNAME.zip" > "$ZNAME.zip.sha256" )
ls -la "/c/handoff/$ZNAME.zip"*; cat "/c/handoff/$ZNAME.zip.sha256"
echo "PACKAGE DONE"
