# kodi-rt INTERIM, remove when rt2.4 has the fix for toolchain bug 0032 (reports/toolchain/HANDOFF.md).
# Injected into Kodi's configure with -DCMAKE_PROJECT_kodi_INCLUDE (scripts/s4-configure.sh, KODIRT_0032_WORKAROUND).
# 0032: ARMConstantIslands doesn't count the alignment WinException emits before each EH funclet, so a constant pool
# placed after many funclets can end up out of range: "error: out of range pc-relative fixup value" (rt2.4 0549949d;
# Kodi's InputManager.cpp, then PVRClient.cpp once other errors were gone). So it is not a one-file problem.
# -mllvm -align-all-blocks=2 gives EVERY block 4-byte alignment in MachineBlockPlacement, funclet entries included, so
# the alignment beginFunclet emits is already the blocks' own and ARMConstantIslands counts it. Checked: the 41-line
# repro, InputManager's IR and PVRClient.cpp build with it. Cost: nops at block starts (code size, some speed), so it is
# for the server-side gate and link work only; device builds wait for the fixed toolchain. Correctness is not at risk:
# MC range-checks every pc-relative fixup. (-align-all-nofallthru-blocks=2 is NOT enough: it is decided before the
# funclets are moved to the end, and a funclet's EH predecessor counts as a fall-through.)
add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:SHELL:-mllvm -align-all-blocks=2>")
message(STATUS "kodi-rt INTERIM 0032: all C++ compiled with -mllvm -align-all-blocks=2")
