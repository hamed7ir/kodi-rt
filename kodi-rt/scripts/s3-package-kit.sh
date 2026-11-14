#!/bin/bash
# kodi-rt Stage 3: assemble the device kit (kit/kodi-rt-stage3) and zip it into C:\handoff.
#   kit/kodi-rt-stage3/{run-stage3.cmd,README.txt} are written by hand; this adds bin/, fonts/, expected/, MANIFEST.txt,
#   converts the .cmd/.txt to CRLF (not the .bin test data), and zips.
# Usage (Git Bash): bash scripts/s3-package-kit.sh [--dryrun-x64 [--fail]]
#   --dryrun-x64: build/s3/kit-dryrun/kodi-rt-stage3 with x64 stand-ins (one stub source, a role per -D): the two
#   self-tests print "ALL PASSED (3 checks)" and exit 0, openssl prints "OpenSSL 3.5.7", iconv writes the expected
#   bytes; with --fail each fails its own way (FAILED line and exit 1; wrong version; wrong bytes).
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24b-cr/bin
MODE=""; FAILSTUB=0
for a in "$@"; do case $a in --dryrun-x64) MODE=dryrun ;; --fail) FAILSTUB=1 ;; *) echo "unknown argument $a"; exit 2 ;; esac; done
KNAME=kodi-rt-stage3; ZNAME=${ZNAME:-kodi-rt-stage3-20261112}   # run 2: ZNAME=kodi-rt-stage3-run2-20261112
KSRC=/f/kodi-rt/kit/$KNAME
if [ "$MODE" = dryrun ]; then K=/f/kodi-rt/build/s3/kit-dryrun/$KNAME; else K=$KSRC; fi
mkdir -p "$K"
[ "$K" != "$KSRC" ] && cp "$KSRC/run-stage3.cmd" "$KSRC/README.txt" "$K/"
rm -rf "$K/bin" "$K/fonts" "$K/expected" "$K/MANIFEST.txt" "$K"/results*
mkdir -p "$K/bin" "$K/fonts" "$K/expected"
E=$(cygpath -m "$K/expected")
python -I - "$E" <<'EOF'
import sys, os
e = sys.argv[1]
utf8 = 'Kodi café naïve Ångström'.encode('utf-8')
latin1 = 'Kodi café naïve Ångström'.encode('latin-1')
open(os.path.join(e, 'iconv-in-utf8.bin'), 'wb').write(utf8)
open(os.path.join(e, 'iconv-out-latin1.bin'), 'wb').write(latin1)
open(os.path.join(e, 'control-changed-latin1.bin'), 'wb').write(latin1[:-1] + b'M')
open(os.path.join(e, 'control-passed.txt'), 'wb').write(b'CHECK x OK\r\nALL PASSED (1 checks)\r\n')
open(os.path.join(e, 'control-failed.txt'), 'wb').write(b'CHECK x FAIL\r\nFAILED (1 of 1 checks)\r\n')
EOF
cp /f/kodi-rt/src/xbmc/addons/skin.estuary/fonts/NotoSans-Regular.ttf /f/kodi-rt/src/xbmc/addons/skin.estuary/fonts/noto_license.txt "$K/fonts/"

if [ "$MODE" = dryrun ]; then
  S=/f/kodi-rt/build/s3/kit-dryrun/stub; mkdir -p "$S"
  cat > "$S/stub.c" <<'EOF'
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
int main(void) {
#if defined(ROLE_SELFTEST)
  puts(FAILSTUB ? "CHECK x FAIL\nFAILED (1 of 3 checks)" : "CHECK x OK\nALL PASSED (3 checks)"); return FAILSTUB;
#elif defined(ROLE_OPENSSL)
  puts(FAILSTUB ? "OpenSSL 0.0.0" : "OpenSSL 3.5.7 stand-in"); return 0;
#else
  static const unsigned char ok[] = "Kodi caf\xe9 na\xefve \xc5ngstr\xf6m", bad[] = "wrong";
  _setmode(_fileno(stdout), _O_BINARY);
  fwrite(FAILSTUB ? bad : ok, 1, (FAILSTUB ? sizeof bad : sizeof ok) - 1, stdout); return 0;
#endif
}
EOF
  for role in SELFTEST:s3test-c SELFTEST:s3test-cpp OPENSSL:openssl ICONV:iconv; do
    r=${role%%:*}; n=${role#*:}
    "$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo -DROLE_$r -DFAILSTUB=$FAILSTUB "$(cygpath -m "$S/stub.c")" \
      "-Fe$(cygpath -m "$S/$n.exe")" "-Fo$(cygpath -m "$S/$n.obj")" -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp \
      > "$S/build-$n.log" 2>&1 || { cat "$S/build-$n.log"; exit 1; }
    cp "$S/$n.exe" "$K/bin/$n.exe"
  done
  cp /f/kodi-rt/tools/dbgrun/x64/dbgrun.exe "$K/bin/dbgrun.exe"
else
  cp /f/kodi-rt/build/s3/s3test/s3test-c.exe /f/kodi-rt/build/s3/s3test/s3test-cpp.exe "$K/bin/"
  cp /f/kodi-rt/prefix/arm32/bin/openssl.exe /f/kodi-rt/prefix/arm32/bin/iconv.exe /f/kodi-rt/prefix/arm32/bin/dvdnav.dll "$K/bin/"
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.exe "$K/bin/"
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$K/bin")"/*.exe "$(cygpath -m "$K/bin")"/*.dll \
    || { echo "a kit binary is not ARM32"; exit 1; }
  python -I F:/kodi-rt/scripts/check-imports.py "$RT/llvm-readobj.exe" F:/kodi-rt/results/stage0-run1/dlls \
    "$(cygpath -m "$K/bin")"/*.exe "$(cygpath -m "$K/bin")"/dvdnav.dll || { echo "an import is missing on the device"; exit 1; }
fi
for f in run-stage3.cmd README.txt; do
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
