#!/bin/bash
# kodi-rt Stage 9: FFmpeg 9.0.2 for desktop Windows x64 or x86 (cross/arch.sh: ARCH=x64 or ARCH=x86), STATIC, with
# Kodi's Windows options: the x86 twin of scripts/s2-ffmpeg-arm32.sh (its comments explain the option choices), from
# the release source build/s7/ffmpeg-src (Kodi's Windows patch set applied), with these differences:
#   - --arch=x86_64 with target-os win64, or --arch=x86 --cpu=i686 with win32, as Kodi's buildffmpeg.sh;
#   - the x86 SIMD (nasm assembly) with tools/nasm (Kodi's pinned nasm 2.15.05, scripts/s9-nasm.sh; Hamed's OK
#     2026-11-13), plus FFmpeg's GCC-style inline assembly, which clang-cl compiles (Kodi's own Windows builds have no
#     inline assembly, since MSVC has none). Without tools/nasm (A_ASM=no): --disable-x86asm.
#   - cross/cc-$ARCH.sh and cross/$ARCH-target-link.rsp: rt2.4 f6e5f8e0, SDK 10.0.26100.0, /MT. No PGO (the profile is
#     an ARM32 device profile), no LTO.
#   - with the assembly, tests/checkasm/checkasm.exe is built and run right here (the server runs x64 and x86 code).
# zlib and dav1d come from F:/kodi-rt/prefix/$ARCH (scripts/s9-prefix.sh); FFmpeg is installed there too.
# Run with MSYS2's bash (GNU make), detached for a full build: ARCH=x64 bash /f/kodi-rt/scripts/s9-ffmpeg.sh
# Log: logs/s9-ffmpeg-$ARCH.log (make output: logs/s9-ffmpeg-$ARCH-make.log).
# CFGONLY=1: configure and gate only, in build/s9/ffmpeg-$ARCH-cfgtest (log logs/s9-ffmpeg-$ARCH-cfgtest.log).
set -u
source /f/kodi-rt/cross/arch.sh
unset MSYS2_ARG_CONV_EXCL
case $ARCH in
  x64) FFARCH="--arch=x86_64 --target-os=win64"; GATEARCH="ARCH_X86_64=1 ARCH_X86_32=0" ;;
  x86) FFARCH="--arch=x86 --cpu=i686 --target-os=win32"; GATEARCH="ARCH_X86_32=1 ARCH_X86_64=0" ;;
  *) echo "s9-ffmpeg.sh is for x64/x86"; exit 1 ;;
esac
if [ $A_ASM = yes ]; then X86ASM="--x86asmexe=$A_NASM"; WANTASM=1; else X86ASM="--disable-x86asm"; WANTASM=0; fi
SUF=""; [ "${CFGONLY:-0}" = 1 ] && SUF=-cfgtest
L=/f/kodi-rt/logs/s9-ffmpeg-$ARCH$SUF
exec > $L.log 2>&1
echo "start $(date '+%F %T') ($ARCH)"
RT=$A_RT/bin
X=/f/kodi-rt/cross
SRC=/f/kodi-rt/build/s7/ffmpeg-src
B=/f/kodi-rt/build/s9/ffmpeg-$ARCH$SUF
PFX=/f/kodi-rt/prefix/$ARCH
PFXW=$A_PFX
JOBS=${JOBS:-8}
export PATH="/usr/bin:/usr/local/bin:$PATH"
"$RT/clang-cl.exe" --version | head -1
for f in z.lib libdav1d.lib; do [ -f "$PFX/lib/$f" ] || { echo "no $PFX/lib/$f (scripts/s9-prefix.sh)"; exit 1; }; done
rm -rf "$B"; mkdir -p "$B"; cd "$B" || exit 1
export TMPDIR=. TMP=/d/MSYS2/tmp TEMP=/d/MSYS2/tmp
export NM="$RT/llvm-nm.exe"

