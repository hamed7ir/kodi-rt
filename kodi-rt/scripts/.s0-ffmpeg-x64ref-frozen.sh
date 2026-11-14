#!/bin/bash
# kodi-rt Stage 0: x64 REFERENCE FFmpeg 8.1.2 for h264md5 -- static, C only (--disable-asm), the same decoders,
# demuxers, parsers and bsfs as ffmpeg-rt's ARM32 configure line. Same pinned source tree (out-of-tree build).
# H.264/HEVC/VP9 decoding is bit-exact, so this build's frame MD5s are the expected output for the ARM32 device run.
# Then: builds h264md5 for x64, runs it on the clips (threads 1 and auto), and the --perturb control.
# Run with MSYS2's bash (GNU make), detached, after the ARM32 build (never two -j2 builds at once).
# Argument md5only: skip configure/make (a finished build is in place) and redo only the h264md5 part.
MODE=${1:-full}
if [ "$MODE" = md5only ]; then exec > /f/kodi-rt/logs/s0-ffmpeg-x64ref-md5.log 2>&1; else exec > /f/kodi-rt/logs/s0-ffmpeg-x64ref.log 2>&1; fi
set -u
echo "start $(date '+%F %T') mode=$MODE"
export RT2=F:/cr/rt22-cr/bin
FR=/f/kodi-rt/src/ffmpeg-rt
export FF_ROOT=$FR
. "$FR/config.sh"
rt_check_config || exit 1
X=$FR/cross
S=$FR/deps/ffmpeg-8.1.2
BX=/f/kodi-rt/build/s0/ffmpeg-x64ref
LOGS=/f/kodi-rt/logs
[ -f "$FR/cross/x64-link.rsp" ] || sh "$FR/scripts/gen-rsp.sh" || exit 1
export PATH="$FR/cross/bin:/usr/bin:/usr/local/bin:$PATH"
export TMPDIR=. TMP="$MSYS2/tmp" TEMP="$MSYS2/tmp" NM="$RT2/llvm-nm.exe"
if [ "$MODE" != md5only ]; then
rm -rf "$BX"; mkdir -p "$BX/build"; cd "$BX/build" || exit 1
"$S/configure" \
  --prefix=$BX/prefix \
  --enable-cross-compile --arch=x86_64 --target-os=win32 \
  --cc="$X/hostcc-x64.sh" --cxx="$X/hostcc-x64.sh" \
  --ld="$RT2/lld-link.exe" --ar="$RT2/llvm-ar.exe" --nm="$RT2/llvm-nm.exe" \
  --ranlib="$RT2/llvm-ranlib.exe" --strip="$RT2/llvm-strip.exe" \
  --host-cc="$X/hostcc-x64.sh" --host-ld="$RT2/lld-link.exe" \
  --host-ldflags="@$FF_ROOT_W/cross/x64-link.rsp" \
  --enable-static --disable-shared --disable-asm \
  --disable-everything --disable-programs --disable-doc \
  --disable-avdevice --disable-avfilter --disable-network --disable-autodetect \
  --enable-decoder=h264,hevc,av1,vp8,vp9,opus,aac,flac,pcm_s16le \
  --enable-demuxers --enable-parsers --enable-bsfs --enable-protocols \
  --enable-avformat --enable-swresample \
  --extra-ldflags="@$FF_ROOT_W/cross/x64-link.rsp" > $LOGS/s0-ffmpeg-x64ref-configure.log 2>&1
