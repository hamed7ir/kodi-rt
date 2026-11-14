#!/bin/bash
# kodi-rt: the Kodi rebuilds for the purple icon and the corrected splash (branding/), and for x64/x86 the FFmpeg with
# nasm: ARM32 PGO tree (build/s7/kodi-build-pgo: only the resource and the link; the ThinLTO cache keeps the rest),
# then x64 and x86. The .rc compile does not track application.ico (CMake's RC rule here is "unscanned"), so the
# compiled .res is removed first; media/splash.jpg is copied into each build tree (Kodi copies media at configure
# time). Waits for "LANE FREE", claims the lane, frees it at the end. Detached.
exec > /f/kodi-rt/logs/s9-lane6.log 2>&1
cd /f/kodi-rt || exit 1
ST=/f/kodi-rt/logs/s9-lane.status
echo "lane6 start $(date '+%F %T'): waiting for a free lane"
n=0; until grep -q '^LANE FREE' $ST; do sleep 20; n=$((n + 1)); [ $n -gt 540 ] && { echo "gave up waiting"; exit 1; }; done
echo "LANE kodi-rt Kodi arm32/x64/x86 rebuild (icon, splash, FFmpeg with nasm), since $(date '+%F %T')" > $ST
for BD in build/s7/kodi-build-pgo build/s9/kodi-build-x64 build/s9/kodi-build-x86; do
  rm -f $BD/CMakeFiles/windows_resources.dir/build/xbmc/platform/win32/XBMC_PC.rc.res
  cp -f branding/splash.jpg $BD/media/splash.jpg
done
echo "--- arm32 (PGO tree) $(date '+%T')"; bash scripts/s7-build.sh use; cat logs/s7-build-use.status
echo "--- x64 $(date '+%T')"; bash scripts/s9-build.sh x64; cat logs/s9-build-x64.status
echo "--- x86 $(date '+%T')"; bash scripts/s9-build.sh x86; cat logs/s9-build-x86.status
echo "LANE FREE since $(date '+%F %T')" > $ST
echo "lane6 end $(date '+%F %T')"
