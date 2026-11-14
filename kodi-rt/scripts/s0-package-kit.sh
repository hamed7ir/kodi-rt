#!/bin/bash
# kodi-rt Stage 0: assemble the device kit from the build outputs and zip it into C:\handoff.
#   kit/<name>/{run-stage0.cmd,README.txt} are written by hand (kept in kit/); this script adds bin/, clips/,
#   expected/, MANIFEST.txt, converts the .cmd/.txt to CRLF, and zips. Symbols for the kit's binaries are kept in
#   build/s0/kit-symbols[-rt23]/ (never shipped).
# Usage (Git Bash): bash scripts/s0-package-kit.sh [--tag=rt22|rt23] [--dryrun-x86]
#   --tag=rt22 (default): run 1 kit, kodi-rt-stage0 -> C:\handoff\kodi-rt-stage0-20261108.zip
#   --tag=rt23:           run 2 kit, kodi-rt-stage0-rt23 -> C:\handoff\kodi-rt-stage0-rt23-20261109.zip
#   --dryrun-x86: build build/s0/kit-dryrun[-rt23]/ instead, with the x86/x64 builds in bin/ (same names), to test the
#   kit's run-stage0.cmd on this server.
set -u
export MSYS2_ARG_CONV_EXCL='*'
B=/f/kodi-rt/build/s0
MODE=""; TAG=rt22
for a in "$@"; do
  case $a in
    --dryrun-x86) MODE=dryrun ;;
    --tag=*) TAG=${a#--tag=} ;;
    *) echo "unknown argument $a"; exit 2 ;;
  esac
done
EHONLY=""
case $TAG in
  rt22) KNAME=kodi-rt-stage0;      EH=$B/ehtest;                      FF=$B/arm32-rt22; ZNAME=kodi-rt-stage0-20261108;      SUF="" ;;
  rt23) KNAME=kodi-rt-stage0-rt23; EH=/f/kodi-rt/build/s0-rt23/ehtest; FF=$B/arm32-rt23; ZNAME=kodi-rt-stage0-rt23-20261109; SUF="-rt23" ;;
  # rt2.4 changes only C++ EH code generation: the kit carries ehtest alone (h264md5 passed on rt2.2 and rt2.3)
  rt24) KNAME=kodi-rt-stage0-rt24; EH=/f/kodi-rt/build/s0-rt24/ehtest; FF="";             ZNAME=kodi-rt-stage0-rt24-20261112; SUF="-rt24"; EHONLY=1 ;;
  # interim: rt2.4 + "-mllvm -trap-unreachable" on the ARM32 builds (the llvm-rt session: same code as its 0031 fix)
  rt24t) KNAME=kodi-rt-stage0-rt24t; EH=/f/kodi-rt/build/s0-rt24t/ehtest; FF="";          ZNAME=kodi-rt-stage0-rt24t-20261112; SUF="-rt24t"; EHONLY=1 ;;
  # rt2.4 rebuilt with 0031 (0549949d), no extra flags; its ARM32 ehtest equals rt24t's except the version string
  rt24b) KNAME=kodi-rt-stage0-rt24b; EH=/f/kodi-rt/build/s0-rt24b/ehtest; FF="";          ZNAME=kodi-rt-stage0-rt24b-20261112; SUF="-rt24b"; EHONLY=1 ;;
  # rt2.4 rebuilt with 0032 too (0318206a, tc/rt24c-cr); the toolchain session: Release moves one constant to another
  # island, /Od code is identical (checked here too: /Od disassembly identical, Release 164 lines differ)
  rt24c) KNAME=kodi-rt-stage0-rt24c; EH=/f/kodi-rt/build/s0-rt24c/ehtest; FF="";          ZNAME=kodi-rt-stage0-run5-20261112; SUF="-rt24c"; EHONLY=1 ;;
  *) echo "unknown tag $TAG"; exit 2 ;;
