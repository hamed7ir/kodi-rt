#!/bin/bash
# kodi-rt Stage 2: x64 REFERENCE for the decode test: FFmpeg 9.0.2 (the same Kodi-patched tree as the ARM32 build),
# static, plain C (--disable-asm), only what h264md5 needs. Then h264md5 for x64 on the clips (threads 1 and auto)
# and the --perturb control. The output is compared with Stage 0's 8.1.2 reference: H.264/HEVC decoding is
# bit-exact, so the two must be identical.
# Run with MSYS2's bash, detached, after the ARM32 build: powershell -File scripts/launch-detached.ps1 -Script <frozen>
set -u
unset MSYS2_ARG_CONV_EXCL
exec > /f/kodi-rt/logs/s2-ffmpeg-x64ref.log 2>&1
echo "start $(date '+%F %T')"
RT=F:/kodi-rt/tc/rt24b-cr/bin
X=/f/kodi-rt/cross
S=/f/kodi-rt/build/s2/ffmpeg-9.0.2-kodi
BX=/f/kodi-rt/build/s2/ffmpeg-x64ref
LOGS=/f/kodi-rt/logs
export PATH="/usr/bin:/usr/local/bin:$PATH"
export TMPDIR=. TMP=/d/MSYS2/tmp TEMP=/d/MSYS2/tmp NM="$RT/llvm-nm.exe"
rm -rf "$BX"; mkdir -p "$BX/build"; cd "$BX/build" || exit 1
"$S/configure" \
  --prefix=$BX/prefix \
  --enable-cross-compile --arch=x86_64 --target-os=win32 \
  --cc="$X/hostcc-x64.sh" --cxx="$X/hostcc-x64.sh" \
  --ld="$RT/lld-link.exe" --ar="$RT/llvm-ar.exe" --nm="$RT/llvm-nm.exe" \
  --ranlib="$RT/llvm-ranlib.exe" --strip="$RT/llvm-strip.exe" \
  --host-cc="$X/hostcc-x64.sh" --host-ld="$RT/lld-link.exe" --host-ldflags="@F:/kodi-rt/cross/x64-link.rsp" \
  --enable-static --disable-shared --disable-asm \
  --disable-everything --disable-programs --disable-doc \
  --disable-avdevice --disable-avfilter --disable-network --disable-autodetect --disable-postproc \
  --enable-decoder=h264,hevc,av1,vp8,vp9,opus,aac,flac,pcm_s16le \
  --enable-demuxers --enable-parsers --enable-bsfs --enable-protocols \
  --enable-avformat --enable-swresample \
  --extra-ldflags="@F:/kodi-rt/cross/x64-link.rsp" > $LOGS/s2-ffmpeg-x64ref-configure.log 2>&1
echo "configure exit=$?"
val () { grep -hE "define $1( |\$)" config.h config_components.h 2>/dev/null | head -1 | awk '{print $3}'; }
FAIL=0
for kv in CONFIG_STATIC=1 CONFIG_SHARED=0 ARCH_X86=0 ARCH_X86_64=0 HAVE_X86ASM=0 HAVE_SSE2_INLINE=0 HAVE_MMX_INLINE=0 \
          CONFIG_H264_DECODER=1 CONFIG_HEVC_DECODER=1 CONFIG_VP9_DECODER=1 CONFIG_MOV_DEMUXER=1 \
          CONFIG_MATROSKA_DEMUXER=1 CONFIG_MPEGTS_DEMUXER=1 CONFIG_H264_PARSER=1 CONFIG_FILE_PROTOCOL=1; do
  k=${kv%=*}; want=${kv#*=}; v=$(val $k); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$want" ]; then echo "  OK    $k = $v"; else echo "  FAIL  $k = $v (want $want)"; FAIL=$((FAIL+1)); fi
done
[ $FAIL -eq 0 ] || { echo "X64REF GATE FAILED"; exit 1; }
echo "=== make -j8 $(date '+%T')"
make -j8 > $LOGS/s2-ffmpeg-x64ref-make.log 2>&1 || { tail -20 $LOGS/s2-ffmpeg-x64ref-make.log; echo "X64REF MAKE FAILED"; exit 1; }

echo "=== h264md5 x64 $(date '+%T')"
P=$BX/h264md5
rm -rf "$P"; mkdir -p "$P"; cd "$P" || exit 1
"$X/hostcc-x64.sh" -c /f/kodi-rt/tests/stage0/h264md5/h264md5.c -Foh264md5.obj "-I$BX/build" "-I$S" -O2 -W3 2>&1 | head -20
[ -f h264md5.obj ] || { echo "h264md5 COMPILE FAILED"; exit 1; }
L=$BX/build
lib_of() { for f in "$L/$1/${1#lib}.lib" "$L/$1/$1.a" "$L/$1/$1.lib"; do [ -f "$f" ] && { echo "$f"; return; }; done; echo "MISSING-$1"; }
"$RT/lld-link.exe" h264md5.obj "$(lib_of libavformat)" "$(lib_of libavcodec)" "$(lib_of libswresample)" "$(lib_of libavutil)" \
  @F:/kodi-rt/cross/x64-link.rsp -out:h264md5.exe -subsystem:console \
  -defaultlib:libcmt -defaultlib:libvcruntime -defaultlib:libucrt -defaultlib:kernel32 \
  bcrypt.lib user32.lib ole32.lib ws2_32.lib secur32.lib 2>&1 | head -30
[ -f h264md5.exe ] || { echo "h264md5 x64 LINK FAILED"; exit 1; }

echo "=== reference decode $(date '+%T')"
C=/f/kodi-rt/build/s0/clips
CL=$(cd "$C" && ls)
cd "$C" || exit 1
"$P/h264md5.exe" --threads 1 $CL > $BX/ref-threads1.txt 2> $BX/ref-threads1.err; echo "threads1 exit=$?"
"$P/h264md5.exe" --threads 0 $CL > $BX/ref-threads0.txt 2> $BX/ref-threads0.err; echo "threads0 exit=$?"
"$P/h264md5.exe" --threads 1 --perturb $CL > $BX/ref-perturb.txt 2> /dev/null; echo "perturb exit=$?"
cmp $BX/ref-threads1.txt $BX/ref-threads0.txt && echo "threads 1 == threads auto (byte-identical)"
cmp -s $BX/ref-threads1.txt $BX/ref-perturb.txt || echo "control: --perturb output differs, as it must ($(diff $BX/ref-threads1.txt $BX/ref-perturb.txt | grep -c '^<') line(s))"
cmp $BX/ref-threads1.txt /f/kodi-rt/build/s0/ffmpeg-x64ref/ref-threads1.txt && echo "9.0.2 reference == Stage 0's 8.1.2 reference (byte-identical)"
grep -E '^clip|summary|failed|error' $BX/ref-threads1.txt | head -12
echo "end $(date '+%F %T')"
echo "S2 X64REF DONE"
