#!/bin/bash
# kodi-rt Stage 10: the FFmpeg that inputstream.ffmpegdirect links (statically, into its DLL), ARM32, into
# prefix/arm32-ffmpegdirect. The add-on opens streams with FFmpeg's own protocols (HLS, HTTPS, RTMP, RTSP, UDP),
# so unlike Kodi's FFmpeg (scripts/s2-ffmpeg-arm32.sh: no TLS, Kodi does HTTPS through curl) this one has OpenSSL.
# Same source (build/s2/ffmpeg-9.0.2-kodi: FFmpeg 9.0.2, the version the add-on requires, with Kodi's Windows
# patches) and the same cross setup and Kodi option lists, with these differences, after the add-on's own Windows
# build (depends/common/ffmpeg/CMakeLists.txt):
#   - --enable-openssl --enable-version3: GPLv3 with OpenSSL 3 (Apache-2.0) is redistributable; the add-on's own
#     build uses --enable-nonfree instead, which is not
#   - --enable-libxml2 (FFmpeg's DASH demuxer), --enable-bzlib --enable-iconv: what the add-on links on Windows;
#     lzma stays off (it doesn't link it)
#   - no dav1d and no hardware decoding (d3d11va/dxva2/hwaccels): the add-on only demuxes, Kodi decodes
#   - no checkasm: the same source and NEON code as Kodi's FFmpeg, checked there
#   - pkg-config: this server has none, and FFmpeg finds OpenSSL (its GPL version check) and libxml2 only through it,
#     so cross/pkg-config-arm32-ffmpegdirect.sh stands in for exactly those two
# OpenSSL, zlib and iconv come from prefix/arm32, libxml2 and bzip2 from prefix/arm32-addons (s10-addon-deps.sh).
# Run with MSYS2's bash (GNU make), detached: powershell -File scripts/launch-detached.ps1 -Script <frozen copy>
set -u
unset MSYS2_ARG_CONV_EXCL
exec > /f/kodi-rt/logs/s10-ffmpeg-arm32.log 2>&1
echo "start $(date '+%F %T')"
LANE=/f/kodi-rt/logs/s9-lane.status
echo "LANE original FFmpeg for inputstream.ffmpegdirect (arm32) since $(date '+%F %T')" > $LANE
trap 'echo "LANE FREE since $(date "+%F %T")" > $LANE' EXIT
RT=F:/kodi-rt/tc/rt24b-cr/bin
X=/f/kodi-rt/cross
SRC=/f/kodi-rt/build/s2/ffmpeg-9.0.2-kodi
B=/f/kodi-rt/build/s10/ffmpeg-arm32
PFX=/f/kodi-rt/prefix/arm32-ffmpegdirect
PFXW=F:/kodi-rt/prefix/arm32
ADDW=F:/kodi-rt/prefix/arm32-addons
JOBS=8
export PATH="/usr/bin:/usr/local/bin:$PATH"
"$RT/clang-cl.exe" --version | head -1
rm -rf "$B" "$PFX"; mkdir -p "$B"; cd "$B" || exit 1
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
  --disable-debug --disable-doc --enable-gpl --enable-version3 --enable-w32threads \
  --disable-avdevice --disable-cuda --disable-cuvid --disable-devices --disable-dxva2 --disable-d3d11va \
  --disable-d3d12va --disable-hwaccels --disable-filter=gfxcapture \
  --disable-gnutls --disable-muxer=whip --disable-nvenc --enable-openssl --disable-programs \
  --disable-encoders --enable-encoder=ac3,eac3,aac,wmav2,png,mjpeg \
  --disable-muxers --enable-muxer=spdif,adts,asf,ipod \
  --enable-runtime-cpudetect --enable-zlib --enable-bzlib --enable-iconv --disable-libdav1d \
  --extra-version=kodi-rt-ffmpegdirect \
  --disable-mediafoundation --disable-schannel --disable-lzma --enable-libxml2 \
  --pkg-config=/f/kodi-rt/cross/pkg-config-arm32-ffmpegdirect.sh \
  --extra-cflags="-I$PFXW/include -I$ADDW/include -DWIN32_LEAN_AND_MEAN" \
  --extra-ldflags="@F:/kodi-rt/cross/arm32-link.rsp -libpath:$PFXW/lib -libpath:$ADDW/lib" \
  --extra-libs="crypt32.lib advapi32.lib bcrypt.lib ws2_32.lib user32.lib"
