#!/bin/bash
# kodi-rt Stage 9: nasm 2.15.05, Kodi's pin (tools/depends/native/nasm: nasm-2.15.05.tar.xz, SHA512 512f90a2...,
# checked when downloaded from mirrors.kodi.tv on 2026-11-13 after Hamed's "yes get"), built for this server (x64 host)
# with rt2.4 clang-cl into F:/kodi-rt/tools/nasm. dav1d and FFmpeg assemble their x86/x64 SIMD with it.
# nasm's Mkfiles/msvc.mak stops nmake with "cycle in dependency tree for target 'asm\nasm.obj'" (measured), so this
# compiles the makefile's own file lists (NASM = asm/nasm, LIBOBJ without disasm) directly; the generated sources are in
# the release tarball, so no Perl step is needed. MSVC configuration: config/msvc.h (picked by include/compiler.h).
# Usage (Git Bash): bash scripts/s9-nasm.sh      Log: logs/s9-nasm.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
exec > /f/kodi-rt/logs/s9-nasm.log 2>&1
echo "start $(date '+%F %T')"
RT=F:/kodi-rt/tc/rt24d-cr/bin
SRC=F:/kodi-rt/build/s9/nasm-src/nasm-2.15.05
B=F:/kodi-rt/build/s9/nasm-obj
OUT=F:/kodi-rt/tools/nasm
OBJS="stdlib/snprintf stdlib/vsnprintf stdlib/strlcpy stdlib/strnlen stdlib/strrchrnul
 nasmlib/ver nasmlib/alloc nasmlib/asprintf nasmlib/errfile nasmlib/crc64 nasmlib/md5c nasmlib/string nasmlib/nctype
 nasmlib/file nasmlib/mmap nasmlib/ilog2 nasmlib/realpath nasmlib/path nasmlib/filename nasmlib/rlimit nasmlib/zerobuf
 nasmlib/readnum nasmlib/bsi nasmlib/rbtree nasmlib/hashtbl nasmlib/raa nasmlib/saa nasmlib/strlist nasmlib/perfhash
 nasmlib/badenum common/common
 x86/insnsa x86/insnsb x86/insnsd x86/insnsn x86/regs x86/regvals x86/regflags x86/regdis x86/disp8 x86/iflag
 asm/error asm/warnings asm/floats asm/directiv asm/directbl asm/pragma asm/assemble asm/labels asm/parser asm/preproc
 asm/quote asm/pptok asm/listing asm/eval asm/exprlib asm/exprdump asm/stdscan asm/strfunc asm/tokhash asm/segalloc
 asm/preproc-nop asm/rdstrnum asm/srcfile macros/macros
 output/outform output/outlib output/legacy output/nulldbg output/nullout output/outbin output/outaout output/outcoff
 output/outelf output/outobj output/outas86 output/outrdf2 output/outdbg output/outieee output/outmacho output/codeview
 asm/nasm"
INC="-I$SRC -I$SRC/include -I$SRC/x86 -I$SRC/asm -I$SRC/disasm -I$SRC/output"
rm -rf "$B"; mkdir -p "$B" || exit 1
fail=0; list=()
for o in $OBJS; do
  obj="$B/${o//\//_}.obj"
  "$RT/clang-cl.exe" @F:/kodi-rt/cross/x64-msvc.rsp -MT -O2 -nologo -w $INC -c "$SRC/$o.c" -Fo"$obj" || { echo "COMPILE FAILED: $o"; fail=1; }
  list+=("$obj")
done
[ $fail = 0 ] || { echo "NASM BUILD FAILED"; exit 1; }
mkdir -p "$OUT"
# as the makefile: everything but asm/nasm in libnasm.lib, so the linker takes only the members it needs (nasm.obj
# defines error_file itself, and some headers' inline functions also exist as library members)
main=${list[${#list[@]}-1]}; unset 'list[${#list[@]}-1]'
"$RT/llvm-lib.exe" -nologo -out:"$B/libnasm.lib" "${list[@]}" || { echo "LIB FAILED"; exit 1; }
"$RT/lld-link.exe" @F:/kodi-rt/cross/x64-link.rsp -nologo -subsystem:console -out:"$OUT/nasm.exe" "$main" "$B/libnasm.lib" \
  || { echo "LINK FAILED"; exit 1; }
cp -f "$SRC/LICENSE" "$OUT/LICENSE.txt"
"$OUT/nasm.exe" -v || { echo "nasm.exe does not run"; exit 1; }
# a smoke test: assemble one AVX2 and one AVX-512 instruction for win64
printf 'bits 64\nsection .text\nvpaddd ymm0, ymm1, ymm2\nvpaddd zmm0, zmm1, zmm2\nret\n' > "$B/t.asm"
"$OUT/nasm.exe" -f win64 -o "$B/t.obj" "$B/t.asm" && "$RT/llvm-objdump.exe" -d "$B/t.obj" | grep -E "vpaddd|ret"
echo "NASM DONE $(date '+%F %T')"
