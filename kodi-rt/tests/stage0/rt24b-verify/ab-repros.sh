#!/bin/bash
# kodi-rt: the rebuilt rt2.4 (0031, 0549949d) without flags vs the run-3 rt2.4 (f4d1c311) + "-mllvm -trap-unreachable".
# Compiles the EH repros for ARM32 at /O2 and /Od with both, then compares objects, disassembly and relocations,
# and counts the noreturn calls that end a function (they must all be followed by a trap).
# Run from Git Bash: nice -n 10 bash tests/stage0/rt24b-verify/ab-repros.sh
set -u
export MSYS2_ARG_CONV_EXCL='*'
OLD=F:/kodi-rt/tc/rt24-cr/bin
NEW=F:/kodi-rt/tc/rt24b-cr/bin
R=F:/kodi-rt/tests/stage0/eh-handlers-repro
O=F:/kodi-rt/tests/stage0/rt24b-verify/out
VC="D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207"
SDK="D:/Windows Kits/10"
PIN=(-vctoolsdir "$VC" -winsdkdir "$SDK" -winsdkversion 10.0.19041.0)
CF=(--target=armv7-pc-windows-msvc "${PIN[@]}" /nologo /EHsc /GR /MT /c)
mkdir -p "$O"
fail=0
for src in h2 h3 cr nr rt; do
  for opt in O2 Od; do
    a=$O/$src-old-trap-$opt.obj; b=$O/$src-new-$opt.obj
    "$OLD/clang-cl.exe" "${CF[@]}" /$opt -mllvm -trap-unreachable "$R/$src.cpp" /Fo"$a" > "$O/$src-old-trap-$opt.log" 2>&1 || { echo "$src $opt: old compile failed"; fail=1; continue; }
    "$NEW/clang-cl.exe" "${CF[@]}" /$opt "$R/$src.cpp" /Fo"$b" > "$O/$src-new-$opt.log" 2>&1 || { echo "$src $opt: new compile failed"; fail=1; continue; }
    "$NEW/llvm-objdump.exe" -d -r "$a" | tail -n +3 > "$a.dis"
    "$NEW/llvm-objdump.exe" -d -r "$b" | tail -n +3 > "$b.dis"
    if cmp -s "$a" "$b"; then same="objects identical"
    elif cmp -s "$a.dis" "$b.dis"; then same="objects differ, disassembly+relocations identical"
    else same="DISASSEMBLY DIFFERS ($(diff "$a.dis" "$b.dis" | grep -c '^[<>]') lines)"; fail=1; fi
    # control: the run-3 rt2.4 without the flag
    c=$O/$src-old-$opt.obj
    "$OLD/clang-cl.exe" "${CF[@]}" /$opt "$R/$src.cpp" /Fo"$c" > "$O/$src-old-$opt.log" 2>&1 || { echo "$src $opt: old compile failed"; fail=1; continue; }
    "$NEW/llvm-objdump.exe" -d -r "$c" | tail -n +3 > "$c.dis"
    # calls that are the last instruction of a symbol's body (relocation lines skipped)
    count_trailing() { awk '/IMAGE_REL_/ {next} /^[0-9a-f]+ <.*>:$/ {if (prev ~ /\tblx?\t/) n++; prev=""; next} /^[ \t]+[0-9a-f]+:/ {prev=$0} END {if (prev ~ /\tblx?\t/) n++; print n+0}' "$1"; }
    traps=$(grep -c $'\ttrap' "$b.dis")
    echo "$src /$opt: $same; new: $traps traps, $(count_trailing "$b.dis") symbols ending in a call (run-3 rt2.4 without the flag: $(count_trailing "$c.dis"))"
  done
done
[ $fail = 0 ] && echo "AB-REPROS OK" || echo "AB-REPROS FAILED"