echo "configure exit=$?"
tail -3 $LOGS/s0-ffmpeg-x64ref-configure.log
val () { grep -hE "define $1( |\$)" config.h config_components.h 2>/dev/null | head -1 | awk '{print $3}'; }
FAIL=0
# plain C: --disable-asm sets arch=c (ARCH_X86* 0, every HAVE_*_INLINE 0); HAVE_INLINE_ASM=1 only says the compiler can
for kv in CONFIG_STATIC=1 CONFIG_SHARED=0 ARCH_X86=0 ARCH_X86_64=0 HAVE_X86ASM=0 HAVE_SSE2_INLINE=0 HAVE_MMX_INLINE=0 \
          CONFIG_H264_DECODER=1 CONFIG_HEVC_DECODER=1 \
          CONFIG_VP9_DECODER=1 CONFIG_MOV_DEMUXER=1 CONFIG_MATROSKA_DEMUXER=1 CONFIG_MPEGTS_DEMUXER=1 CONFIG_H264_PARSER=1 \
          CONFIG_FILE_PROTOCOL=1; do
  k=${kv%=*}; want=${kv#*=}; v=$(val $k); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$want" ]; then echo "  OK    $k = $v"; else echo "  FAIL  $k = $v (want $want)"; FAIL=$((FAIL+1)); fi
done
[ $FAIL -eq 0 ] || { echo "X64REF GATE FAILED"; exit 1; }
echo "=== make -j2 ==="
make -j2 > $LOGS/s0-ffmpeg-x64ref-make.log 2>&1
MK=$?
tail -5 $LOGS/s0-ffmpeg-x64ref-make.log
echo "===MAKE EXIT=$MK==="
[ $MK -eq 0 ] || exit 1
find . \( -name '*.a' -o -name '*.lib' \) -printf '%10s  %p\n' | sort -k2
fi

echo "=== h264md5 x64 ==="
P=$BX/h264md5
rm -rf "$P"; mkdir -p "$P"; cd "$P" || exit 1
"$X/hostcc-x64.sh" -c /f/kodi-rt/tests/stage0/h264md5/h264md5.c -Foh264md5.obj "-I$BX/build" "-I$S" -O2 -W3 2>&1 | head -20
[ -f h264md5.obj ] || { echo "h264md5 COMPILE FAILED"; exit 1; }
L=$BX/build
# this configuration names them libavcodec/avcodec.lib (measured); the other spellings are kept as fallbacks
lib_of() { for f in "$L/$1/${1#lib}.lib" "$L/$1/$1.a" "$L/$1/$1.lib"; do [ -f "$f" ] && { echo "$f"; return; }; done; echo "MISSING-$1"; }
"$RT2/lld-link.exe" h264md5.obj "$(lib_of libavformat)" "$(lib_of libavcodec)" "$(lib_of libswresample)" "$(lib_of libavutil)" \
  @$FF_ROOT_W/cross/x64-link.rsp -out:h264md5.exe -subsystem:console \
  -defaultlib:libcmt -defaultlib:libvcruntime -defaultlib:libucrt -defaultlib:kernel32 \
  bcrypt.lib user32.lib ole32.lib ws2_32.lib secur32.lib 2>&1 | head -30
[ -f h264md5.exe ] || { echo "h264md5 x64 LINK FAILED"; exit 1; }

echo "=== reference decode ==="
C=/f/kodi-rt/build/s0/clips
CL=$(cd "$C" && ls)
cd "$C" || exit 1
"$P/h264md5.exe" --threads 1 $CL > $BX/ref-threads1.txt 2> $BX/ref-threads1.err; echo "threads1 exit=$?"
"$P/h264md5.exe" --threads 0 $CL > $BX/ref-threads0.txt 2> $BX/ref-threads0.err; echo "threads0 exit=$?"
"$P/h264md5.exe" --threads 1 --perturb $CL > $BX/ref-perturb.txt 2> /dev/null; echo "perturb exit=$?"
cmp $BX/ref-threads1.txt $BX/ref-threads0.txt && echo "threads 1 == threads auto (byte-identical)"
cmp -s $BX/ref-threads1.txt $BX/ref-perturb.txt || echo "control: --perturb output differs, as it must ($(diff $BX/ref-threads1.txt $BX/ref-perturb.txt | grep -c '^<') line(s))"
cat $BX/ref-threads1.txt | grep -E '^clip|codec=|frames=|summary|failed|error'
cat $BX/ref-threads1.err
echo "end $(date '+%F %T')"
echo "S0 X64REF DONE"
