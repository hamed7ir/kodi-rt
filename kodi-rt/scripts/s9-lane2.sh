#!/bin/bash
# kodi-rt Stage 9: after the prefix chain (scripts/s9-prefix-chain.sh) ends, build FFmpeg for x64 and then x86
# (scripts/s9-ffmpeg.sh, MSYS2's bash). One -j8 build at a time on the server: logs/s9-lane.status says who is
# building ("LANE <who> ...") and becomes "LANE FREE ..." at the end; the Python stage starts its builds after that.
# Started detached (scripts/launch-detached.ps1 -Shell git); it waits for "chain end" in logs/s9-prefix-chain.log.
exec > /f/kodi-rt/logs/s9-lane2.log 2>&1
cd /f/kodi-rt || exit 1
ST=/f/kodi-rt/logs/s9-lane.status
echo "LANE kodi-rt x64/x86 prefixes + FFmpeg (until about 18:30), since $(date '+%F %T')" > $ST
echo "lane2 start $(date '+%F %T'): waiting for the prefix chain"
until grep -q 'chain end' /f/kodi-rt/logs/s9-prefix-chain.log 2>/dev/null; do sleep 60; done
echo "prefix chain ended $(date '+%F %T')"
for a in x64 x86; do
  grep -q "S9 PREFIX $a DONE" /f/kodi-rt/logs/s9-prefix-$a.log || { echo "prefix $a not done: FFmpeg $a skipped"; continue; }
  echo "--- FFmpeg $a $(date '+%T')"
  MSYSTEM=MSYS /d/MSYS2/usr/bin/bash.exe -l -c "ARCH=$a bash /f/kodi-rt/scripts/s9-ffmpeg.sh"
  tail -1 /f/kodi-rt/logs/s9-ffmpeg-$a.log
done
echo "LANE FREE since $(date '+%F %T')" > $ST
echo "lane2 end $(date '+%F %T')"
