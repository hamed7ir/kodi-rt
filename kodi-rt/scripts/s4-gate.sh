#!/bin/bash
# kodi-rt Stage 4 gate, server part (plan §3 Stage 4), on the linked kodi.exe:
#   1. kodi.exe links; it is ARMNT (0x01C4)                          scripts/check-machine.py
#   2. imports: no api-ms-win-crt-*, ucrtbase.dll, vcruntime140*, msvcp140* (RT 8.1 has none; /MT leaves none);
#      api-ms-win-core-* and msvcrt.dll are listed for a closer look
#   3. every imported FUNCTION (normal and delay-load) is exported by the Surface's own DLL
#      (DEVDLLS, default results/stage0-run5/dlls: the tablet's copies of exactly the DLLs kodi.exe imports) check-imports.py
#   4. subsystem WINDOWS_GUI, version <= 6.03
#   5. CFG: if the image has guard flags, GuardAddressTakenIatEntryCount must not be 0 (Kodi sets no /guard:cf)
#   6. the PDB: kodi.pdb exists and is the one the debug directory names
#   7. C runtime of Kodi's own static libraries: /MT (LIBCMT) or none     scripts/check-crt.py
#   8. toolchain 0031 check: no call whose return address leaves its .pdata function   scripts/pdata-calls.py
# Usage (Git Bash): bash scripts/s4-gate.sh [build dir]     Output: logs/s4-gate.log; last line "S4 GATE (server): PASS"
set -u
export MSYS2_ARG_CONV_EXCL='*'
cd /f/kodi-rt || exit 1
BD=${1:-build/s4/kodi-build}
T=F:/kodi-rt/tc/rt24c-cr/bin
DEVDLLS=${DEVDLLS:-results/stage0-run5/dlls}
PYDIR=${PYDIR:-prefix/arm32/python}     # python314.dll ships with Kodi when it is built with Python (check 9)
EXE=$BD/kodi.exe
LOG=${GATELOG:-logs/s4-gate.log}   # GATELOG=<file>: another log (the release build uses logs/s8-gate-arm32.log)
fail=0
res() { printf '%-58s %s\n' "$1" "$2"; [ "$2" = PASS ] || [ "${3:-}" = info ] || fail=1; }
{
echo "== kodi-rt Stage 4 gate (server) $(date '+%F %T'), image $EXE"
[ -f "$EXE" ] || { echo "no $EXE"; echo "S4 GATE (server): FAIL"; exit 1; }
ls -la "$EXE" "$BD/kodi.pdb" 2>&1
sha256sum "$EXE" "$BD/kodi.pdb" 2>/dev/null

echo; echo "-- 1. machine"
python -I scripts/check-machine.py --want=0x1c4 "$EXE" && res "1. ARMNT (0x01C4)" PASS || res "1. ARMNT (0x01C4)" FAIL

echo; echo "-- 2. imported DLLs"
"$T/llvm-readobj.exe" --coff-imports "$EXE" > logs/s4-gate-imports.txt
python -I - logs/s4-gate-imports.txt <<'PY'
import re, sys
kind, dll, rows = None, None, {}
for line in open(sys.argv[1], encoding='utf-8'):
    m = re.match(r'^(Import|DelayImport) \{', line.strip())
    if m: kind = m.group(1); continue
    m = re.match(r'^\s*Name: (\S+)$', line)
    if m and kind: dll = m.group(1); rows.setdefault((kind, dll), 0); kind = None; continue
    if re.match(r'^\s*Symbol: ', line) and dll: rows[[k for k in rows if k[1] == dll][-1]] += 1
for (k, d), n in sorted(rows.items(), key=lambda x: (x[0][0], x[0][1].lower())):
    print(f'   {k:12s} {d:40s} {n:5d} functions')
PY
bad=$(grep -oiE "Name: (api-ms-win-crt-[^ ]*|ucrtbase\.dll|vcruntime140[^ ]*|msvcp140[^ ]*|concrt140\.dll)" logs/s4-gate-imports.txt | sort -u)
[ -z "$bad" ] && res "2. no UCRT/VC runtime DLL imports" PASS || { echo "$bad"; res "2. no UCRT/VC runtime DLL imports" FAIL; }
core=$(grep -oiE "Name: (api|ext)-ms-win-[^ ]*" logs/s4-gate-imports.txt | sort -u)
if [ -z "$core" ]; then
  res "2b. no API-set imports at all" PASS
else
  # plan: an API-set import is checked against the tablet's apisetschema.dll (Windows 8.1 maps many core sets), and
  # its functions against the host DLL the schema names
  python -I scripts/apiset-resolve.py "$DEVDLLS/apisetschema.dll" --check "$T/llvm-readobj.exe" \
    "$DEVDLLS" "$EXE" > logs/s4-gate-apisets.txt; r=$?
  cat logs/s4-gate-apisets.txt
  [ $r = 0 ] && res "2b. API-set imports resolve on the tablet, functions exported" PASS \
             || res "2b. API-set imports resolve on the tablet, functions exported" FAIL
fi
grep -qi "Name: msvcrt.dll" logs/s4-gate-imports.txt && res "2c. msvcrt.dll imported (the system CRT)" CHECK info

echo; echo "-- 3. every imported function vs the Surface's DLLs"
WITHPY=; grep -qi "Name: python314.dll" logs/s4-gate-imports.txt && WITHPY=1
python -I scripts/check-imports.py "$T/llvm-readobj.exe" "$DEVDLLS${WITHPY:+;$PYDIR}" "$EXE" > logs/s4-gate-functions.txt; r=$?
cat logs/s4-gate-functions.txt
[ $r = 0 ] && res "3. all imported functions exist on the device" PASS || res "3. all imported functions exist on the device" FAIL

echo; echo "-- 4. subsystem"
"$T/llvm-readobj.exe" --file-headers "$EXE" > logs/s4-gate-headers.txt
grep -E "Subsystem|SubsystemVersion|OperatingSystemVersion|ImageBase|Characteristics|DLLCharacteristics" logs/s4-gate-headers.txt | head -12
maj=$(grep -m1 "MajorSubsystemVersion" logs/s4-gate-headers.txt | grep -oE "[0-9]+$"); min=$(grep -m1 "MinorSubsystemVersion" logs/s4-gate-headers.txt | grep -oE "[0-9]+$")
grep -q "IMAGE_SUBSYSTEM_WINDOWS_GUI" logs/s4-gate-headers.txt && [ -n "$maj" ] && { [ "$maj" -lt 6 ] || { [ "$maj" = 6 ] && [ "$min" -le 3 ]; }; } \
  && res "4. subsystem WINDOWS_GUI $maj.$min (<= 6.03)" PASS || res "4. subsystem WINDOWS_GUI, version <= 6.03 (got $maj.$min)" FAIL

echo; echo "-- 5. CFG"
# CFG is on only if the PE header has IMAGE_DLLCHARACTERISTICS_GUARD_CF. The load config's GuardFlags can say
# CF_INSTRUMENTED without it: lld-link (like link.exe) sets that when any input object was compiled with /guard:cf,
# e.g. MSVC's static CRT objects.
"$T/llvm-readobj.exe" --coff-load-config "$EXE" > logs/s4-gate-loadconfig.txt 2>&1
gf=$(grep -A2 "GuardFlags" logs/s4-gate-loadconfig.txt | tr -s ' \n' ' '); echo "   load config: ${gf:-no guard flags}"
if grep -q "IMAGE_DLL_CHARACTERISTICS_GUARD_CF" logs/s4-gate-headers.txt; then
  n=$(grep -m1 "GuardAddressTakenIatEntryCount" logs/s4-gate-loadconfig.txt | grep -oE "[0-9]+$")
  [ "${n:-0}" != 0 ] && res "5. CFG on, GuardAddressTakenIatEntryCount=$n" PASS || res "5. CFG on but GuardAddressTakenIatEntryCount=0" FAIL
else
  res "5. CFG off (no GUARD_CF DLL characteristic; Kodi sets no /guard:cf)" PASS
fi

echo; echo "-- 6. PDB"
"$T/llvm-readobj.exe" --coff-debug-directory "$EXE" | grep -E "PDBFileName|Type: CodeView" | head -3
grep -q . <("$T/llvm-readobj.exe" --coff-debug-directory "$EXE" | grep -i "PDBFileName:.*kodi.pdb") && [ -s "$BD/kodi.pdb" ] \
  && res "6. kodi.pdb exists and is named in the debug directory" PASS || res "6. kodi.pdb" FAIL

echo; echo "-- 7. C runtime of Kodi's static libraries"
mapfile -t libs < <(find "$BD/build" -name "*.lib" -not -path "*/build-*" | sort)
python -I scripts/check-crt.py --want=MT "${libs[@]}" > logs/s4-gate-crt.txt; r=$?
tail -3 logs/s4-gate-crt.txt; echo "   (${#libs[@]} libraries)"
[ $r = 0 ] && res "7. Kodi's libraries are /MT (or no CRT)" PASS || res "7. Kodi's libraries are /MT (or no CRT)" FAIL

echo; echo "-- 8. calls whose return address leaves their function (0031)"
python -I scripts/pdata-calls.py "$T/llvm-objdump.exe" "$EXE" > logs/s4-gate-pdata.txt 2>&1; r=$?
tail -4 logs/s4-gate-pdata.txt
n=$(grep -m1 "calls whose return address leaves their function:" logs/s4-gate-pdata.txt | grep -oE ": [0-9]+" | grep -oE "[0-9]+")
[ $r = 0 ] && [ "${n:-x}" = 0 ] && res "8. no call returns outside its function (0031)" PASS || res "8. calls returning outside their function: ${n:-?}" FAIL

if [ -n "$WITHPY" ]; then
  # python314.dll ships with Kodi: the same checks for it (its VERSION/RPCRT4 imports are in the run-1 copies)
  echo; echo "-- 9. python314.dll ($PYDIR)"
  P=$PYDIR/python314.dll; ok=1
  sha256sum "$P"
  python -I scripts/check-machine.py --want=0x1c4 "$P" || ok=0
  python -I scripts/check-imports.py "$T/llvm-readobj.exe" "$DEVDLLS;results/stage0-run1/dlls" "$P" > logs/s4-gate-python.txt || ok=0
  python -I scripts/apiset-resolve.py "$DEVDLLS/apisetschema.dll" --check "$T/llvm-readobj.exe" "$DEVDLLS" "$P" >> logs/s4-gate-python.txt || ok=0
  python -I scripts/pdata-calls.py "$T/llvm-objdump.exe" "$P" > logs/s4-gate-python-pdata.txt 2>&1 || ok=0
  cat logs/s4-gate-python.txt; head -2 logs/s4-gate-python-pdata.txt
  n=$(grep -m1 "calls whose return address leaves their function:" logs/s4-gate-python-pdata.txt | grep -oE ": [0-9]+" | grep -oE "[0-9]+")
  [ "${n:-x}" = 0 ] || ok=0
  [ $ok = 1 ] && res "9. python314.dll: ARMNT, imports on the device, 0031" PASS || res "9. python314.dll: ARMNT, imports on the device, 0031" FAIL
fi

echo
[ $fail = 0 ] && echo "S4 GATE (server): PASS" || echo "S4 GATE (server): FAIL"
} 2>&1 | tee $LOG | grep -E "^[0-9][a-z]?\. |S4 GATE|^== |NOT ON THE DEVICE|MISSING"
exit 0
