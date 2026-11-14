#!/bin/bash
# kodi-rt Stage 2: FFmpeg 9.0.2 for ARM32, STATIC, with Kodi's Windows options, built the ffmpeg-rt way with rt2.4.
#   Source: build/s2/ffmpeg-9.0.2-kodi (scripts/s2-ffmpeg-prep.sh: Kodi's Windows patch set applied).
#   Kodi's options: tools/buildsteps/windows/buildffmpeg.sh (base opts, ARM, --disable-mediafoundation) +
#   tools/depends/target/ffmpeg/win_ffmpeg_options.txt, with these differences, all from the plan's Stage 2:
#     - no --enable-openssl/--enable-nonfree (the plan: start without OpenSSL; Kodi does its own HTTPS via curl), and
#       --disable-schannel so configure does not autodetect another TLS backend instead;
#     - --disable-encoders/--disable-muxers before Kodi's encoder and muxer lists (the plan: "Kodi's encoder and muxer
#       lists"; Kodi's Windows build leaves every other encoder and muxer on, but its code uses only these);
#     - ffmpeg-rt's cross setup instead of --toolchain=msvc: clang-cl (cross/cc-arm32.sh), clang's integrated
#       assembler for the GAS NEON .S files (cross/as-arm32.sh), --enable-neon --enable-thumb;
#     - --ar=llvm-ar (FFmpeg passes GNU "rc" flags, which llvm-lib cannot take: handoff trap 11);
#     - iconv, bzlib, lzma pinned off so the Stage 3 prefix contents can't change this configuration later.
#   zlib and dav1d come from F:/kodi-rt/prefix/arm32 (scripts/s2-zlib.sh, s2-dav1d.sh).
# Run with MSYS2's bash (GNU make), detached: powershell -File scripts/launch-detached.ps1 -Script <frozen copy>
set -u
unset MSYS2_ARG_CONV_EXCL
exec > /f/kodi-rt/logs/s2-ffmpeg-arm32.log 2>&1
echo "start $(date '+%F %T')"
RT=F:/kodi-rt/tc/rt24b-cr/bin
X=/f/kodi-rt/cross
SRC=/f/kodi-rt/build/s2/ffmpeg-9.0.2-kodi
B=/f/kodi-rt/build/s2/ffmpeg-arm32
PFX=/f/kodi-rt/prefix/arm32
PFXW=F:/kodi-rt/prefix/arm32
JOBS=8
export PATH="/usr/bin:/usr/local/bin:$PATH"
"$RT/clang-cl.exe" --version | head -1
rm -rf "$B"; mkdir -p "$B"; cd "$B" || exit 1
export TMPDIR=. TMP=/d/MSYS2/tmp TEMP=/d/MSYS2/tmp
export NM="$RT/llvm-nm.exe"

"$SRC/configure" \
  --prefix="$PFX" \
  --enable-cross-compile --target-os=win32 --arch=arm \
  --cc="$X/cc-arm32.sh" --cxx="$X/cc-arm32.sh" --as="$X/as-arm32.sh" --windres="$X/windres-arm32.sh" \
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
  --extra-cflags="-I$PFXW/include -DWIN32_LEAN_AND_MEAN" \
  --extra-ldflags="@F:/kodi-rt/cross/arm32-link.rsp -libpath:$PFXW/lib"
rc=$?
echo "===CONFIGURE EXIT=$rc==="
[ $rc -eq 0 ] || { tail -40 ffbuild/config.log; echo "CONFIGURE FAILED"; exit 1; }
grep -i 'WARNING' ffbuild/config.log | sort -u | head -20

# gate: read config.h / config_components.h, not configure's summary (configure disables a component whose
# dependency is missing and still exits 0)
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
[ $FAIL -eq 0 ] || { echo "GATE FAILED ($FAIL)"; exit 1; }
echo "GATE PASSED"

echo "=== make -j$JOBS $(date '+%T')"
make -j$JOBS > /f/kodi-rt/logs/s2-ffmpeg-arm32-make.log 2>&1 || { tail -40 /f/kodi-rt/logs/s2-ffmpeg-arm32-make.log; echo "MAKE FAILED"; exit 1; }
echo "make warnings: $(grep -c 'warning:' /f/kodi-rt/logs/s2-ffmpeg-arm32-make.log)"
echo "=== make checkasm $(date '+%T')"
make -j$JOBS checkasm > /f/kodi-rt/logs/s2-ffmpeg-arm32-checkasm.log 2>&1 || { tail -30 /f/kodi-rt/logs/s2-ffmpeg-arm32-checkasm.log; echo "CHECKASM BUILD FAILED"; exit 1; }
ls -la tests/checkasm/checkasm.exe
echo "=== make install $(date '+%T')"
make install > /f/kodi-rt/logs/s2-ffmpeg-arm32-install.log 2>&1 || { tail -20 /f/kodi-rt/logs/s2-ffmpeg-arm32-install.log; echo "INSTALL FAILED"; exit 1; }
ls -la "$PFX/lib"/*.lib
echo "FFMPEG DONE $(date '+%F %T')"
