#!/bin/bash
# kodi-rt Stage 5/6: an update zip that is unzipped OVER an existing kit folder on the tablet, so its portable_data
#   (installed skins, add-ons, sources) stays. It holds the GATED kodi.exe, every file in kit/$UNAME (README, run
#   scripts, extra files under kodi/; these get CRLF if text), and MANIFEST-$UNAME.txt, with no top folder.
#   BASEKIT=<kit folder>: also every file of the build tree's addons/media/system/userdata that differs from that kit's
#   kodi\ folder (new or changed), so the update brings everything the base kit lacks.
#   PYTHON=1: also python314.dll next to kodi.exe and the standard library as kodi\system\python\Lib (without tests,
#   IDLE, tkinter, turtledemo, ensurepip) from prefix/arm32/python, plus empty DLLs\ and Lib\site-packages\, and
#   addons\script.module.pycryptodome and script.module.pil from prefix/arm32/kodi-addons when built
#   (scripts/pycd-build.sh, scripts/pil-build.sh).
# Usage (Git Bash):
#   UNAME=kodi-rt-stage5-run5-update ZNAME=kodi-rt-stage5-run5-update-20261113 \
#   GATED=/f/kodi-rt/results/stage5-kit5/bin [BASEKIT=/f/kodi-rt/kit/kodi-rt-stage5-run4] [PYTHON=1] \
#   bash scripts/s5-package-update.sh
set -u
UNAME=${UNAME:?set UNAME}; ZNAME=${ZNAME:?set ZNAME}; GATED=${GATED:?set GATED}
BASEKIT=${BASEKIT:-}; PYTHON=${PYTHON:-}
SRC=/f/kodi-rt/kit/$UNAME
OUT=/f/kodi-rt/build/s5/update/$UNAME
BD=/f/kodi-rt/build/s4/kodi-build
PY=/f/kodi-rt/prefix/arm32/python
( cd "$GATED" && sha256sum -c --quiet SHA256SUMS.txt ) || { echo "$GATED does not match its SHA256SUMS"; exit 1; }
cmp -s "$GATED/kodi.exe" "$BD/kodi.exe" || { echo "build/s4/kodi-build/kodi.exe is not the gated one"; exit 1; }
rm -rf "$OUT"; mkdir -p "$OUT/kodi"
cp -r "$SRC/." "$OUT/" || exit 1
# CRLF for the kit's own text files (before anything else is added)
find "$OUT" -type f \( -name '*.cmd' -o -name '*.txt' -o -name '*.xml' \) | while read -r f; do
  python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$f")"
  python -I -c "import sys; d=open(sys.argv[1],'rb').read(); c=d.count(b'\r\n'); n=d.count(b'\n'); print(sys.argv[1].split('/')[-1], 'CRLF', c, 'of', n, 'lines'); sys.exit(0 if c==n and n>0 else 1)" "$(cygpath -m "$f")" || { echo "CRLF conversion failed"; exit 1; }
done
cp "$GATED/kodi.exe" "$OUT/kodi/" || exit 1
python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$OUT/kodi/kodi.exe")" || { echo "not ARM32"; exit 1; }
if [ -n "$BASEKIT" ]; then
  n=0
  for d in addons media system userdata; do
    while read -r f; do
      rel=${f#$BD/}
      if ! cmp -s "$f" "$BASEKIT/kodi/$rel"; then
        mkdir -p "$(dirname "$OUT/kodi/$rel")"; cp "$f" "$OUT/kodi/$rel"; n=$((n + 1)); echo "   changed or new: $rel"
      fi
    done < <(find -L "$BD/$d" -type f)
  done
  echo "data files that differ from $(basename "$BASEKIT"): $n"
fi
if [ -n "$PYTHON" ]; then
  cp "$PY/python314.dll" "$OUT/kodi/" || exit 1
  python -I F:/kodi-rt/scripts/check-machine.py --want=0x1c4 "$(cygpath -m "$OUT/kodi/python314.dll")" || { echo "not ARM32"; exit 1; }
  mkdir -p "$OUT/kodi/system/python/DLLs"
  cp -r "$PY/Lib" "$OUT/kodi/system/python/" || exit 1
  ( cd "$OUT/kodi/system/python/Lib" && rm -rf test idlelib tkinter turtledemo ensurepip && find . -name __pycache__ -prune -exec rm -rf {} + )
  mkdir -p "$OUT/kodi/system/python/Lib/site-packages"
  [ -f "$OUT/kodi/python314._pth" ] || { echo "kit/$UNAME/kodi/python314._pth missing"; exit 1; }
  echo "python: $(find "$OUT/kodi/system/python" -type f | wc -l) files, $(du -sh "$OUT/kodi/system/python" | cut -f1)"
  # Kodi's script.module.pycryptodome with the Cryptodome package and its ARM32 C modules (scripts/pycd-build.sh)
  PYCD=/f/kodi-rt/prefix/arm32/kodi-addons/script.module.pycryptodome
  if [ -d "$PYCD/lib/Cryptodome" ]; then
    mkdir -p "$OUT/kodi/addons" && rm -rf "$OUT/kodi/addons/script.module.pycryptodome" && cp -r "$PYCD" "$OUT/kodi/addons/" || exit 1
    find "$OUT/kodi/addons/script.module.pycryptodome" -name __pycache__ -prune -exec rm -rf {} +
    echo "pycryptodome add-on: $(find "$OUT/kodi/addons/script.module.pycryptodome" -name '*.pyd' | wc -l) C modules"
  fi
  PIL=/f/kodi-rt/prefix/arm32/kodi-addons/script.module.pil
  if [ -f "$PIL/lib/PIL/_imaging.pyd" ]; then
    mkdir -p "$OUT/kodi/addons" && rm -rf "$OUT/kodi/addons/script.module.pil" && cp -r "$PIL" "$OUT/kodi/addons/" || exit 1
    find "$OUT/kodi/addons/script.module.pil" -name __pycache__ -prune -exec rm -rf {} +
    echo "Pillow add-on: $(find "$OUT/kodi/addons/script.module.pil" -name '*.pyd' | wc -l) C modules"
  fi
fi
( cd "$OUT" && find . -type f | sed 's|^\./||' | sort | while read -r f; do printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"; done ) > "$OUT/MANIFEST-$UNAME.txt"
python -I -c "import sys; p=sys.argv[1]; d=open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'); open(p,'wb').write(d)" "$(cygpath -m "$OUT/MANIFEST-$UNAME.txt")"
Z=C:/handoff/$ZNAME.zip
[ -e "$Z" ] && { echo "$Z exists already; not overwriting"; exit 1; }
( cd "$OUT" && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=9 "$Z" * > /dev/null ) || { echo "zip failed"; exit 1; }
( cd /c/handoff && sha256sum "$ZNAME.zip" > "$ZNAME.zip.sha256" )
"/c/Program Files/7-Zip/7z.exe" l "$Z" | tail -n 3
ls -la "/c/handoff/$ZNAME.zip"*; cat "/c/handoff/$ZNAME.zip.sha256"
echo "UPDATE PACKAGE DONE"
