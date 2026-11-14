#!/bin/bash
# kodi-rt PGO phase 1: the PROFILING kit (kit/kodi-rt-pgo-profile), a full kit for a new folder: the stage 6 full kit's
# kodi\ folder (data, Python, presets) and bin\dbgrun.exe (not rtprof), the GATED instrumented kodi.exe
# (results/s7-instr/bin, scripts/s4-gate.sh build/s7/kodi-build-instr), and the hand-written run-kodi.cmd,
# run-kodi-dbgrun.cmd and README.txt in kit/kodi-rt-pgo-profile. Checks the base kit against its MANIFEST and the
# gated exe against its SHA256SUMS first. Text files get CRLF; MANIFEST.txt; zip into C:\handoff.
# Dry run of the scripts: scripts/s7-dryrun-pgo.ps1.
# Usage (Git Bash): bash scripts/s7-package-pgo-kit.sh
set -u
BASE=${BASE:-kodi-rt-stage6-full}; KNAME=${KNAME:-kodi-rt-pgo-profile}; ZNAME=${ZNAME:-kodi-rt-pgo-profile-20261113}
GATED=${GATED:-/f/kodi-rt/results/s7-instr/bin}
B=/f/kodi-rt/kit/$BASE
K=/f/kodi-rt/kit/$KNAME
( cd "$GATED" && sha256sum -c --quiet SHA256SUMS.txt ) || { echo "$GATED does not match its SHA256SUMS"; exit 1; }
cmp -s "$GATED/kodi.exe" /f/kodi-rt/build/s7/kodi-build-instr/kodi.exe || { echo "the gated exe is not the build's"; exit 1; }
( cd "$B" && tr -d '\r' < MANIFEST.txt | sha256sum -c --quiet - ) || { echo "$B does not match its MANIFEST.txt"; exit 1; }
n_manifest=$(tr -d '\r' < "$B/MANIFEST.txt" | grep -c .)
n_files=$(cd "$B" && find . -type f ! -name MANIFEST.txt | wc -l)
[ "$n_manifest" = "$n_files" ] || { echo "$B has $n_files files, its MANIFEST lists $n_manifest"; exit 1; }
for f in run-kodi.cmd run-kodi-dbgrun.cmd README.txt; do [ -f "$K/$f" ] || { echo "missing $K/$f"; exit 1; }; done
rm -rf "$K/kodi" "$K/bin" "$K/MANIFEST.txt" "$K/prof" "$K"/results*
mkdir -p "$K/bin"
cp -r "$B/kodi" "$K/" || exit 1
cp "$B/bin/dbgrun.exe" "$K/bin/" || exit 1
cp "$GATED/kodi.exe" "$K/kodi/kodi.exe" || exit 1
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/kodi/kodi.exe")" \
  "$(cygpath -m "$K/kodi/dvdnav.dll")" "$(cygpath -m "$K/kodi/python314.dll")" "$(cygpath -m "$K/bin/dbgrun.exe")" \
  || { echo "not all ARM32"; exit 1; }
# the instrumented exe: profile sections present
F:/kodi-rt/tc/rt24c-cr/bin/llvm-objdump.exe -h "$(cygpath -m "$K/kodi/kodi.exe")" | grep -q '\.lprfc' \
  || { echo "kodi.exe has no profile counters"; exit 1; }
for f in run-kodi.cmd run-kodi-dbgrun.cmd README.txt; do
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
