#!/bin/bash
# kodi-rt Stage 5: assemble the Kodi device kit (kit/kodi-rt-stage5) and zip it into C:\handoff.
#   kit/kodi-rt-stage5/{run-kodi.cmd,run-kodi-dbgrun.cmd,README.txt} are written by hand. This adds kodi/ (the GATED
#   kodi.exe from results/stage4-server/bin, dvdnav.dll from the prefix, and the build tree's addons, media, system and
#   userdata folders), bin/dbgrun.exe and MANIFEST.txt, converts the .cmd/.txt files to CRLF, and zips.
#   kodi.pdb is not shipped: it stays in results/stage4-server/bin for symbolizing.
# Usage (Git Bash): bash scripts/s5-package-kit.sh [--dryrun-x64=normal|crash|nolog|break]
#   --dryrun-x64=<role>: build build/s5/kit-dryrun/kodi-rt-stage5 instead, with an x64 stand-in for kodi.exe
#   (tests/stage5/kodi-standin.c in that role) and the x64 dbgrun, to run the kit's scripts on this server.
#   ("break" is for run-kodi-dbgrun.cmd only: without a debugger it would raise an unhandled breakpoint.)
# Options (environment): ADVSET=1 adds kit/portable-data/advancedsettings.xml (Stage 5 run 6 preset); PYTHON=1 adds
#   python314.dll, kit/python/python314._pth and the stdlib (without tests, IDLE, tkinter, turtledemo, ensurepip) as
#   kodi\system\python (Stage 6); RTPROF=1 adds bin\rtprof.exe (build/s6/rtprof) for kit/<KNAME>/run-kodi-profile.cmd.
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24c-cr/bin
ROLE=""
for a in "$@"; do
  case $a in
    --dryrun-x64=*) ROLE=${a#--dryrun-x64=} ;;
    *) echo "unknown argument $a"; exit 2 ;;
  esac
done
# run 1: the defaults. run 2 (touch): KNAME=kodi-rt-stage5-run2 ZNAME=kodi-rt-stage5-run2-20261112 GATED=.../stage5-kit2/bin
KNAME=${KNAME:-kodi-rt-stage5}; ZNAME=${ZNAME:-kodi-rt-stage5-20261112}
KSRC=/f/kodi-rt/kit/$KNAME
BD=/f/kodi-rt/build/s4/kodi-build
GATED=${GATED:-/f/kodi-rt/results/stage4-server/bin}
if [ -n "$ROLE" ]; then K=/f/kodi-rt/build/s5/kit-dryrun/$KNAME; else K=$KSRC; fi
mkdir -p "$K"
[ "$K" != "$KSRC" ] && cp "$KSRC/run-kodi.cmd" "$KSRC/run-kodi-dbgrun.cmd" "$KSRC/README.txt" "$K/"
[ "$K" != "$KSRC" ] && [ -f "$KSRC/run-kodi-profile.cmd" ] && cp "$KSRC/run-kodi-profile.cmd" "$K/"
rm -rf "$K/kodi" "$K/bin" "$K/MANIFEST.txt" "$K"/results*
mkdir -p "$K/kodi" "$K/bin"

# the gated exe, and the data folders of the same build
( cd "$GATED" && sha256sum -c --quiet SHA256SUMS.txt ) || { echo "results/stage4-server/bin does not match its SHA256SUMS"; exit 1; }
cmp -s "$GATED/kodi.exe" "$BD/kodi.exe" || { echo "build/s4/kodi-build/kodi.exe is not the gated one: package from that build"; exit 1; }
# -L: the tree has a symlink (system/settings/freebsd.xml -> linux.xml); a zip and the tablet want plain files
for d in addons media system userdata; do cp -rL "$BD/$d" "$K/kodi/" || exit 1; done
cp /f/kodi-rt/prefix/arm32/bin/dvdnav.dll "$K/kodi/" || exit 1     # DllPaths_win32.h: special://xbmcbin/dvdnav.dll
# touch-only use (Stage 5 run 1): two-finger tap = Back, a tap keeps the video controls up (kit/keymaps/*.xml says why)
mkdir -p "$K/kodi/portable_data/userdata/keymaps"
cp /f/kodi-rt/kit/keymaps/touchscreen-kodirt.xml "$K/kodi/portable_data/userdata/keymaps/" || exit 1
# Estuary's touch mode on (on-screen Back buttons): the skin setting "touchmode", as Kodi stores it
mkdir -p "$K/kodi/portable_data/userdata/addon_data/skin.estuary"
cp /f/kodi-rt/kit/portable-data/skin.estuary-settings.xml "$K/kodi/portable_data/userdata/addon_data/skin.estuary/settings.xml" || exit 1
# Stage 5 run 6 preset: skiploopfilter 48
if [ -n "${ADVSET:-}" ]; then
  cp /f/kodi-rt/kit/portable-data/advancedsettings.xml "$K/kodi/portable_data/userdata/" || exit 1
