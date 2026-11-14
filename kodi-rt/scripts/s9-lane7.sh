#!/bin/bash
# kodi-rt: rebuild the three Kodi trees for the "Open with" hand-off to a running Kodi
# (reports/proposed-edits/openwith-running-instance.py: WinMain.cpp, WinEventsWin32.cpp/.h). ARM32 is the PGO tree
# (changed functions lose their profile, the rest keeps it; ThinLTO cache for the link). Claims the lane, frees it.
exec > /f/kodi-rt/logs/s9-lane7.log 2>&1
cd /f/kodi-rt || exit 1
ST=/f/kodi-rt/logs/s9-lane.status
n=0; until grep -q '^LANE FREE' $ST; do sleep 20; n=$((n + 1)); [ $n -gt 540 ] && { echo "gave up waiting"; exit 1; }; done
echo "LANE kodi-rt Kodi arm32/x64/x86 rebuild (Open with hand-off), since $(date '+%F %T')" > $ST
echo "lane7 start $(date '+%F %T')"
echo "--- arm32 (PGO tree) $(date '+%T')"; bash scripts/s7-build.sh use; cat logs/s7-build-use.status
echo "--- x64 $(date '+%T')"; bash scripts/s9-build.sh x64; cat logs/s9-build-x64.status
echo "--- x86 $(date '+%T')"; bash scripts/s9-build.sh x86; cat logs/s9-build-x86.status
echo "LANE FREE since $(date '+%F %T')" > $ST
echo "lane7 end $(date '+%F %T')"
