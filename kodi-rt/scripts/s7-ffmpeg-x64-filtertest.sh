#!/bin/bash
# kodi-rt: a small x64 FFmpeg 9.0.2 (avutil, swscale, avfilter with buffer/buffersink/scale/format/null; plain C, no
# asm, like the ARM32 build's paths for these conversions) from build/s7/ffmpeg-src, for tests/s7/fgcs.c: Kodi's video
# filter graph and the colorspace of its buffer source.
# Run with MSYS2's bash (GNU make). Log: logs/s7-ffmpeg-x64-filtertest.log. Output: build/s7/ffmpeg-x64-filtertest.
set -u
unset MSYS2_ARG_CONV_EXCL
exec > /f/kodi-rt/logs/s7-ffmpeg-x64-filtertest.log 2>&1
echo "start $(date '+%F %T')"
RT=F:/kodi-rt/tc/rt24c-cr/bin
X=/f/kodi-rt/cross
SRC=/f/kodi-rt/build/s7/ffmpeg-src
B=/f/kodi-rt/build/s7/ffmpeg-x64-filtertest
export PATH="/usr/bin:/usr/local/bin:$PATH"
rm -rf "$B"; mkdir -p "$B"; cd "$B" || exit 1
export TMPDIR=. TMP=/d/MSYS2/tmp TEMP=/d/MSYS2/tmp
"$SRC/configure" --enable-cross-compile --arch=x86_64 --target-os=win32 \
  --cc="$X/hostcc-x64.sh" --cxx="$X/hostcc-x64.sh" --ld="$RT/lld-link.exe" --ar="$RT/llvm-ar.exe" \
  --nm="$RT/llvm-nm.exe" --ranlib="$RT/llvm-ranlib.exe" --strip="$RT/llvm-strip.exe" \
  --host-cc="$X/hostcc-x64.sh" --host-ld="$RT/lld-link.exe" --host-ldflags="@F:/kodi-rt/cross/x64-link.rsp" \
  --enable-static --disable-shared --disable-asm --disable-everything --disable-programs --disable-doc \
  --disable-avdevice --disable-avformat --disable-avcodec --disable-network --disable-autodetect --disable-postproc \
  --disable-swresample --enable-avfilter --enable-swscale --enable-w32threads \
  --enable-filter=buffer,buffersink,scale,format,null \
  --extra-ldflags="@F:/kodi-rt/cross/x64-link.rsp" || { tail -30 ffbuild/config.log; echo "CONFIGURE FAILED"; exit 1; }
grep -E "define (HAVE_W32THREADS|HAVE_THREADS|CONFIG_SCALE_FILTER|CONFIG_BUFFERSINK_FILTER) " config.h config_components.h
make -j8 > make.log 2>&1 || { tail -30 make.log; echo "MAKE FAILED"; exit 1; }
ls -la libavfilter/avfilter.lib libswscale/swscale.lib libavutil/avutil.lib
echo "X64 FILTERTEST FFMPEG DONE $(date '+%F %T')"
