#!/bin/bash
# kodi-rt Python stage: CPython 3.14.10 for desktop x64 and x86, in the shared build lane (logs/s9-lane.status, the
# original session's protocol: one -j8 build at a time). Claims the lane, builds liblzma and CPython for both arches
# (scripts/py-deps.sh, scripts/py-build.sh), runs the smoke test and the regrtest device list with each interpreter on
# this server, and frees the lane (also on failure).
# Run detached: powershell -NoProfile -File scripts/launch-detached.ps1 -Script /f/kodi-rt/scripts/py-lane-x64x86.sh -Shell git
# Log: logs/py-lane-x64x86.log; result lines "PY X64X86 <arch> ..." and "PY X64X86 DONE rc=<n>".
set -u
cd /f/kodi-rt || exit 1
LANE=logs/s9-lane.status
LOG=logs/py-lane-x64x86.log
now() { date '+%F %T'; }
# wait for the lane (up to 6 h), then claim it at once
echo "$(now) waiting for LANE FREE (now: $(cat $LANE 2>/dev/null))" >> $LOG
for i in $(seq 1 1080); do grep -q "^LANE FREE" "$LANE" 2>/dev/null && break; sleep 20; done
grep -q "^LANE FREE" "$LANE" 2>/dev/null || { echo "$(now) gave up waiting: $(cat $LANE)" >> $LOG; exit 1; }
echo "LANE python CPython 3.14.10 x64/x86 (liblzma, CPython, tests; ~20 min) since $(now)" > "$LANE"
trap 'echo "LANE FREE since $(now)" > "$LANE"' EXIT
rc=0
{
  echo "[py-lane] $(now) start"
  for a in x64 x86; do
    for f in libssl.lib libcrypto.lib sqlite3.lib zs.lib; do
      [ -f prefix/$a/lib/$f ] || { echo "PY X64X86 $a: prefix/$a/lib/$f missing"; rc=1; }
    done
  done
  if [ $rc = 0 ]; then
    for a in x64 x86; do
      bash scripts/py-deps.sh $a || { echo "PY X64X86 $a: liblzma FAILED"; rc=1; continue; }
      bash scripts/py-build.sh $a || { echo "PY X64X86 $a: CPython build FAILED"; rc=1; continue; }
      P=prefix/$a/python/python.exe
      timeout 600 $P -X faulthandler tests/python/kodirt_smoke.py --require-all > logs/py-smoke-$a.txt 2>&1
      s=$?; echo "PY X64X86 $a: smoke exit $s, $(grep -c '^SMOKE PASS' logs/py-smoke-$a.txt) pass, $(grep -c '^SMOKE FAIL' logs/py-smoke-$a.txt) fail"
      [ $s = 0 ] || rc=1
      timeout 1800 $P -X faulthandler -m test -j4 --timeout 1800 --fromfile tests/python/regrtest-device.txt > logs/py-regrtest-$a.txt 2>&1
      t=$?; echo "PY X64X86 $a: regrtest exit $t, $(grep -E '^Result:|^Total tests:' logs/py-regrtest-$a.txt | tr '\n' ' ')"
      [ $t = 0 ] || rc=1
    done
  fi
  echo "[py-lane] $(now) end"
  echo "PY X64X86 DONE rc=$rc"
} >> $LOG 2>&1
exit $rc
