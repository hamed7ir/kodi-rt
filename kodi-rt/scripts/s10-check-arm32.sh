#!/bin/bash
# kodi-rt Stage 10: the device checks of scripts/s4-gate.sh (check 9, as scripts/py-check-arm32.sh does them for the
# Python stage) for every ARM32 binary add-on in build/s10/install-arm32 (scripts/s10-addon.sh). Per DLL: ARMNT,
# every imported function exported by the tablet's own DLL copies (results/stage0-run5/dlls; VERSION/RPCRT4 from
# run 1), API sets resolved through the tablet's apisetschema.dll, no UCRT/VC runtime DLL (RT 8.1 has none), and the
# toolchain-0031 check (no call whose return address leaves its .pdata function). Also: addon.xml says
# <platform>windows-arm</platform> and names the DLL.
# Usage (Git Bash): bash scripts/s10-check-arm32.sh [addon-id ...]
#   Output: logs/s10-check-arm32.log; last line "ADDON ARM32 CHECK: PASS"
set -u
export MSYS2_ARG_CONV_EXCL='*'
cd /f/kodi-rt || exit 1
T=F:/kodi-rt/tc/rt24c-cr/bin
DEVDLLS=results/stage0-run5/dlls
INST=build/s10/install-arm32
LOG=logs/s10-check-arm32.log
if [ $# -gt 0 ]; then IDS=("$@"); else mapfile -t IDS < <(ls "$INST" 2>/dev/null); fi
fail=0; n=0
{
  echo "== kodi-rt ARM32 binary add-on checks $(date '+%F %T'): ${IDS[*]}"
  for id in "${IDS[@]}"; do
    x=$INST/$id/addon.xml
    lib=$(grep -oE 'library_windows="[^"]+"|library="[^"]+"' "$x" 2>/dev/null | head -1 | cut -d'"' -f2)
    grep -q '<platform>windows-arm</platform>' "$x" 2>/dev/null || { echo "FAIL  $id: addon.xml platform is not windows-arm"; fail=1; }
    [ -n "$lib" ] && [ -f "$INST/$id/$lib" ] || { echo "FAIL  $id: addon.xml library '$lib' not in the folder"; fail=1; }
    for b in $(find "$INST/$id" -iname '*.dll' | sort); do
      n=$((n+1)); ok=1; why=""
      python -I scripts/check-machine.py --want=0x1c4 "$b" > /dev/null || { ok=0; why="$why machine"; }
      python -I scripts/check-imports.py "$T/llvm-readobj.exe" "$DEVDLLS;results/stage0-run1/dlls" "$b" > logs/s10-check-imp.txt 2>&1 || { ok=0; why="$why imports"; }
      grep -qiE 'api-ms-win-crt-|ucrtbase|vcruntime|msvcp1' logs/s10-check-imp.txt && { ok=0; why="$why vc-runtime"; }
      if grep -q "api-ms-win-" logs/s10-check-imp.txt; then
        python -I scripts/apiset-resolve.py "$DEVDLLS/apisetschema.dll" --check "$T/llvm-readobj.exe" "$DEVDLLS" "$b" >> logs/s10-check-imp.txt 2>&1 || { ok=0; why="$why apisets"; }
      fi
      python -I scripts/pdata-calls.py "$T/llvm-objdump.exe" "$b" > logs/s10-check-pdata.txt 2>&1 || { ok=0; why="$why pdata-run"; }
      bad=$(grep -m1 "calls whose return address leaves their function:" logs/s10-check-pdata.txt | grep -oE ": [0-9]+" | grep -oE "[0-9]+")
      [ "${bad:-x}" = 0 ] || { ok=0; why="$why 0031:${bad:-?}"; }
      dlls=$(grep -E "^   [A-Za-z0-9_.-]+\.(dll|DLL): " logs/s10-check-imp.txt | grep -oE "^   [A-Za-z0-9_.-]+\.(dll|DLL)" | sed 's/^ *//' | sort -u | tr '\n' ' ')
      if [ $ok = 1 ]; then echo "OK    $b  $(stat -c %s "$b") bytes sha256 $(sha256sum "$b" | cut -d" " -f1) [imports: $dlls]"; else echo "FAIL  $b:$why"; cat logs/s10-check-imp.txt; tail -3 logs/s10-check-pdata.txt; fail=1; fi
    done
  done
  [ $fail = 0 ] && echo "ADDON ARM32 CHECK: PASS ($n DLLs)" || echo "ADDON ARM32 CHECK: FAIL"
} > $LOG 2>&1
grep -E "^OK|^FAIL|ADDON ARM32 CHECK|^== " $LOG
exit $fail
