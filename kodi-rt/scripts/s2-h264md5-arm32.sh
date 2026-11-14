#!/bin/bash
# kodi-rt Stage 2: h264md5 (tests/stage0/h264md5, the per-frame MD5 decode probe) for ARM32, linked STATICALLY against
# the Stage 2 FFmpeg 9.0.2 + dav1d + zlib in F:/kodi-rt/prefix/arm32, rt2.4, /MT. The extra libraries come from the
# installed .pc files (foo.lib, or -lfoo -> foo.lib), so the link uses exactly what FFmpeg's configure recorded.
# Run from Git Bash after scripts/s2-ffmpeg-arm32.sh: bash scripts/s2-h264md5-arm32.sh
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24b-cr/bin
PFX=F:/kodi-rt/prefix/arm32
O=/f/kodi-rt/build/s2/h264md5-arm32
rm -rf "$O"; mkdir -p "$O"; cd "$O" || exit 1
"$RT/clang-cl.exe" @F:/kodi-rt/cross/arm32-msvc.rsp -MT -O2 -W3 -nologo -Zi -c F:/kodi-rt/tests/stage0/h264md5/h264md5.c \
  -Foh264md5.obj "-I$PFX/include" > compile.log 2>&1 || { cat compile.log; echo "COMPILE FAILED"; exit 1; }
PC=/f/kodi-rt/prefix/arm32/lib/pkgconfig
# this static msvc-style build records the extra libraries on "Libs:" as foo.lib (Libs.private is empty); read both
SYS=$(sed -n -e 's/^Libs: *//p' -e 's/^Libs.private: *//p' $PC/libavformat.pc $PC/libavcodec.pc $PC/libswresample.pc $PC/libavutil.pc \
      | tr ' ' '\n' | sed -n -e 's/^-l\(.*\)$/\1.lib/p' -e '/\.lib$/p' | grep -vE '^(avcodec|avformat|avutil|swresample|swscale|avfilter|postproc)\.lib$' | sort -u | tr '\n' ' ')
echo "system/extra libraries from Libs.private: $SYS"
lib() { for f in "$PFX/lib/$1.lib" "$PFX/lib/lib$1.a" "$PFX/lib/lib$1.lib"; do [ -f "$f" ] && { echo "$f"; return; }; done; echo "MISSING-$1"; }
"$RT/lld-link.exe" -nologo h264md5.obj "$(lib avformat)" "$(lib avcodec)" "$(lib swresample)" "$(lib avutil)" \
  @F:/kodi-rt/cross/arm32-link.rsp "-libpath:$PFX/lib" -out:h264md5.exe -subsystem:console -debug -pdb:h264md5.pdb \
  -opt:ref $SYS kernel32.lib > link.log 2>&1 || { cat link.log; echo "LINK FAILED"; exit 1; }
cat link.log
ls -la h264md5.exe
echo "H264MD5 ARM32 DONE"
