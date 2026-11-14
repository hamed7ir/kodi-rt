#!/bin/bash
# kodi-rt PGO phase 2: FFmpeg 9.0.2 for ARM32 (static) with the device profile and ThinLTO, for the PGO Kodi
# (scripts/s7-configure.sh PHASE=use).
#   The same configuration as scripts/s2-ffmpeg-arm32.sh / s7-ffmpeg-instr.sh, with:
#   - the same frozen source build/s7/ffmpeg-src as phase 1 (the profile names static functions by source path);
#   - rt2.4 f6e5f8e0 (tc/rt24d-cr) and cross/cc-arm32-pgouse.sh (-fprofile-use, -flto=thin, -pgso=false): the C
#     objects are bitcode, the NEON .S objects native; lld-link compiles the bitcode when it links kodi.exe;
#   - installed to prefix/arm32-ffpgo.
#   Gate as s2's, plus config.h/config_components.h equal to s2's apart from paths: under -flto, configure's
#   compile-only inline-asm tests cannot fail (inline asm in bitcode is assembled at link time), so this comparison
#   is what shows the configuration did not change. Then: every library holds bitcode.
# Run with MSYS2's bash (GNU make), detached: powershell -File scripts/launch-detached.ps1 -Script <this script>
set -u
unset MSYS2_ARG_CONV_EXCL
exec > /f/kodi-rt/logs/s7-ffmpeg-pgo.log 2>&1
echo "start $(date '+%F %T')"
RT=F:/kodi-rt/tc/rt24d-cr/bin
X=/f/kodi-rt/cross
SRC=/f/kodi-rt/build/s7/ffmpeg-src
B=/f/kodi-rt/build/s7/ffmpeg-arm32-pgo
PFX=/f/kodi-rt/prefix/arm32-ffpgo
DEPW=F:/kodi-rt/prefix/arm32
PROF=F:/kodi-rt/build/s7/prof/kodi-20261113.profdata
JOBS=${JOBS:-8}
export PATH="/usr/bin:/usr/local/bin:$PATH"
"$RT/clang-cl.exe" --version | head -1
[ -f "$PROF" ] || { echo "no $PROF"; exit 1; }
rm -rf "$B"; mkdir -p "$B"; cd "$B" || exit 1
export TMPDIR=. TMP=/d/MSYS2/tmp TEMP=/d/MSYS2/tmp
export NM="$RT/llvm-nm.exe"

"$SRC/configure" \
  --prefix="$PFX" \
  --enable-cross-compile --target-os=win32 --arch=arm \
  --cc="$X/cc-arm32-pgouse.sh" --cxx="$X/cc-arm32-pgouse.sh" --as="$X/as-arm32-rt24d.sh" \
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
  --extra-ldflags="@F:/kodi-rt/cross/arm32-link.rsp -libpath:$DEPW/lib"
rc=$?
echo "===CONFIGURE EXIT=$rc==="
[ $rc -eq 0 ] || { tail -40 ffbuild/config.log; echo "CONFIGURE FAILED"; exit 1; }
grep -i 'WARNING' ffbuild/config.log | sort -u | head -20

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
for f in config.h config_components.h; do
  if diff <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' $f) \
          <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' /f/kodi-rt/build/s2/ffmpeg-arm32/$f) > /dev/null; then
    echo "  OK    $f equals build/s2/ffmpeg-arm32/$f (paths and compiler ident aside)"
  else
    echo "  FAIL  $f differs from build/s2/ffmpeg-arm32/$f:"
    diff <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' $f) \
         <(grep -vE 'FFMPEG_CONFIGURATION|CC_IDENT|FFMPEG_DATADIR|AVCONV_DATADIR|LICENSE' /f/kodi-rt/build/s2/ffmpeg-arm32/$f) | head -20
    FAIL=$((FAIL+1))
  fi
done
[ $FAIL -eq 0 ] || { echo "GATE FAILED ($FAIL)"; exit 1; }
echo "GATE PASSED"

echo "=== make -j$JOBS $(date '+%T')"
make -j$JOBS > /f/kodi-rt/logs/s7-ffmpeg-pgo-make.log 2>&1 || { tail -40 /f/kodi-rt/logs/s7-ffmpeg-pgo-make.log; echo "MAKE FAILED"; exit 1; }
echo "make warnings: $(grep -c 'warning:' /f/kodi-rt/logs/s7-ffmpeg-pgo-make.log)"
echo "=== make install $(date '+%T')"
make install > /f/kodi-rt/logs/s7-ffmpeg-pgo-install.log 2>&1 || { tail -20 /f/kodi-rt/logs/s7-ffmpeg-pgo-install.log; echo "INSTALL FAILED"; exit 1; }
ls -la "$PFX/lib"/*.lib
# every library must hold bitcode (ThinLTO): count members that start with the bitcode magic BC C0 DE
T=$B/bccheck; mkdir -p "$T"
for l in avcodec avfilter avformat avutil postproc swresample swscale; do
  rm -rf "$T"/*; ( cd "$T" && "$RT/llvm-ar.exe" x "$PFX/lib/$l.lib" ) || { echo "llvm-ar x $l failed"; exit 1; }
  nbc=0; nall=0
  for o in "$T"/*; do nall=$((nall+1)); [ "$(head -c 4 "$o" | od -An -tx1 | tr -d ' \n')" = "4243c0de" ] && nbc=$((nbc+1)); done
  echo "  $l.lib: $nbc of $nall members are bitcode"
  [ "$nbc" -gt 0 ] || { echo "NO BITCODE: $l.lib"; exit 1; }
done
echo "FFMPEG PGO DONE $(date '+%F %T')"
