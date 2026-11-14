#!/bin/bash
# kodi-rt PGO phase 1: INSTRUMENTED FFmpeg 9.0.2 for ARM32 (static), for the instrumented Kodi (scripts/s7-configure.sh).
#   The same configuration as scripts/s2-ffmpeg-arm32.sh (Kodi's options, NEON, the 10-bit MC patch), with:
#   - source: build/s7/ffmpeg-src, a frozen copy of build/s2/ffmpeg-9.0.2-kodi (2026-11-13, NEON patch 0001 applied),
#     so phase 2 (-fprofile-use) compiles exactly the code the profile counted;
#   - rt2.4 0318206a (tc/rt24c-cr) for C, assembly and the tools, IR instrumentation in the compiler wrapper
#     (cross/cc-arm32-pgoinstr.sh);
#   - the clang runtime folder on the link path (configure's link tests need clang_rt.profile-arm.lib);
#   - installed to prefix/arm32-ffinstr (prefix/arm32 keeps the normal libraries); zlib and dav1d still come from
#     prefix/arm32; no checkasm.
# Run with MSYS2's bash (GNU make), detached: powershell -File scripts/launch-detached.ps1 -Script <this script>
set -u
unset MSYS2_ARG_CONV_EXCL
exec > /f/kodi-rt/logs/s7-ffmpeg-instr.log 2>&1
echo "start $(date '+%F %T')"
RT=F:/kodi-rt/tc/rt24c-cr/bin
CRT=F:/kodi-rt/tc/rt24c-cr/lib/clang/23/lib/windows
X=/f/kodi-rt/cross
SRC=/f/kodi-rt/build/s7/ffmpeg-src
B=/f/kodi-rt/build/s7/ffmpeg-arm32-instr
PFX=/f/kodi-rt/prefix/arm32-ffinstr
DEPW=F:/kodi-rt/prefix/arm32
JOBS=${JOBS:-7}
export PATH="/usr/bin:/usr/local/bin:$PATH"
"$RT/clang-cl.exe" --version | head -1
[ -f "$CRT/clang_rt.profile-arm.lib" ] || { echo "no $CRT/clang_rt.profile-arm.lib"; exit 1; }
rm -rf "$B"; mkdir -p "$B"; cd "$B" || exit 1
export TMPDIR=. TMP=/d/MSYS2/tmp TEMP=/d/MSYS2/tmp
export NM="$RT/llvm-nm.exe"

"$SRC/configure" \
  --prefix="$PFX" \
  --enable-cross-compile --target-os=win32 --arch=arm \
  --cc="$X/cc-arm32-pgoinstr.sh" --cxx="$X/cc-arm32-pgoinstr.sh" --as="$X/as-arm32-rt24c.sh" \
  --windres="$X/windres-arm32.sh" \
  --ld="$RT/lld-link.exe" --ar="$RT/llvm-ar.exe" --nm="$RT/llvm-nm.exe" \
  --ranlib="$RT/llvm-ranlib.exe" --strip="$RT/llvm-strip.exe" \
  --host-cc="$X/hostcc-x64.sh" --host-ld="$RT/lld-link.exe" --host-ldflags="@F:/kodi-rt/cross/x64-link.rsp" \
  --enable-asm --enable-neon --enable-thumb \
  --enable-static --disable-shared \
  --disable-debug --disable-doc --enable-gpl --enable-w32threads \
  --disable-avdevice --disable-cuda --disable-cuvid --disable-devices --disable-dxva2 --disable-filter=gfxcapture \
  --disable-gnutls --disable-muxer=whip --disable-nvenc --disable-openssl --disable-programs \
  --disable-encoders --enable-encoder=ac3,eac3,aac,wmav2,png,mjpeg \
  --disable-muxers --enable-muxer=spdif,adts,asf,ipod \
  --enable-protocol=http --enable-runtime-cpudetect --enable-zlib --enable-libdav1d --extra-version=Kodi \
  --disable-mediafoundation --disable-schannel --disable-iconv --disable-bzlib --disable-lzma \
  --extra-cflags="-I$DEPW/include -DWIN32_LEAN_AND_MEAN" \
  --extra-ldflags="@F:/kodi-rt/cross/arm32-link.rsp -libpath:$DEPW/lib -libpath:$CRT"
rc=$?
echo "===CONFIGURE EXIT=$rc==="
[ $rc -eq 0 ] || { tail -40 ffbuild/config.log; echo "CONFIGURE FAILED"; exit 1; }
grep -i 'WARNING' ffbuild/config.log | sort -u | head -20

