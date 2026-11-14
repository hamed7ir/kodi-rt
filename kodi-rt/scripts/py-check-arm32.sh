#!/bin/bash
# kodi-rt Python stage: the device checks of scripts/s4-gate.sh (check 9) for every ARM32 binary of the Python stage:
# prefix/arm32/python/python314.dll, python.exe, DLLs/*.pyd and the pycryptodome C modules in
# prefix/arm32/kodi-addons/script.module.pycryptodome. Per binary: ARMNT, every imported function exported by the
# tablet's own DLL copies (results/stage0-run5/dlls; VERSION/RPCRT4 from run 1), API sets resolved through the tablet's
# apisetschema.dll, and the toolchain-0031 check (no call whose return address leaves its .pdata function).
# Usage (Git Bash): bash scripts/py-check-arm32.sh      Output: logs/py-check-arm32.log; last line "PY ARM32 CHECK: PASS"
set -u
export MSYS2_ARG_CONV_EXCL='*'
cd /f/kodi-rt || exit 1
T=F:/kodi-rt/tc/rt24c-cr/bin
DEVDLLS=results/stage0-run5/dlls
LOG=logs/py-check-arm32.log
mapfile -t BINS < <(ls prefix/arm32/python/python314.dll prefix/arm32/python/python.exe prefix/arm32/python/DLLs/*.pyd 2>/dev/null;
                    find prefix/arm32/kodi-addons -name '*.pyd' 2>/dev/null | sort)
fail=0; n=0
{
  echo "== kodi-rt Python ARM32 binary checks $(date '+%F %T'): ${#BINS[@]} binaries"
  for b in "${BINS[@]}"; do
    n=$((n+1)); ok=1; why=""
    python -I scripts/check-machine.py --want=0x1c4 "$b" > /dev/null || { ok=0; why="$why machine"; }
    # python314.dll is ours: python.exe's and the .pyd files' imports from it are checked against its exports
    python -I scripts/check-imports.py "$T/llvm-readobj.exe" "$DEVDLLS;results/stage0-run1/dlls;prefix/arm32/python" "$b" > logs/py-check-imp.txt 2>&1 || { ok=0; why="$why imports"; }
    if grep -q "api-ms-win-" logs/py-check-imp.txt; then
      python -I scripts/apiset-resolve.py "$DEVDLLS/apisetschema.dll" --check "$T/llvm-readobj.exe" "$DEVDLLS" "$b" >> logs/py-check-imp.txt 2>&1 || { ok=0; why="$why apisets"; }
    fi
    python -I scripts/pdata-calls.py "$T/llvm-objdump.exe" "$b" > logs/py-check-pdata.txt 2>&1 || { ok=0; why="$why pdata-run"; }
    bad=$(grep -m1 "calls whose return address leaves their function:" logs/py-check-pdata.txt | grep -oE ": [0-9]+" | grep -oE "[0-9]+")
    [ "${bad:-x}" = 0 ] || { ok=0; why="$why 0031:${bad:-?}"; }
    dlls=$(grep -E "^== |^   [A-Za-z0-9_.-]+\.(dll|DLL): " logs/py-check-imp.txt | grep -oE "^   [A-Za-z0-9_.-]+\.(dll|DLL)" | sed 's/^ *//' | sort -u | tr '\n' ' ')
    if [ $ok = 1 ]; then echo "OK    $b  [imports: $dlls]"; else echo "FAIL  $b:$why"; cat logs/py-check-imp.txt; tail -3 logs/py-check-pdata.txt; fail=1; fi
  done
  [ $fail = 0 ] && echo "PY ARM32 CHECK: PASS ($n binaries)" || echo "PY ARM32 CHECK: FAIL"
} > $LOG 2>&1
grep -E "^FAIL|PY ARM32 CHECK|^== " $LOG
exit $fail
