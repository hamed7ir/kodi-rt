#!/bin/bash
# kodi-rt Stage 9: FFmpeg x64 then x86 WITH the x86 SIMD (nasm, scripts/s9-nasm.sh), each gated and checked with
# checkasm on this server (scripts/s9-ffmpeg.sh). Claims the lane if free; frees it at the end. Detached.
exec > /f/kodi-rt/logs/s9-lane5.log 2>&1
cd /f/kodi-rt || exit 1
ST=/f/kodi-rt/logs/s9-lane.status
grep -q '^LANE FREE' $ST || { echo "lane not free: $(cat $ST)"; exit 1; }
echo "LANE kodi-rt FFmpeg x64/x86 with nasm (about 30 min), since $(date '+%F %T')" > $ST
echo "lane5 start $(date '+%F %T')"
for a in x64 x86; do
  echo "--- FFmpeg $a $(date '+%T')"
  MSYSTEM=MSYS /d/MSYS2/usr/bin/bash.exe -l -c "ARCH=$a bash /f/kodi-rt/scripts/s9-ffmpeg.sh"
  tail -1 /f/kodi-rt/logs/s9-ffmpeg-$a.log
  grep -A3 "make checkasm" /f/kodi-rt/logs/s9-ffmpeg-$a.log | tail -3
done
echo "LANE FREE since $(date '+%F %T')" > $ST
echo "lane5 end $(date '+%F %T')"