# gate: the s2 list (read config.h / config_components.h, not configure's summary)
H=config.h; C=config_components.h
val () { grep -hE "define $1( |\$)" "$H" "$C" 2>/dev/null | head -1 | awk '{print $3}'; }
FAIL=0
for kv in ARCH_ARM=1 HAVE_NEON=1 HAVE_VFP_ARGS=1 HAVE_ARMV6T2=1 CONFIG_THUMB=1 HAVE_W32THREADS=1 \
          CONFIG_STATIC=1 CONFIG_SHARED=0 CONFIG_GPL=1 CONFIG_NONFREE=0 CONFIG_RUNTIME_CPUDETECT=1 \
          CONFIG_ZLIB=1 CONFIG_LIBDAV1D=1 CONFIG_D3D11VA=1 CONFIG_DXVA2=0 CONFIG_MEDIAFOUNDATION=0 \
          CONFIG_OPENSSL=0 CONFIG_SCHANNEL=0 CONFIG_GNUTLS=0 CONFIG_ICONV=0 \
          CONFIG_AVFILTER=1 CONFIG_SWSCALE=1 CONFIG_SWRESAMPLE=1 CONFIG_POSTPROC=1 CONFIG_AVDEVICE=0 \
          CONFIG_H264_DECODER=1 CONFIG_HEVC_DECODER=1 CONFIG_VP9_DECODER=1 CONFIG_AV1_DECODER=1 \
          CONFIG_LIBDAV1D_DECODER=1 CONFIG_MPEG2VIDEO_DECODER=1 CONFIG_VC1_DECODER=1 CONFIG_PNG_DECODER=1 \
          CONFIG_AC3_DECODER=1 CONFIG_EAC3_DECODER=1 CONFIG_DCA_DECODER=1 CONFIG_TRUEHD_DECODER=1 \
          CONFIG_AAC_DECODER=1 CONFIG_FLAC_DECODER=1 CONFIG_OPUS_DECODER=1 CONFIG_VORBIS_DECODER=1 \
          CONFIG_ASS_DECODER=1 CONFIG_PGSSUB_DECODER=1 \
          CONFIG_AC3_ENCODER=1 CONFIG_EAC3_ENCODER=1 CONFIG_AAC_ENCODER=1 CONFIG_WMAV2_ENCODER=1 \
          CONFIG_PNG_ENCODER=1 CONFIG_MJPEG_ENCODER=1 CONFIG_MPEG4_ENCODER=0 \
          CONFIG_SPDIF_MUXER=1 CONFIG_ADTS_MUXER=1 CONFIG_ASF_MUXER=1 CONFIG_IPOD_MUXER=1 CONFIG_MP4_MUXER=0 \
          CONFIG_MOV_DEMUXER=1 CONFIG_MATROSKA_DEMUXER=1 CONFIG_MPEGTS_DEMUXER=1 CONFIG_AVI_DEMUXER=1 \
          CONFIG_HLS_DEMUXER=1 CONFIG_HTTP_PROTOCOL=1 CONFIG_HTTPS_PROTOCOL=0 \
          CONFIG_H264_PARSER=1 CONFIG_HEVC_PARSER=1 CONFIG_AV1_PARSER=1 CONFIG_YADIF_FILTER=1 CONFIG_PP_FILTER=1; do
  k=${kv%=*}; want=${kv#*=}; v=$(val $k); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$want" ]; then echo "  OK    $k = $v"; else echo "  FAIL  $k = $v (want $want)"; FAIL=$((FAIL+1)); fi
done
echo "inline asm: HAVE_INLINE_ASM=$(val HAVE_INLINE_ASM), HAVE_NEON_INLINE=$(val HAVE_NEON_INLINE)"
# the configuration must equal the normal build's, apart from paths and the toolchain
for f in config.h config_components.h; do
  if diff <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' $f) \
          <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' /f/kodi-rt/build/s2/ffmpeg-arm32/$f) > /dev/null; then
    echo "  OK    $f equals build/s2/ffmpeg-arm32/$f (paths and compiler ident aside)"
  else
    echo "  NOTE  $f differs from build/s2/ffmpeg-arm32/$f:"
    diff <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' $f) \
         <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' /f/kodi-rt/build/s2/ffmpeg-arm32/$f) | head -20
  fi
done
[ $FAIL -eq 0 ] || { echo "GATE FAILED ($FAIL)"; exit 1; }
echo "GATE PASSED"

echo "=== make -j$JOBS $(date '+%T')"
make -j$JOBS > /f/kodi-rt/logs/s7-ffmpeg-instr-make.log 2>&1 || { tail -40 /f/kodi-rt/logs/s7-ffmpeg-instr-make.log; echo "MAKE FAILED"; exit 1; }
echo "make warnings: $(grep -c 'warning:' /f/kodi-rt/logs/s7-ffmpeg-instr-make.log)"
echo "=== make install $(date '+%T')"
make install > /f/kodi-rt/logs/s7-ffmpeg-instr-install.log 2>&1 || { tail -20 /f/kodi-rt/logs/s7-ffmpeg-instr-install.log; echo "INSTALL FAILED"; exit 1; }
ls -la "$PFX/lib"/*.lib
# every library must carry profile counters (IR instrumentation: __profc_* symbols, most of them local .L__profc_*;
# the first run's check counted only the external ones and stopped on postproc.lib, whose 32 are all local)
for l in avcodec avfilter avformat avutil postproc swresample swscale; do
  n=$("$RT/llvm-nm.exe" "$PFX/lib/$l.lib" 2>/dev/null | grep -c '__profc_')
  echo "  $l.lib: $n __profc_ symbols"
  [ "$n" -gt 0 ] || { echo "NOT INSTRUMENTED: $l.lib"; exit 1; }
done
echo "FFMPEG INSTR DONE $(date '+%F %T')"
