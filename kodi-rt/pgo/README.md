# the arm32 pgo profile

`kodi-20261113.profdata.xz` is the profile-guided-optimization data for kodi-rt v1.0: what kodi and ffmpeg really run
on a tegra 3, counted function by function. the v1.0 release is compiled with it and with thinlto, and that is what
made 720p 10-bit x265 play at full speed on my surface rt.

| file | sha256 |
|---|---|
| `kodi-20261113.profdata.xz` (2.2 mb, xz) | `985ecdd08f4444421d80bd038f9c8749615f5e446ff832b2ae2cb936d8d6f624` |
| `kodi-20261113.profdata` (20 mb, unpacked) | `52cec96322b7bf0b08618f31450abc61f48d65927ba6f52f9f0ee61f7c58f0ae` |

## use it

unpack it (`xz -dk kodi-20261113.profdata.xz`, or 7-zip) to `build/s7/prof/kodi-20261113.profdata`, the path
`cross/kodi-rt-pgo-use.cmake` and `cross/cc-arm32-pgouse.sh` read, and build phase 2 (`RECIPE.md`, step 5).

the profile fits kodi master bffa625c with patches 0001-0015, ffmpeg 9.0.2 with `patches-ffmpeg/0001` and llvm-rt 2.4.
clang finds a static function's counts by its source path, so build from the same tree paths (`build/s7/kodi`,
`build/s7/ffmpeg-src`). functions a later patch changes just lose their profile (clang skips a function whose hash does
not match), so small patches are fine. after a new kodi or ffmpeg version, or a toolchain change in llvm's middle end,
gather a new one.

## how i made it

1. **a counting build:** kodi and ffmpeg with `-fprofile-generate` (ir level, like chromium's phase 1), from frozen
   copies of the sources. rt2.4 has the arm32 profile runtime (`clang_rt.profile-arm.lib`). a small writer
   (`tools/pgo/pgoflush.c`) saves the counts once a minute, so a crash would lose at most a minute.
2. **run it on the device:** the profiling kit sets `LLVM_PROFILE_FILE=<kit>\prof\kodi-%m.profraw` (`%m` merges every
   run into one file). 16 minutes on the surface rt: 1080p h.264, 720p 10-bit x265 with the dxva renderer, menus,
   settings, add-on installs and a skin switch, then a normal exit.
3. **merge:** `llvm-profdata merge -o kodi-20261113.profdata kodi-*.profraw` with rt2.4's llvm-profdata. one raw file,
   12 mb; the result has 67,158 functions. the hottest code was swscale turning every x265 frame into rgb and back
   (a kodi bug, fixed in 0013 before the release build), then ffmpeg's 10-bit hevc motion compensation and prediction.

the release build compiles with `-fprofile-use -flto=thin -mllvm -pgso=false`: code the profile never ran (software
h.264, the hevc loop filter, other codecs) keeps the normal `-O2` instead of being made small.
