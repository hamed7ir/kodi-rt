#!/bin/bash
# kodi-rt Stage 2b: the follow-up kit with dav1d's untrimmed checkasm (build/s2/dav1d-arm32-untrimmed), zipped into
# C:\handoff. Usage (Git Bash): bash scripts/s2b-package-kit.sh [--dryrun-x64 [--fail]]
#   --dryrun-x64: build/s2/kit-dryrun-2b/ with an x64 stand-in that prints a passing line (or, with --fail, the
#   "reference functions unavailable" line and exit 0, the Stage 2 case), and the x64 dbgrun.
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24b-cr/bin
MODE=""; FAILSTUB=0
for a in "$@"; do case $a in --dryrun-x64) MODE=dryrun ;; --fail) FAILSTUB=1 ;; *) echo "unknown argument $a"; exit 2 ;; esac; done
KNAME=kodi-rt-stage2b; ZNAME=kodi-rt-stage2b-20261112
KSRC=/f/kodi-rt/kit/$KNAME
if [ "$MODE" = dryrun ]; then K=/f/kodi-rt/build/s2/kit-dryrun-2b/$KNAME; else K=$KSRC; fi
mkdir -p "$K"
[ "$K" != "$KSRC" ] && cp "$KSRC/run-stage2b.cmd" "$KSRC/README.txt" "$K/"
rm -rf "$K/bin" "$K/expected" "$K/MANIFEST.txt" "$K"/results*
mkdir -p "$K/bin" "$K/expected"
printf 'checkasm: all 1234 tests passed\n' > "$K/expected/control-passed.txt"
printf "checkasm: reference functions unavailable, reconfigure using '-Dtrim_dsp=false'\n" > "$K/expected/control-unavailable.txt"
if [ "$MODE" = dryrun ]; then
  S=/f/kodi-rt/build/s2/kit-dryrun-2b/stub; mkdir -p "$S"
  if [ $FAILSTUB = 1 ]; then
    printf '#include <stdio.h>\nint main(void){fprintf(stderr,"checkasm: reference functions unavailable, reconfigure using %s\\n","-Dtrim_dsp=false");return 0;}\n' "'"'-Dtrim_dsp=false'"'" > "$S/stub.c"
  else
    printf '#include <stdio.h>\nint main(void){fprintf(stderr,"checkasm: all 42 tests passed\\n");return 0;}\n' > "$S/stub.c"
  fi
  "$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo "$(cygpath -m "$S/stub.c")" "-Fe$(cygpath -m "$S/stub.exe")" \
    "-Fo$(cygpath -m "$S/stub.obj")" -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp > "$S/build.log" 2>&1 || { cat "$S/build.log"; exit 1; }
  cp "$S/stub.exe" "$K/bin/dav1d-checkasm.exe"
  cp /f/kodi-rt/tools/dbgrun/x64/dbgrun.exe "$K/bin/dbgrun.exe"
else
  cp /f/kodi-rt/build/s2/dav1d-arm32-untrimmed/tests/checkasm.exe "$K/bin/dav1d-checkasm.exe"
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.exe "$K/bin/dbgrun.exe"
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/bin")"/*.exe || { echo "a kit binary is not ARM32"; exit 1; }
fi
for f in run-stage2b.cmd README.txt expected/control-passed.txt expected/control-unavailable.txt; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/$f")"
done
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1))"
if [ "$MODE" != dryrun ]; then
  Z=C:/handoff/$ZNAME.zip
  [ -e "$Z" ] && { echo "$Z exists already; not overwriting"; exit 1; }
  ( cd /f/kodi-rt/kit && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=9 "$Z" "$KNAME" > /dev/null ) || { echo "zip failed"; exit 1; }
  ( cd /c/handoff && sha256sum "$ZNAME.zip" > "$ZNAME.zip.sha256" )
  ls -la "/c/handoff/$ZNAME.zip"; cat "/c/handoff/$ZNAME.zip.sha256"
fi
echo "PACKAGE DONE"