rc=$?
echo "===CONFIGURE EXIT=$rc==="
[ $rc -eq 0 ] || { tail -40 ffbuild/config.log; echo "CONFIGURE FAILED"; exit 1; }
grep -i 'WARNING' ffbuild/config.log | sort -u | head -20

# gate: read config.h / config_components.h, not configure's summary
H=config.h; C=config_components.h
val () { grep -hE "define $1( |\$)" "$H" "$C" 2>/dev/null | head -1 | awk '{print $3}'; }
FAIL=0
for kv in ARCH_ARM=1 HAVE_NEON=1 HAVE_ARMV6T2=1 CONFIG_THUMB=1 HAVE_W32THREADS=1 \
          CONFIG_STATIC=1 CONFIG_SHARED=0 CONFIG_GPL=1 CONFIG_VERSION3=1 CONFIG_NONFREE=0 \
          CONFIG_OPENSSL=1 CONFIG_SCHANNEL=0 CONFIG_GNUTLS=0 CONFIG_ZLIB=1 CONFIG_BZLIB=1 CONFIG_ICONV=1 \
          CONFIG_LZMA=0 CONFIG_LIBXML2=1 CONFIG_DASH_DEMUXER=1 CONFIG_LIBDAV1D=0 CONFIG_D3D11VA=0 CONFIG_DXVA2=0 CONFIG_MEDIAFOUNDATION=0 \
          CONFIG_HTTP_PROTOCOL=1 CONFIG_HTTPS_PROTOCOL=1 CONFIG_TLS_PROTOCOL=1 CONFIG_TCP_PROTOCOL=1 \
          CONFIG_UDP_PROTOCOL=1 CONFIG_RTMP_PROTOCOL=1 CONFIG_RTMPS_PROTOCOL=1 \
          CONFIG_HLS_DEMUXER=1 CONFIG_MPEGTS_DEMUXER=1 CONFIG_RTSP_DEMUXER=1 CONFIG_MOV_DEMUXER=1 \
          CONFIG_MATROSKA_DEMUXER=1 CONFIG_FLV_DEMUXER=1 CONFIG_H264_PARSER=1 CONFIG_HEVC_PARSER=1 \
          CONFIG_AAC_PARSER=1 CONFIG_H264_DECODER=1 CONFIG_AAC_DECODER=1; do
  k=${kv%=*}; want=${kv#*=}; v=$(val $k); [ -z "$v" ] && v="<ABSENT>"
  if [ "$v" = "$want" ]; then echo "  OK    $k = $v"; else echo "  FAIL  $k = $v (want $want)"; FAIL=$((FAIL+1)); fi
done
[ $FAIL -eq 0 ] || { echo "GATE FAILED ($FAIL)"; exit 1; }
echo "GATE PASSED"

echo "=== make -j$JOBS $(date '+%T')"
make -j$JOBS > /f/kodi-rt/logs/s10-ffmpeg-arm32-make.log 2>&1 || { tail -40 /f/kodi-rt/logs/s10-ffmpeg-arm32-make.log; echo "MAKE FAILED"; exit 1; }
echo "make warnings: $(grep -c 'warning:' /f/kodi-rt/logs/s10-ffmpeg-arm32-make.log)"
echo "=== make install $(date '+%T')"
make install > /f/kodi-rt/logs/s10-ffmpeg-arm32-install.log 2>&1 || { tail -20 /f/kodi-rt/logs/s10-ffmpeg-arm32-install.log; echo "INSTALL FAILED"; exit 1; }
ls -la "$PFX/lib"/*.lib
echo "FFMPEG DONE $(date '+%F %T')"
