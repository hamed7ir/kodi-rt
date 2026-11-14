#!/bin/bash
# kodi-rt Stage 9: Kodi x64 and x86 WITH Python, after the Python stage's x64/x86 CPython. Waits until both
# prefix/<arch>/python/libs/python314.lib exist and logs/s9-lane.status says "LANE FREE" (the Python stage frees the
# lane after its build), claims the lane, then per arch: s9-configure.sh, s9-build.sh, s9-package-kit.sh; frees the
# lane. Gives up after 3 hours of waiting. Started detached (scripts/launch-detached.ps1 -Shell git).
exec > /f/kodi-rt/logs/s9-lane3.log 2>&1
cd /f/kodi-rt || exit 1
ST=/f/kodi-rt/logs/s9-lane.status
echo "lane3 start $(date '+%F %T'): waiting for the x64/x86 Python and a free lane"
n=0
until [ -f prefix/x64/python/libs/python314.lib ] && [ -f prefix/x86/python/libs/python314.lib ] && grep -q '^LANE FREE' $ST; do
  sleep 30; n=$((n + 1)); [ $n -gt 360 ] && { echo "gave up waiting $(date '+%F %T')"; exit 1; }
done
echo "LANE kodi-rt Kodi x64/x86 builds (about 40 min), since $(date '+%F %T')" > $ST
for a in x64 x86; do
  echo "--- $a configure $(date '+%T')"
  ARCH=$a bash scripts/s9-configure.sh > logs/s9-lane3-configure-$a.out 2>&1 || { echo "configure $a FAILED"; tail -5 logs/s9-lane3-configure-$a.out; continue; }
  grep -E '^ENABLE_PYTHON:' build/s9/kodi-build-$a/CMakeCache.txt
  echo "--- $a build $(date '+%T')"
  bash scripts/s9-build.sh $a
  cat logs/s9-build-$a.status
  grep -q 'DONE rc=0' logs/s9-build-$a.status || { echo "build $a FAILED"; grep -E "FAILED:|error:" logs/s9-build-$a.log | head -20; continue; }
  bash scripts/s9-package-kit.sh $a 2>&1 | tail -3
done
echo "LANE FREE since $(date '+%F %T')" > $ST
echo "lane3 end $(date '+%F %T')"
