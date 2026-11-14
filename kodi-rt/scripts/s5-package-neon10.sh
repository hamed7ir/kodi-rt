#!/bin/bash
# kodi-rt Stage 5: the neon10 device kit (10-bit HEVC motion compensation NEON test): kit/kodi-rt-stage5-neon10
#   {run-neon10.cmd, README.txt} are hand-written; this adds bin\checkasm.exe (build/s2/ffmpeg-arm32, with the new code),
#   bin\hevcbench.exe (scripts/s5-hevcbench.sh), bin\dbgrun.exe, CRLF, MANIFEST.txt, and zips into C:\handoff.
# Usage (Git Bash): bash scripts/s5-package-neon10.sh [--dryrun-x64=normal|fail|nopassline]
#   --dryrun-x64: build/s5/kit-dryrun/kodi-rt-stage5-neon10 with x64 stand-ins (tests/stage5/checkasm-standin.c in that
#   role, the x64 hevcbench and dbgrun), to run the kit's script on this server.
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24c-cr/bin
KNAME=kodi-rt-stage5-neon10; ZNAME=kodi-rt-stage5-neon10-20261113
KSRC=/f/kodi-rt/kit/$KNAME
ROLE=""
for a in "$@"; do case $a in --dryrun-x64=*) ROLE=${a#--dryrun-x64=} ;; *) echo "unknown argument $a"; exit 2 ;; esac; done
if [ -n "$ROLE" ]; then K=/f/kodi-rt/build/s5/kit-dryrun/$KNAME; else K=$KSRC; fi
mkdir -p "$K"
[ "$K" != "$KSRC" ] && cp "$KSRC/run-neon10.cmd" "$KSRC/README.txt" "$K/"
rm -rf "$K/bin" "$K/MANIFEST.txt" "$K"/results*
mkdir -p "$K/bin"
if [ -n "$ROLE" ]; then
  case $ROLE in normal) DEF="" ;; fail) DEF=-DSTANDIN_FAIL ;; nopassline) DEF=-DSTANDIN_NOPASSLINE ;;
    *) echo "unknown role $ROLE"; exit 2 ;; esac
  S=F:/kodi-rt/build/s5/kit-dryrun/standin-checkasm; mkdir -p "$S"
  "$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo $DEF F:/kodi-rt/tests/stage5/checkasm-standin.c \
    "-Fe$S/checkasm.exe" "-Fo$S/checkasm.obj" -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp > "$S/build.log" 2>&1 \
    || { cat "$S/build.log"; echo "stand-in build failed"; exit 1; }
  cp "$S/checkasm.exe" "$K/bin/checkasm.exe"
  cp /f/kodi-rt/build/s5/hevcbench/x64/hevcbench.exe "$K/bin/hevcbench.exe"
  cp /f/kodi-rt/tools/dbgrun/x64/dbgrun.exe "$K/bin/dbgrun.exe"
  echo "dry run: stand-in role $ROLE"
else
  cp /f/kodi-rt/build/s2/ffmpeg-arm32/tests/checkasm/checkasm.exe "$K/bin/" || exit 1
  cp /f/kodi-rt/build/s5/hevcbench/arm32/hevcbench.exe "$K/bin/" || exit 1
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.exe "$K/bin/" || exit 1
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/bin/checkasm.exe")" \
    "$(cygpath -m "$K/bin/hevcbench.exe")" "$(cygpath -m "$K/bin/dbgrun.exe")" || { echo "not all ARM32"; exit 1; }
fi
for f in run-neon10.cmd README.txt; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/$f")"
done
( cd "$K" && find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$K/MANIFEST.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/MANIFEST.txt")"
echo "kit: $K ($(find "$K" -type f | wc -l) files, $(du -sh "$K" | cut -f1))"
if [ -z "$ROLE" ]; then
  Z=C:/handoff/$ZNAME.zip
  [ -e "$Z" ] && { echo "$Z exists already; not overwriting"; exit 1; }
  ( cd /f/kodi-rt/kit && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=9 "$Z" "$KNAME" > /dev/null ) || { echo "zip failed"; exit 1; }
  ( cd /c/handoff && sha256sum "$ZNAME.zip" > "$ZNAME.zip.sha256" )
  ls -la "/c/handoff/$ZNAME.zip"*; cat "/c/handoff/$ZNAME.zip.sha256"
fi
echo "PACKAGE DONE"
