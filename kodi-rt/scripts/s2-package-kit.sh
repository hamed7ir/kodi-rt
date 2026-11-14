#!/bin/bash
# kodi-rt Stage 2: assemble the device kit (kit/kodi-rt-stage2) and zip it into C:\handoff.
#   kit/kodi-rt-stage2/{run-stage2.cmd,README.txt} are written by hand; this adds bin/, clips/, expected/, MANIFEST.txt,
#   converts the .cmd/.txt to CRLF, and zips. Symbols stay in build/s2/kit-symbols/ (never shipped).
# Usage (Git Bash): bash scripts/s2-package-kit.sh [--dryrun-x64 [--fail]]
#   --dryrun-x64: build build/s2/kit-dryrun/kodi-rt-stage2 instead, with x64 stand-ins (the x64 reference h264md5,
#   stub checkasm programs that exit 0, or 1 with --fail, and the x64 dbgrun), to test run-stage2.cmd on this server.
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24b-cr/bin
MODE=""; FAILSTUB=0
for a in "$@"; do case $a in --dryrun-x64) MODE=dryrun ;; --fail) FAILSTUB=1 ;; *) echo "unknown argument $a"; exit 2 ;; esac; done
KNAME=kodi-rt-stage2; ZNAME=kodi-rt-stage2-20261112
KSRC=/f/kodi-rt/kit/$KNAME
if [ "$MODE" = dryrun ]; then K=/f/kodi-rt/build/s2/kit-dryrun/$KNAME; else K=$KSRC; fi
mkdir -p "$K"
[ "$K" != "$KSRC" ] && cp "$KSRC/run-stage2.cmd" "$KSRC/README.txt" "$K/"
rm -rf "$K/bin" "$K/clips" "$K/expected" "$K/MANIFEST.txt" "$K"/results*
mkdir -p "$K/bin" "$K/clips" "$K/expected"

if [ "$MODE" = dryrun ]; then
  cp /f/kodi-rt/build/s2/ffmpeg-x64ref/h264md5/h264md5.exe "$K/bin/h264md5.exe"
  S=/f/kodi-rt/build/s2/kit-dryrun/stub; mkdir -p "$S"
  printf 'int main(void){return %d;}\n' $FAILSTUB > "$S/stub.c"
  "$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo "$(cygpath -m "$S/stub.c")" "-Fe$(cygpath -m "$S/stub.exe")" \
    "-Fo$(cygpath -m "$S/stub.obj")" -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp > "$S/build.log" 2>&1 || { cat "$S/build.log"; exit 1; }
  cp "$S/stub.exe" "$K/bin/ffmpeg-checkasm.exe"; cp "$S/stub.exe" "$K/bin/dav1d-checkasm.exe"
  cp /f/kodi-rt/tools/dbgrun/x64/dbgrun.exe "$K/bin/dbgrun.exe"
else
  cp /f/kodi-rt/build/s2/h264md5-arm32/h264md5.exe "$K/bin/h264md5.exe"
  cp /f/kodi-rt/build/s2/ffmpeg-arm32/tests/checkasm/checkasm.exe "$K/bin/ffmpeg-checkasm.exe"
  cp /f/kodi-rt/build/s2/dav1d-arm32/tests/checkasm.exe "$K/bin/dav1d-checkasm.exe"
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.exe "$K/bin/dbgrun.exe"
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/bin")"/*.exe || { echo "a kit binary is not ARM32"; exit 1; }
  SY=/f/kodi-rt/build/s2/kit-symbols; rm -rf "$SY"; mkdir -p "$SY"
  cp /f/kodi-rt/build/s2/h264md5-arm32/h264md5.pdb "$SY/" 2>/dev/null || true
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.pdb "$SY/"
  cp /f/kodi-rt/build/s2/dav1d-arm32/tests/checkasm.pdb "$SY/dav1d-checkasm.pdb" 2>/dev/null || true
fi
cp /f/kodi-rt/build/s0/clips/* "$K/clips/"
# expected: the x64 plain-C FFmpeg 9.0.2 reference (scripts/s2-ffmpeg-x64ref.sh), threads=1 (threads=auto is identical)
cp /f/kodi-rt/build/s2/ffmpeg-x64ref/ref-threads1.txt "$K/expected/h264md5.txt"
python -I -c "
import sys; p=sys.argv[1]; d=open(p,'rb').read(); i=d.find(b'md5=')
assert i >= 0, 'no md5= in the expected output'
c=d[i+4:i+5]; r=b'0' if c != b'0' else b'1'
open(sys.argv[2],'wb').write(d[:i+4]+r+d[i+5:])" "$(cygpath -m "$K/expected/h264md5.txt")" "$(cygpath -m "$K/expected/control-changed-h264md5.txt")"
cmp -s "$K/expected/h264md5.txt" "$K/expected/control-changed-h264md5.txt" && { echo "control file is not changed"; exit 1; }

for f in run-stage2.cmd README.txt; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/$f")"
  python -I -c "import sys; d=open(sys.argv[1],'rb').read(); c=d.count(b'\r\n'); n=d.count(b'\n'); print(sys.argv[1].split('/')[-1], 'CRLF', c, 'of', n, 'lines'); sys.exit(0 if c==n and n>0 else 1)" "$(cygpath -m "$K/$f")" || { echo "CRLF conversion failed"; exit 1; }
done
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1))"
if [ "$MODE" != dryrun ]; then
  Z=C:/handoff/$ZNAME.zip
  [ -e "$Z" ] && { echo "$Z exists already; not overwriting"; exit 1; }
  ( cd /f/kodi-rt/kit && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=9 "$Z" "$KNAME" > /dev/null ) || { echo "zip failed"; exit 1; }
  ( cd /c/handoff && sha256sum "$ZNAME.zip" > "$ZNAME.zip.sha256" )
  ls -la "/c/handoff/$ZNAME.zip"*; cat "/c/handoff/$ZNAME.zip.sha256"
fi
echo "PACKAGE DONE"
