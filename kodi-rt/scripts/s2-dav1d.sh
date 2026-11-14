#!/bin/bash
# kodi-rt Stage 2: dav1d 1.5.3 (Kodi's pin), static, /MT, rt2.4, into F:/kodi-rt/prefix/$ARCH (cross/arch.sh: arm32
# by default, or ARCH=x64 / ARCH=x86). meson 1.9.1 (venv F:/kodi-rt/tools/pyenv) + ninja 1.12.1 (VS build tools) +
# cross/meson-$ARCH.ini.
# ARM32: NEON assembly, and tests on: tests/checkasm/checkasm.exe checks every NEON function against the C reference,
# on the device. x64/x86: the x86 assembly with nasm (tools/nasm, scripts/s9-nasm.sh; without it A_ASM=no: no
# assembly, no checkasm), and checkasm runs right here, since this server runs x64 and x86 programs.
# FFmpeg's configure with Kodi's patch 005 links "libdav1d.lib", so the static library is also installed under it.
# Run from Git Bash: nice -n 10 bash scripts/s2-dav1d.sh   (ARCH=x64 bash scripts/s2-dav1d.sh for x64)
set -u
source /f/kodi-rt/cross/arch.sh
export MSYS2_ARG_CONV_EXCL='*'
# rt2.4 first: meson's clang-cl detection runs a bare "lld-link" (cross/meson-arm32.ini explains)
export PATH="$A_RTP/bin:$A_NASMP:/d/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja:$PATH"
MESON=F:/kodi-rt/tools/pyenv/Scripts/meson.exe
SRC=F:/kodi-rt/src/deps/dav1d-1.5.3
BD=F:/kodi-rt/build/s2/dav1d-$ARCH
PFX=$A_PFX
if [ $A_ASM = yes ]; then ASMOPT=(-Denable_asm=true -Denable_tests=true); else ASMOPT=(-Denable_asm=false -Denable_tests=false); fi
JOBS=${JOBS:-8}
rm -rf "$BD"
"$MESON" setup "$BD" "$SRC" --cross-file "$A_MESON" --prefix "$PFX" \
  --buildtype release --default-library static \
  "${ASMOPT[@]}" -Denable_tools=false -Denable_examples=false \
  || { echo "DAV1D SETUP FAILED"; exit 1; }
grep -E 'HAVE_ASM|ARCH_ARM|ARCH_X86|HAVE_AS_FUNC|PIC' "$BD/config.h"
"$MESON" compile -C "$BD" -j "$JOBS" || { echo "DAV1D BUILD FAILED"; exit 1; }
# checkasm has build_by_default: false
if [ $A_ASM = yes ]; then
  "$MESON" compile -C "$BD" -j "$JOBS" checkasm || { echo "DAV1D CHECKASM BUILD FAILED"; exit 1; }
fi
"$MESON" install -C "$BD" || { echo "DAV1D INSTALL FAILED"; exit 1; }
L=$(ls "$PFX"/lib/libdav1d.a "$PFX"/lib/dav1d.lib 2>/dev/null | head -1)
[ -n "$L" ] || { echo "no static dav1d in $PFX/lib"; ls "$PFX/lib"; exit 1; }
[ "$L" = "$PFX/lib/libdav1d.lib" ] || cp -f "$L" "$PFX/lib/libdav1d.lib"
echo "installed $(basename "$L") and libdav1d.lib"
ls -la "$BD/tests/checkasm/"*.exe 2>/dev/null || ls "$BD/tests"
if [ "$ARCH" != arm32 ] && [ $A_ASM = yes ]; then
  # the release build trims the C reference functions (trim_dsp), so its checkasm checks nothing ("reference functions
  # unavailable"); a second build with -Dtrim_dsp=false only for checkasm, run here
  CB=$BD-checkasm
  rm -rf "$CB"
  "$MESON" setup "$CB" "$SRC" --cross-file "$A_MESON" --buildtype release --default-library static \
    -Denable_asm=true -Denable_tests=true -Dtrim_dsp=false -Denable_tools=false -Denable_examples=false > "$CB.log" 2>&1 \
    && "$MESON" compile -C "$CB" -j "$JOBS" checkasm >> "$CB.log" 2>&1 || { echo "DAV1D CHECKASM BUILD FAILED ($CB.log)"; exit 1; }
  "$CB/tests/checkasm.exe" > "$CB/checkasm.txt" 2>&1; rc=$?
  tail -3 "$CB/checkasm.txt"
  grep -q "reference functions unavailable" "$CB/checkasm.txt" && rc=2
  [ $rc = 0 ] || { echo "DAV1D CHECKASM FAILED (rc $rc, $CB/checkasm.txt)"; exit 1; }
fi
echo "DAV1D DONE"
