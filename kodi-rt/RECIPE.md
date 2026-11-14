# recipe

how kodi-rt is built, stage by stage. the scripts expect the tree at `F:\kodi-rt` and run in git bash (msys2's bash
for ffmpeg's make). a full kodi build outlasts an interactive session, so the long ones start detached with
`scripts/launch-detached.ps1`. every script says in its header what it does, what it reads and where it writes.

## 0. toolchain

- llvm-rt 2.4 (clang-cl, lld-link and the llvm tools for armnt) unpacked into `tc/`: rt2.4 `0549949d` built the
  stage 2–3 libraries, `0318206a` (0032 fixed) the normal kodi build and pgo phase 1, `f6e5f8e0` (0033 + 0034 fixed)
  pgo phase 2
- msvc 14.44 (the last toolset with arm32), sdk 10.0.26100 headers with the 10.0.19041 arm32 import libs
- `cross/`: the cmake toolchain files (`arm32-rt24.cmake`, `arm32-rt24d.cmake`), the meson cross file, the compiler
  wrappers for ffmpeg and autotools, and the rsp files with the toolset pins
- stage 0 (`s0-*`, `tests/stage0`): a c++ exceptions test run on the device first, the way kodi builds c++ on windows.
  it found the toolchain's arm32 exception bugs before kodi did

## 1. sources

`s2-fetch-sources.sh` fetches every archive kodi pins (its `tools/depends` VERSION files) and checks each one's sha512
against `downloads/MANIFEST.tsv`. kodi itself is a clone of xbmc/xbmc at bffa625c.

## 2. ffmpeg (`s2-*`)

- `s2-zlib.sh`, `s2-dav1d.sh`: zlib 1.3.2 and dav1d 1.5.3 (with its neon) into `prefix/arm32`
- `s2-ffmpeg-prep.sh`: ffmpeg 9.0.2 patched the way kodi's windows build patches it, plus `patches-ffmpeg/`
- `s2-ffmpeg-arm32.sh`: ffmpeg static with kodi's windows options, neon on, built with clang-cl and clang's integrated
  assembler. it gates on config.h (not configure's summary) and builds checkasm, which ran on the device

## 3. kodi's other libraries (`s3-*`)

about 25 libraries with kodi's own recipes (its `cmake/modules/Find*.cmake` at bffa625c): `s3-cmake.sh`,
`s3-meson.sh`, `s3-small-libs.sh`, `s3-more-libs.sh`, `s3-hand-libs.sh` (small cmake projects of mine in
`cross/cmake/` where a library has no usable build system here), `s3-libdvd.sh`, `s3-libiconv.sh` and
`s3-openssl-arm32.cmd`. all static `/MT` into `prefix/arm32`; `scripts/check-crt.py` checks the runtime of every
object.

## 4. kodi (`s4-*`)

- `s4-apply-patches.sh`: a fresh kodi tree with the patches in `patches/` (the fork's commits as files; the `kodi-rt`
  branch itself is that tree), kodi's prebuilt texturepacker and `s4-host-pkgconf.sh`'s pkgconf
- `s4-cppwinrt-arm32.py`: the sdk's c++/winrt `base.h` dropped 32-bit arm; `cross/cppwinrt-arm32` puts the three arm32
  branches back
- `s4-configure.sh`, `s4-build.sh`: ninja with `cross/arm32-rt24.cmake`, every library from `prefix/arm32`
- `s4-gate.sh`: the server checks before anything goes to the device: armnt, no ucrt or vc runtime imports, every
  imported function exported by the tablet's own dlls, the pdb, `/MT`, and no call that returns outside its function
  (the 0031 check, `pdata-calls.py`)

## python (`py-*`)

cpython 3.14.10 (kodi's pin) with a cmake project of mine (`cross/cmake/python3`) that compiles pcbuild's own file
lists with clang-cl, the extension modules inside `python314.dll`: `py-prepare-src.sh`, `py-deps.sh`, `py-build.sh`.
`py-swig.sh` builds the host swig for kodi's bindings, and `py-kodi-configure.sh` turns python on in the kodi build.

## 5. pgo + thinlto (`s7-*`)

1. phase 1, counting builds from frozen copies of the patched sources (`build/s7/kodi`, `build/s7/ffmpeg-src`; phase 2
   must compile the same paths): `s7-ffmpeg-instr.sh`, then `PHASE=instr s7-configure.sh` and `s7-build.sh instr`
   (`cross/kodi-rt-pgo-instr.cmake`: `-fprofile-generate`, and `tools/pgo/pgoflush.c` writes the counts once a minute)
2. the device run with the profiling kit (`s7-package-pgo-kit.sh`): `LLVM_PROFILE_FILE=<kit>\prof\kodi-%m.profraw`,
   15 minutes of real use, a normal exit
3. `llvm-profdata merge` into `pgo/` (see its README)
4. phase 2: `s7-ffmpeg-pgo.sh`, `PHASE=use s7-configure.sh`, `s7-build.sh use` (`cross/kodi-rt-pgo-use.cmake`:
   `-fprofile-use -flto=thin -mllvm -pgso=false`, the thinlto codegen in lld-link), then `s4-gate.sh` on it

## 6. installer

`installer/build-installer.ps1` takes a full kit's `kodi\` folder and builds `Kodi-RT-Setup-<ver>-<flavor>.exe`
(`-Flavor arm32`, `x64` or `x86`), venetium's msil installer adapted for kodi. it also puts kodi rt in explorer's "open
with" for the video, music and playlist types it plays (per user). `installer/tests/test-installer.ps1` runs it end to
end in a scratch folder.

`branding/`: the purple icon (`s9-recolor-icon.py`, kodi's blue turned 85 degrees) and the splash with kodi's real
version (`s9-splash.ps1`); they are commit 0018.

## 7. x64 and x86 (`s9-*`)

the same kodi for desktop windows, from the same sources. `cross/arch.sh` picks the target for the stage 2–3 scripts
(`ARCH=x64` or `ARCH=x86`; without it they build arm32 as before), and `cross/gen-arch-files.py` writes the x64 and
x86 toolchain files (rt2.4 `f6e5f8e0`, sdk 10.0.26100 headers and libs, static `/MT`).

- `s9-prefix.sh`: every stage 2–3 library with the same scripts into `prefix/x64` or `prefix/x86`.
  `s3-font-libs.sh` (freetype, harfbuzz, fribidi, libass) and `s3-openssl.cmd` are the arm32 steps as scripts.
  `s9-nasm.sh` builds nasm 2.15.05 (kodi's pin) first: dav1d and ffmpeg get their x86 assembly, and their checkasm
  runs on the build server (x64 and x86 run there). openssl stays without assembly, as in kodi's own build
- `s9-ffmpeg.sh`: ffmpeg with kodi's options, its nasm assembly and its inline asm; checkasm runs on the build server
- python: the python stage's scripts, into `prefix/<arch>/python`
- `s9-configure.sh`, `s9-build.sh`: kodi with the arm32 options, no pgo. three changes make the desktop builds possible:
  detours is optional (0003; the driver hook needs detours and the wdk), `/NODEFAULTLIB` follows the static crt (0001),
  and `gpu_memcpy` gets clang's sse4.1 target (0017).
  x86 also gets `cross/kodi-rt-x86.cmake`: clang doesn't advertise c++20 coroutines for 32-bit x86 with the msvc abi,
  and c++/winrt's headers won't compile without the feature macro (kodi itself has no coroutines)
- `s9-package-kit.sh`: the installer's payload (kodi's data from the build, python's library from the arm32 kit);
  `s9-gate.sh` checks the exe; `tests/s9/smoke-kodi.ps1` starts it and plays a clip (it needs a session with a screen)

## device kits

`kit/` has the run scripts and readmes of the device kits (`s5-package-*.sh` make them) and the presets: the touch
keymap, estuary's touch mode, skiploopfilter. `tools/dbgrun` catches a crash with a minidump, `tools/rtprof` samples
where kodi's threads spend their time, `tools/mdump*.py` read the dumps.
