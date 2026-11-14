#!/bin/bash
# kodi-rt Stage 0: FFmpeg 8.1.2 for ARM32 through the ffmpeg-rt harness, UNCHANGED, with rt2.2 instead of rt2.
# ffmpeg-rt's own scripts run as they are (gen-rsp, configure-arm32, gate-config, verify-build, build-probe); the only
# differences: RT2 points at rt2.2, make runs at -j2 (build.sh hardcodes -j12), verify-build gets the x64 control
# object it expects at build/noext/h.obj, and an extra gate checks HAVE_VFP_ARGS (hard-float ABI).
# Then builds h264md5 (tests/stage0/h264md5) against the same import libs.
# Run with MSYS2's bash (GNU make), detached: scripts/launch-detached.ps1 -Script <frozen copy of this file>
# Argument (optional): toolchain tag, rt22 (default) or rt23. MSYS2 bash started from Git Bash/WMI gets no VAR=x
# prefixes (handoff trap 10), so it is an argument. Outputs and logs carry the tag (rt22 keeps the original names).
TAG=${1:-rt22}
case $TAG in
  rt22) RT=F:/cr/rt22-cr/bin; LS="" ;;
  rt23) RT=F:/cr/rt23-cr/bin; LS="-rt23" ;;
  *) echo "unknown toolchain tag $TAG"; exit 2 ;;
esac
exec > /f/kodi-rt/logs/s0-ffmpeg-arm32$LS.log 2>&1
set -u
echo "start $(date '+%F %T') toolchain=$TAG"
export RT2=$RT
FR=/f/kodi-rt/src/ffmpeg-rt
export FF_ROOT=$FR
OUT=/f/kodi-rt/build/s0/arm32-$TAG
LOGS=/f/kodi-rt/logs
cd "$FR" || exit 1
. "$FR/config.sh"
rt_check_config || exit 1
"$RT2/clang-cl.exe" --version | head -1

echo "=== gen-rsp ==="
sh scripts/gen-rsp.sh || exit 1
echo "=== configure-arm32 (ffmpeg-rt, unchanged) ==="
sh scripts/configure-arm32.sh > $LOGS/s0-ffmpeg-arm32$LS-configure.log 2>&1
tail -5 $LOGS/s0-ffmpeg-arm32$LS-configure.log
grep -q '===CONFIGURE EXIT=0===' $LOGS/s0-ffmpeg-arm32$LS-configure.log || { echo "CONFIGURE FAILED"; exit 1; }
grep -i 'WARNING' $LOGS/s0-ffmpeg-arm32$LS-configure.log | head -20

echo "=== gate-config (ffmpeg-rt, unchanged) ==="
sh scripts/gate-config.sh || { echo "GATE FAILED"; exit 1; }
B=$FR/build/msys2-shared
echo "=== extra gate (kodi-rt) ==="
for kv in HAVE_VFP_ARGS=1 HAVE_NEON=1 HAVE_ARMV6T2=1 HAVE_VFPV3=1 HAVE_W32THREADS=1; do
  k=${kv%=*}; want=${kv#*=}
  v=$(grep -hE "define $k( |\$)" "$B/config.h" | head -1 | awk '{print $3}'); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$want" ]; then echo "  OK    $k = $v"; else echo "  FAIL  $k = $v (want $want)"; EXTRA_FAIL=1; fi
done
[ -z "${EXTRA_FAIL:-}" ] || { echo "EXTRA GATE FAILED"; exit 1; }
echo "  info: $(grep -hE 'define (HAVE_INLINE_ASM|HAVE_THUMB|HAVE_ARMV6T2|HAVE_ARMV6|HAVE_ARMV5TE) ' "$B/config.h" | awk '{printf "%s=%s ", $2, $3}')"

echo "=== make -j2 (build.sh's environment, -j2) ==="
cd "$B" || exit 1
export PATH="$FR/cross/bin:/usr/bin:/usr/local/bin:$PATH"
export TMPDIR=. TMP="$MSYS2/tmp" TEMP="$MSYS2/tmp" NM="$RT2/llvm-nm.exe"
make -j2 > $LOGS/s0-ffmpeg-arm32$LS-make.log 2>&1
MK=$?
tail -15 $LOGS/s0-ffmpeg-arm32$LS-make.log
echo "===MAKE EXIT=$MK==="
[ $MK -eq 0 ] || exit 1

echo "=== x64 control object for verify-build ==="
mkdir -p "$FR/build/noext"
printf 'int h(void) { return 0; }\n' > "$FR/build/noext/h.c"
# dash options: this script runs without MSYS2_ARG_CONV_EXCL, which turned "/c" into "C:/" (handoff trap 15)
"$RT2/clang-cl.exe" --target=x86_64-pc-windows-msvc -nologo -c "$(cygpath -m "$FR/build/noext/h.c")" "-Fo$(cygpath -m "$FR/build/noext/h.obj")"
"$RT2/llvm-readobj.exe" --file-headers "$(cygpath -m "$FR/build/noext/h.obj")" | grep -m1 Machine

echo "=== verify-build (ffmpeg-rt, unchanged) ==="
cd "$FR" || exit 1
bash scripts/verify-build.sh > $LOGS/s0-ffmpeg-arm32$LS-verify.log 2>&1
echo "verify exit=$?"
cat $LOGS/s0-ffmpeg-arm32$LS-verify.log | grep -v '^UNREADABLE' | head -80

echo "=== build-probe (ffmpeg-rt, unchanged) ==="
bash scripts/build-probe.sh || { echo "PROBE BUILD FAILED"; exit 1; }

echo "=== h264md5 (kodi-rt) ==="
S=$FR/deps/ffmpeg-8.1.2
P=/f/kodi-rt/build/s0/h264md5-arm32-$TAG
rm -rf "$P"; mkdir -p "$P"; cd "$P" || exit 1
"$FR/cross/cc-arm32.sh" -c /f/kodi-rt/tests/stage0/h264md5/h264md5.c -Foh264md5.obj "-I$B" "-I$S" -O2 -W3 -Z7 2>&1 | head -25
[ -f h264md5.obj ] || { echo "h264md5 COMPILE FAILED"; exit 1; }
"$RT2/lld-link.exe" h264md5.obj \
  "$B/libavcodec/avcodec.lib" "$B/libavformat/avformat.lib" "$B/libavutil/avutil.lib" \
  @$FF_ROOT_W/cross/arm32-link.rsp \
  -out:h264md5.exe -subsystem:console,6.03 -osversion:6.03 -debug -pdb:h264md5.pdb \
  -defaultlib:libcmt -defaultlib:libvcruntime -defaultlib:libucrt -defaultlib:kernel32 2>&1 | head -20
[ -f h264md5.exe ] || { echo "h264md5 LINK FAILED"; exit 1; }

echo "=== collect -> $OUT ==="
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$FR/build/probe/h264probe.exe" "$P/h264md5.exe" "$P/h264md5.pdb" "$OUT/"
for d in $(find "$B" -name '*.dll'); do cp "$d" "$OUT/"; done
ls -la "$OUT"
for f in "$OUT"/*.exe "$OUT"/*.dll; do
  printf '%-22s %s\n' "$(basename "$f")" "$("$RT2/llvm-readobj.exe" --file-headers "$(cygpath -m "$f")" | grep -E '^  Machine|MajorSubsystemVersion|MinorSubsystemVersion' | tr -s ' ' | tr '\n' ' ')"
done
sha256sum "$OUT"/*
echo "end $(date '+%F %T')"
echo "S0 ARM32 DONE"
