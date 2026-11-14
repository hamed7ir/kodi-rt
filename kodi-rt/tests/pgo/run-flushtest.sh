#!/bin/bash
# kodi-rt: x64 test of tools/pgo/pgoflush.c (the instrumented Kodi's once-a-minute profile writer), with a 1 s interval.
#   exit:   normal exit, %m in LLVM_PROFILE_FILE  -> work() counted exactly N times (periodic writes + exit write)
#   kill:   TerminateProcess, %m                  -> 0 < count < N (the last periodic write survives)
#   plain:  normal exit, no %m                    -> exactly N (the writer stays idle)
#   noflush: normal exit, without pgoflush        -> exactly N (control)
# The clang runtime folder goes FIRST on the link path: the MSVC x64 lib folder has its own, older
# clang_rt.profile-x86_64.lib (raw profile version 10; this compiler writes 11, so that runtime refuses to write:
# "Runtime and instrumentation version mismatch"). The MSVC ARM lib folder has no clang_rt libraries.
# Usage (Git Bash): bash tests/pgo/run-flushtest.sh        Output: build/s7/tests/flushtest
set -u
export MSYS2_ARG_CONV_EXCL='*'
RT=F:/kodi-rt/tc/rt24c-cr/bin
CRT=F:/kodi-rt/tc/rt24c-cr/lib/clang/23/lib/windows
O=F:/kodi-rt/build/s7/tests/flushtest
N=3500
mkdir -p "$O" && cd "$O" || exit 1
rm -f ./*.profraw ./*.obj ./*.exe
CC="$RT/clang-cl.exe @F:/kodi-rt/cross/x64-msvc.rsp -MT -O2"
$CC -DKODIRT_PGO_FLUSH_MS=1000 -c F:/kodi-rt/tools/pgo/pgoflush.c -Fo$O/pgoflush.obj || exit 1
$CC -fprofile-generate -c F:/kodi-rt/tests/pgo/flushtest.c -Fo$O/flushtest.obj || exit 1
"$RT/lld-link.exe" -libpath:$CRT @F:/kodi-rt/cross/x64-link.rsp -out:$O/flushtest.exe $O/flushtest.obj $O/pgoflush.obj || exit 1
"$RT/lld-link.exe" -libpath:$CRT @F:/kodi-rt/cross/x64-link.rsp -out:$O/noflush.exe $O/flushtest.obj || exit 1

count () {  # profraw -> work()'s entry count (IR profile: its single block's count)
  "$RT/llvm-profdata.exe" show --counts --function=work "$1" 2>&1 | awk -F'[][]' '/Block counts:/ {print $2; exit}'
}
FAIL=0
check () {  # name, value, condition
  if eval "$3"; then echo "  OK    $1: work() counted $2 times ($3)"; else echo "  FAIL  $1: work() counted '$2' times, want $3"; FAIL=$((FAIL+1)); fi
}

LLVM_PROFILE_FILE="$O/exit-%m.profraw" ./flushtest.exe $N 4
v=$(count "$(ls exit-*.profraw | head -1)"); check exit "$v" "[ \"$v\" = $N ]"

LLVM_PROFILE_FILE="$O/kill-%m.profraw" ./flushtest.exe $N 4 kill
f=$(ls kill-*.profraw 2>/dev/null | head -1)
if [ -n "$f" ]; then v=$(count "$f"); else v=0; fi
check kill "$v" "[ \"$v\" -gt 0 ] && [ \"$v\" -lt $N ]"

LLVM_PROFILE_FILE="$O/plain.profraw" ./flushtest.exe $N 4
v=$(count plain.profraw); check plain "$v" "[ \"$v\" = $N ]"

LLVM_PROFILE_FILE="$O/noflush-%m.profraw" ./noflush.exe $N 2
v=$(count "$(ls noflush-*.profraw | head -1)"); check noflush "$v" "[ \"$v\" = $N ]"

ls -la ./*.profraw
[ $FAIL -eq 0 ] && echo "FLUSHTEST PASSED" || { echo "FLUSHTEST FAILED ($FAIL)"; exit 1; }