fi
# Stage 6: Python next to kodi.exe (python314._pth: Python's paths, since Kodi's PYTHONHOME only reaches its emulated
# environment)
if [ -n "${PYTHON:-}" ]; then
  PY=/f/kodi-rt/prefix/arm32/python
  cp "$PY/python314.dll" /f/kodi-rt/kit/python/python314._pth "$K/kodi/" || exit 1
  mkdir -p "$K/kodi/system/python/DLLs"
  cp -r "$PY/Lib" "$K/kodi/system/python/" || exit 1
  ( cd "$K/kodi/system/python/Lib" && rm -rf test idlelib tkinter turtledemo ensurepip && find . -name __pycache__ -prune -exec rm -rf {} + )
  mkdir -p "$K/kodi/system/python/Lib/site-packages"
fi

if [ -n "$ROLE" ]; then
  S=/f/kodi-rt/build/s5/kit-dryrun/standin; mkdir -p "$S"
  case $ROLE in
    normal) DEF="" ;; crash) DEF=-DSTANDIN_CRASH ;; nolog) DEF=-DSTANDIN_NOLOG ;; break) DEF=-DSTANDIN_BREAK ;;
    *) echo "unknown role $ROLE"; exit 2 ;;
  esac
  "$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -nologo $DEF F:/kodi-rt/tests/stage5/kodi-standin.c \
    "-Fe$(cygpath -m "$S/kodi.exe")" "-Fo$(cygpath -m "$S/kodi.obj")" -fuse-ld=lld -link @F:/kodi-rt/cross/x64-link.rsp \
    > "$S/build.log" 2>&1 || { cat "$S/build.log"; echo "stand-in build failed"; exit 1; }
  cp "$S/kodi.exe" "$K/kodi/kodi.exe"
  cp /f/kodi-rt/tools/dbgrun/x64/dbgrun.exe "$K/bin/dbgrun.exe"
  [ -n "${RTPROF:-}" ] && cp /f/kodi-rt/build/s6/rtprof/x64/rtprof.exe "$K/bin/rtprof.exe"
  echo "dry run: stand-in role $ROLE"
else
  cp "$GATED/kodi.exe" "$K/kodi/"
  cp /f/kodi-rt/tools/dbgrun/arm32/dbgrun.exe "$K/bin/dbgrun.exe"
  check=("$(cygpath -m "$K/kodi/kodi.exe")" "$(cygpath -m "$K/kodi/dvdnav.dll")" "$(cygpath -m "$K/bin/dbgrun.exe")")
  if [ -n "${RTPROF:-}" ]; then
    cp /f/kodi-rt/build/s6/rtprof/arm32/rtprof.exe "$K/bin/rtprof.exe" || exit 1
    check+=("$(cygpath -m "$K/bin/rtprof.exe")")
  fi
  [ -n "${PYTHON:-}" ] && check+=("$(cygpath -m "$K/kodi/python314.dll")")
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "${check[@]}" || { echo "not all ARM32"; exit 1; }
fi

# CRLF for the files the tablet's cmd and Notepad read
CRLF=(run-kodi.cmd run-kodi-dbgrun.cmd README.txt)
[ -f "$K/run-kodi-profile.cmd" ] && CRLF+=(run-kodi-profile.cmd)
for f in "${CRLF[@]}"; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$K/$f")"
  python -I -c "import sys; d=open(sys.argv[1],'rb').read(); c=d.count(b'\r\n'); n=d.count(b'\n'); print(sys.argv[1].split('/')[-1], 'CRLF', c, 'of', n, 'lines'); sys.exit(0 if c==n and n>0 else 1)" "$(cygpath -m "$K/$f")" || { echo "CRLF conversion failed"; exit 1; }
done

# MANIFEST (sha256 of every file)
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
