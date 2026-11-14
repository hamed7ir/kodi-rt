#!/bin/bash
# kodi-rt Stage 9 gate for the x64/x86 kodi.exe (the ARM32 gate scripts/s4-gate.sh, minus its device-DLL and 0031
# checks, which are ARM32 things):
#   1. machine x64 (0x8664) or x86 (0x14c)                                   scripts/check-machine.py
#   2. imports: no api-ms-win-crt-*, ucrtbase.dll, vcruntime140*, msvcp140* (/MT leaves none: no VC runtime needed)
#   3. every imported function (normal and delay-load) is exported by this server's Windows DLLs (System32, or SysWOW64
#      for x86). Windows Server 2022 has more than 8.1, so this proves presence, not the 8.1 floor; Kodi builds with
#      _WIN32_WINNT_WINBLUE                                                  scripts/check-imports.py
#   4. subsystem WINDOWS_GUI, version <= 6.03
#   5. the PDB: kodi.pdb exists and is the one the debug directory names
#   6. C runtime of Kodi's own static libraries: /MT (LIBCMT) or none     scripts/check-crt.py
#   7. python314.dll (when Kodi was built with Python): machine type, no UCRT/VC runtime imports, imports present
# Usage (Git Bash): bash scripts/s9-gate.sh x64|x86      Output: logs/s9-gate-<arch>.log; last line "S9 GATE <arch>: PASS"
set -u
export MSYS2_ARG_CONV_EXCL='*'
cd /f/kodi-rt || exit 1
A=${1:?usage: s9-gate.sh x64|x86}
case $A in x64) M=0x8664; SYS=C:/Windows/System32 ;; x86) M=0x14c; SYS=C:/Windows/SysWOW64 ;; *) echo "x64 or x86"; exit 1 ;; esac
BD=build/s9/kodi-build-$A
T=F:/kodi-rt/tc/rt24d-cr/bin
EXE=$BD/kodi.exe
L=logs/s9-gate-$A
fail=0
res() { printf '%-62s %s\n' "$1" "$2"; [ "$2" = PASS ] || [ "${3:-}" = info ] || fail=1; }
nocrt() { # readobj imports file -> the UCRT/VC runtime DLLs it names
  grep -oiE "Name: (api-ms-win-crt-[^ ]*|ucrtbase\.dll|vcruntime140[^ ]*|msvcp140[^ ]*|concrt140\.dll)" "$1" | sort -u; }
{
echo "== kodi-rt Stage 9 gate $A $(date '+%F %T'), image $EXE"
[ -f "$EXE" ] || { echo "no $EXE"; echo "S9 GATE $A: FAIL"; exit 1; }
ls -la "$EXE" "$BD/kodi.pdb" 2>&1
sha256sum "$EXE" 2>/dev/null

echo; echo "-- 1. machine"
python -I scripts/check-machine.py --want=$M "$EXE" && res "1. machine $M ($A)" PASS || res "1. machine $M ($A)" FAIL

echo; echo "-- 2. imported DLLs"
"$T/llvm-readobj.exe" --coff-imports "$EXE" > $L-imports.txt
grep -E "^\s*Name: " $L-imports.txt | sort | uniq -c | sort -rn | head -40
bad=$(nocrt $L-imports.txt)
[ -z "$bad" ] && res "2. no UCRT/VC runtime DLL imports" PASS || { echo "$bad"; res "2. no UCRT/VC runtime DLL imports" FAIL; }

echo; echo "-- 3. imported functions vs $SYS"
PYDIR=prefix/$A/python
WITHPY=; grep -qi "Name: python314.dll" $L-imports.txt && WITHPY=1
python -I scripts/check-imports.py "$T/llvm-readobj.exe" "$SYS${WITHPY:+;$PYDIR}" "$EXE" > $L-functions.txt; r=$?
tail -5 $L-functions.txt
[ $r = 0 ] && res "3. all imported functions exported by this Windows" PASS || res "3. all imported functions exported by this Windows" FAIL

echo; echo "-- 4. subsystem"
"$T/llvm-readobj.exe" --file-headers "$EXE" > $L-headers.txt
grep -E "Subsystem|SubsystemVersion|OperatingSystemVersion|DLLCharacteristics" $L-headers.txt | head -8
maj=$(grep -m1 "MajorSubsystemVersion" $L-headers.txt | grep -oE "[0-9]+$"); min=$(grep -m1 "MinorSubsystemVersion" $L-headers.txt | grep -oE "[0-9]+$")
grep -q "IMAGE_SUBSYSTEM_WINDOWS_GUI" $L-headers.txt && [ -n "$maj" ] && { [ "$maj" -lt 6 ] || { [ "$maj" = 6 ] && [ "$min" -le 3 ]; }; } \
  && res "4. subsystem WINDOWS_GUI $maj.$min (<= 6.03)" PASS || res "4. subsystem WINDOWS_GUI, version <= 6.03 (got $maj.$min)" FAIL

echo; echo "-- 5. PDB"
"$T/llvm-readobj.exe" --coff-debug-directory "$EXE" | grep -E "PDBFileName" | head -2
grep -q . <("$T/llvm-readobj.exe" --coff-debug-directory "$EXE" | grep -i "PDBFileName:.*kodi.pdb") && [ -s "$BD/kodi.pdb" ] \
  && res "5. kodi.pdb exists and is named in the debug directory" PASS || res "5. kodi.pdb" FAIL

echo; echo "-- 6. C runtime of Kodi's static libraries"
mapfile -t libs < <(find "$BD/build" -name "*.lib" -not -path "*/build-*" | sort)
python -I scripts/check-crt.py --want=MT "${libs[@]}" > $L-crt.txt; r=$?
tail -3 $L-crt.txt; echo "   (${#libs[@]} libraries)"
[ $r = 0 ] && res "6. Kodi's libraries are /MT (or no CRT)" PASS || res "6. Kodi's libraries are /MT (or no CRT)" FAIL

if [ -n "$WITHPY" ]; then
  echo; echo "-- 7. python314.dll ($PYDIR)"
  P=$PYDIR/python314.dll; ok=1
  sha256sum "$P"
  python -I scripts/check-machine.py --want=$M "$P" || ok=0
  "$T/llvm-readobj.exe" --coff-imports "$P" > $L-python-imports.txt
  [ -z "$(nocrt $L-python-imports.txt)" ] || { nocrt $L-python-imports.txt; ok=0; }
  python -I scripts/check-imports.py "$T/llvm-readobj.exe" "$SYS" "$P" > $L-python.txt || ok=0
  tail -3 $L-python.txt
  [ $ok = 1 ] && res "7. python314.dll: $A, no VC runtime, imports present" PASS || res "7. python314.dll: $A, no VC runtime, imports present" FAIL
else
  res "7. (Kodi built without Python)" CHECK info
fi

echo
[ $fail = 0 ] && echo "S9 GATE $A: PASS" || echo "S9 GATE $A: FAIL"
} 2>&1 | tee $L.log | grep -E "^[0-9][a-z]?\. |S9 GATE|^== |MISSING|NOT ON THE DEVICE LIST"
exit 0