"$SRC/configure" \
  --prefix="$PFX" \
  --enable-cross-compile $FFARCH \
  --cc="$X/cc-$ARCH.sh" --cxx="$X/cc-$ARCH.sh" --windres="$X/windres-$ARCH.sh" \
  --ld="$RT/lld-link.exe" --ar="$RT/llvm-ar.exe" --nm="$RT/llvm-nm.exe" \
  --ranlib="$RT/llvm-ranlib.exe" --strip="$RT/llvm-strip.exe" \
  --host-cc="$X/hostcc-x64.sh" --host-ld="$RT/lld-link.exe" --host-ldflags="@F:/kodi-rt/cross/x64-link.rsp" \
  $X86ASM \
  --enable-static --disable-shared \
  --disable-debug --disable-doc --enable-gpl --enable-w32threads \
  --disable-avdevice --disable-cuda --disable-cuvid --disable-devices --disable-dxva2 --disable-filter=gfxcapture \
  --disable-gnutls --disable-muxer=whip --disable-nvenc --disable-openssl --disable-programs \
  --disable-encoders --enable-encoder=ac3,eac3,aac,wmav2,png,mjpeg \
  --disable-muxers --enable-muxer=spdif,adts,asf,ipod \
  --enable-protocol=http --enable-runtime-cpudetect --enable-zlib --enable-libdav1d --extra-version=Kodi \
  --disable-mediafoundation --disable-schannel --disable-iconv --disable-bzlib --disable-lzma \
  --extra-cflags="-I$PFXW/include -DWIN32_LEAN_AND_MEAN" \
  --extra-ldflags="@F:/kodi-rt/cross/$ARCH-target-link.rsp -libpath:$PFXW/lib"
rc=$?
echo "===CONFIGURE EXIT=$rc==="
[ $rc -eq 0 ] || { tail -40 ffbuild/config.log; echo "CONFIGURE FAILED"; exit 1; }
grep -i 'WARNING' ffbuild/config.log | sort -u | head -20

# gate: read config.h / config_components.h, not configure's summary (see s2-ffmpeg-arm32.sh)
H=config.h; C=config_components.h
val () { grep -hE "define $1( |\$)" "$H" "$C" 2>/dev/null | head -1 | awk '{print $3}'; }
FAIL=0
for kv in $GATEARCH HAVE_X86ASM=$WANTASM HAVE_W32THREADS=1 \
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
echo "inline asm: HAVE_INLINE_ASM=$(val HAVE_INLINE_ASM), HAVE_MMX_INLINE=$(val HAVE_MMX_INLINE), HAVE_SSE2_INLINE=$(val HAVE_SSE2_INLINE)"
[ $FAIL -eq 0 ] || { echo "GATE FAILED ($FAIL)"; exit 1; }
echo "GATE PASSED"
[ "${CFGONLY:-0}" = 1 ] && { echo "CONFIGURE-ONLY DONE $(date '+%F %T')"; exit 0; }

echo "=== make -j$JOBS $(date '+%T')"
make -j$JOBS > $L-make.log 2>&1 || { tail -40 $L-make.log; echo "MAKE FAILED"; exit 1; }
echo "make warnings: $(grep -c 'warning:' $L-make.log)"
if [ $WANTASM = 1 ]; then
  echo "=== make checkasm $(date '+%T')"
  make -j$JOBS checkasm > $L-checkasm-build.log 2>&1 || { tail -30 $L-checkasm-build.log; echo "CHECKASM BUILD FAILED"; exit 1; }
  ./tests/checkasm/checkasm.exe > $L-checkasm.log 2>&1; rc=$?
  tail -3 $L-checkasm.log
  [ $rc = 0 ] || { echo "CHECKASM FAILED (rc $rc, $L-checkasm.log)"; exit 1; }
fi
echo "=== make install $(date '+%T')"
make install > $L-install.log 2>&1 || { tail -20 $L-install.log; echo "INSTALL FAILED"; exit 1; }
ls -la "$PFX/lib"/av*.lib "$PFX/lib"/sw*.lib "$PFX/lib"/postproc.lib
echo "FFMPEG DONE $(date '+%F %T')"
