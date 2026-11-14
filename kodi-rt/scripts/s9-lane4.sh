#!/bin/bash
# kodi-rt Stage 9: the second Kodi x64/x86 round (after the gpu_memcpy fix): claims the lane if it is free, finishes
# the configured x64 tree (ninja picks up the changed header), packages its kit, then configures, builds and packages
# x86; frees the lane. Started detached (scripts/launch-detached.ps1 -Shell git).
exec > /f/kodi-rt/logs/s9-lane4.log 2>&1
cd /f/kodi-rt || exit 1
ST=/f/kodi-rt/logs/s9-lane.status
grep -q '^LANE FREE' $ST || { echo "lane not free: $(cat $ST)"; exit 1; }
echo "LANE kodi-rt Kodi x64/x86 builds, round 2 (about 30 min), since $(date '+%F %T')" > $ST
echo "lane4 start $(date '+%F %T')"
build() { # arch
  bash scripts/s9-build.sh $1
  cat logs/s9-build-$1.status
  grep -q 'DONE rc=0' logs/s9-build-$1.status || { echo "build $1 FAILED"; grep -E "^FAILED:" logs/s9-build-$1.log | head -20; return 1; }
  bash scripts/s9-package-kit.sh $1 2>&1 | tail -3
}
echo "--- x64 build $(date '+%T')"; build x64
echo "--- x86 configure $(date '+%T')"
if ARCH=x86 bash scripts/s9-configure.sh > logs/s9-lane4-configure-x86.out 2>&1; then
  grep -E '^ENABLE_PYTHON:' build/s9/kodi-build-x86/CMakeCache.txt
  echo "--- x86 build $(date '+%T')"; build x86
else
  echo "configure x86 FAILED"; tail -5 logs/s9-lane4-configure-x86.out
fi
echo "LANE FREE since $(date '+%F %T')" > $ST
echo "lane4 end $(date '+%F %T')"
