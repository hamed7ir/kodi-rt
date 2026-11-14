#!/bin/bash
# kodi-rt Python stage: CPython 3.14.10 with _ctypes (static libffi, scripts/py-deps.sh <arch> libffi) and
# pycryptodome (scripts/pycd-build.sh: Kodi's script.module.pycryptodome) for x64, x86 and arm32, in the shared build
# lane (logs/s9-lane.status: one -j8 build at a time). Waits for LANE FREE, claims it, builds, then runs on this
# server with the x64 and x86 interpreters: the smoke test (--require-all, now with _ctypes), test_ctypes (with
# DLLs/_ctypes_test.pyd), tests/python/kodirt_crypto.py --selftest and the regrtest device list; frees the lane at
# the end, also on failure.
# Run detached: powershell -NoProfile -File scripts/launch-detached.ps1 -Script /f/kodi-rt/scripts/py-lane-ctypes.sh -Shell git
# Log: logs/py-lane-ctypes.log; result lines "PY CTYPES <arch> ..." and "PY CTYPES DONE rc=<n>".
set -u
cd /f/kodi-rt || exit 1
LANE=logs/s9-lane.status
LOG=logs/py-lane-ctypes.log
now() { date '+%F %T'; }
echo "$(now) waiting for LANE FREE (now: $(cat $LANE 2>/dev/null))" >> $LOG
for i in $(seq 1 1080); do grep -q "^LANE FREE" "$LANE" 2>/dev/null && break; sleep 20; done
grep -q "^LANE FREE" "$LANE" 2>/dev/null || { echo "$(now) gave up waiting: $(cat $LANE)" >> $LOG; exit 1; }
# Environment (space-separated lists; default all): BUILDS (CPython), PYCD (pycryptodome), TESTS (x64/x86 test runs),
# REGR=0 skips the regrtest device list.
BUILDS=${BUILDS-x64 x86 arm32}; PYCD=${PYCD-x64 x86 arm32}; TESTS=${TESTS-x64 x86}; REGR=${REGR:-1}
echo "LANE python CPython 3.14.10 + _ctypes [$BUILDS], pycryptodome [$PYCD], tests [$TESTS] since $(now)" > "$LANE"
trap 'echo "LANE FREE since $(now)" > "$LANE"' EXIT
rc=0
{
  echo "[py-lane-ctypes] $(now) start: BUILDS=[$BUILDS] PYCD=[$PYCD] TESTS=[$TESTS] REGR=$REGR"
  for a in $BUILDS; do
    if bash scripts/py-build.sh $a; then echo "PY CTYPES $a: built"; else echo "PY CTYPES $a: CPython build FAILED"; rc=1; fi
  done
  for a in $PYCD; do
    if bash scripts/pycd-build.sh $a; then echo "PY CTYPES $a: pycryptodome $(tail -1 logs/pycd-$a.log)"
    else echo "PY CTYPES $a: pycryptodome build FAILED"; rc=1; fi
  done
  for a in $TESTS; do
    P=prefix/$a/python/python.exe
    [ -f $P ] || { echo "PY CTYPES $a: no python.exe"; rc=1; continue; }
    timeout 600 $P -X faulthandler tests/python/kodirt_smoke.py --require-all > logs/py-smoke-$a.txt 2>&1
    s=$?; echo "PY CTYPES $a: smoke exit $s, $(grep -c '^SMOKE PASS' logs/py-smoke-$a.txt) pass, $(grep -c '^SMOKE FAIL' logs/py-smoke-$a.txt) fail"
    [ $s = 0 ] || rc=1
    # two cases need what this build leaves out by design: _sqlite3 as a .pyd (compiled in here) and _testcapi
    timeout 1800 $P -X faulthandler -m test -j4 --timeout 900 -i '*test_load_dll_with_flags' -i '*test_packed_c_limits' \
      test_ctypes > logs/py-test-ctypes-$a.txt 2>&1
    t=$?; echo "PY CTYPES $a: test_ctypes exit $t, $(grep -E '^Result:|^Total tests:' logs/py-test-ctypes-$a.txt | tr '\n' ' ')"
    [ $t = 0 ] || rc=1
    timeout 1800 $P -X faulthandler tests/python/kodirt_crypto.py prefix/$a/kodi-addons/script.module.pycryptodome/lib \
      --selftest > logs/py-crypto-$a.txt 2>&1
    t=$?; echo "PY CTYPES $a: crypto exit $t, $(grep -c '^CRYPTO PASS' logs/py-crypto-$a.txt) pass, $(grep -c '^CRYPTO FAIL' logs/py-crypto-$a.txt) fail; $(grep -E 'SelfTest [0-9]' logs/py-crypto-$a.txt | sed 's/^ *//')"
    [ $t = 0 ] || rc=1
    [ "$REGR" = 1 ] || continue
    timeout 1800 $P -X faulthandler -m test -j4 --timeout 1800 --fromfile tests/python/regrtest-device.txt > logs/py-regrtest-$a.txt 2>&1
    t=$?; echo "PY CTYPES $a: regrtest device list exit $t, $(grep -E '^Result:|^Total tests:' logs/py-regrtest-$a.txt | tr '\n' ' ')"
    [ $t = 0 ] || rc=1
  done
  echo "[py-lane-ctypes] $(now) end"
  echo "PY CTYPES DONE rc=$rc"
} >> $LOG 2>&1
exit $rc