esac
KSRC=/f/kodi-rt/kit/$KNAME
if [ "$MODE" = dryrun ]; then K=$B/kit-dryrun$SUF/$KNAME; else K=$KSRC; fi
mkdir -p "$K"
if [ "$K" != "$KSRC" ]; then cp "$KSRC/run-stage0.cmd" "$KSRC/README.txt" "$K/"; fi
rm -rf "$K/bin" "$K/clips" "$K/expected" "$K/MANIFEST.txt"
mkdir -p "$K/bin" "$K/clips" "$K/expected"

if [ "$MODE" = dryrun ]; then
  cp "$EH/x86-rel/ehtest.exe" "$K/bin/ehtest-rel.exe"
  cp "$EH/x86-od/ehtest.exe" "$K/bin/ehtest-od.exe"
  if [ -z "$EHONLY" ]; then
    cp "$B/ffmpeg-x64ref/h264md5/h264md5.exe" "$K/bin/h264md5.exe"
    cp "$B/ffmpeg-x64ref/h264md5/h264md5.exe" "$K/bin/h264probe.exe"   # stand-in: only exercises the script's loop
  fi
  cp /f/kodi-rt/tools/dbgrun/x86/dbgrun.exe "$K/bin/dbgrun.exe"      # x86: it debugs the x86 ehtest on a DIFF
else
  if [ -z "$EHONLY" ]; then
    for f in h264probe.exe h264md5.exe; do cp "$FF/$f" "$K/bin/"; done
    # only the versioned names (the import libs point at them); the build dir also has unversioned copies
    for f in avcodec-62.dll avformat-62.dll avutil-60.dll swresample-6.dll swscale-9.dll; do cp "$FF/$f" "$K/bin/"; done
  fi
  cp "$EH/arm32-rel/ehtest.exe" "$K/bin/ehtest-rel.exe"
  cp "$EH/arm32-od/ehtest.exe" "$K/bin/ehtest-od.exe"
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.exe "$K/bin/dbgrun.exe"
  S=$B/kit-symbols$SUF; rm -rf "$S"; mkdir -p "$S"
  cp "$EH/arm32-rel/ehtest.pdb" "$S/ehtest-rel.pdb"; cp "$EH/arm32-od/ehtest.pdb" "$S/ehtest-od.pdb"
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.pdb "$S/"
  if [ -z "$EHONLY" ]; then
    cp "$FF/h264md5.pdb" "$S/"
    # the ffmpeg-rt build dir holds the LAST build's PDBs: package right after that toolchain's build
    cp /f/kodi-rt/src/ffmpeg-rt/build/msys2-shared/lib*/*.pdb "$S/"
    cp /f/kodi-rt/src/ffmpeg-rt/build/probe/h264probe.pdb "$S/" 2>/dev/null || echo "(h264probe has no PDB: build-probe.sh links without -debug)"
  fi
fi
if [ -z "$EHONLY" ]; then cp "$B"/clips/* "$K/clips/"; else rmdir "$K/clips"; fi

# expected output: the x86 Release build's stdout (identical to x86 /Od and to MSVC cl's, checked by the build log)
cp "$EH/x86-rel/stdout.txt" "$K/expected/ehtest.txt"
# the comparator control: the same file with one planted change
sed -e '1s/^T01 OK  /T01 FAIL/' "$K/expected/ehtest.txt" > "$K/expected/control-changed-ehtest.txt"
cmp -s "$K/expected/ehtest.txt" "$K/expected/control-changed-ehtest.txt" && { echo "control file is not changed"; exit 1; }
[ -z "$EHONLY" ] && cp "$B/ffmpeg-x64ref/ref-threads1.txt" "$K/expected/h264md5.txt"

# CRLF for the files the tablet's cmd and Notepad read
for f in run-stage0.cmd README.txt; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/$f")"
done
# (Git Bash's grep does not see the \r: count bytes instead, and stop if any line lacks its CR)
for f in run-stage0.cmd README.txt; do
  python -I -c "import sys; d=open(sys.argv[1],'rb').read(); c=d.count(b'\r\n'); n=d.count(b'\n'); print(sys.argv[1].split('/')[-1], 'CRLF', c, 'of', n, 'lines'); sys.exit(0 if c==n and n>0 else 1)" "$(cygpath -m "$K/$f")" || { echo "CRLF conversion failed"; exit 1; }
done

# MANIFEST
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
