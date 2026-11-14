#!/bin/bash
# kodi-rt Stage 3: GNU libiconv 1.18 (Kodi's pin), static, /MT, rt2.4, into F:/kodi-rt/prefix/$ARCH (cross/arch.sh:
# arm32 by default, or ARCH=x64 / ARCH=x86). libiconv's own MSVC recipe (INSTALL.windows: configure with
# build-aux/compile and build-aux/ar-lib around cl), with cross/autotools-$ARCH/clang-cl as the compiler, a MinGW-style
# --host for the target, and Kodi's depends options
# (--disable-shared --enable-extra-encodings). Out-of-tree build. CMake's FindIconv (which Kodi and libass use) looks
# for iconv.lib or libiconv.lib, so the static library is also installed under those names.
# Run with MSYS2's bash (GNU make), detached or from a session: bash /f/kodi-rt/scripts/s3-libiconv.sh
# (ARCH=x64 bash /f/kodi-rt/scripts/s3-libiconv.sh for x64). Build dir $A_B3/libiconv-$ARCH, log
# $A_LOG3-libiconv.log (arm32: build/s3/libiconv-arm32, logs/s3-libiconv.log).
set -u
source /f/kodi-rt/cross/arch.sh
unset MSYS2_ARG_CONV_EXCL
exec > $A_LOG3-libiconv.log 2>&1
echo "start $(date '+%F %T')"
export PATH="/usr/bin:/usr/local/bin:$PATH"
S=/f/kodi-rt/src/deps/libiconv-1.18
B=/f${A_B3#F:}/libiconv-$ARCH
PFX=/f/kodi-rt/prefix/$ARCH
RT=$A_RT/bin
rm -rf "$B"; mkdir -p "$B"; cd "$B" || exit 1
"$S/configure" --host=$A_HOST --prefix="$PFX" --disable-shared --enable-static --enable-extra-encodings \
  --disable-nls \
  CC="$S/build-aux/compile /f/kodi-rt/cross/autotools-$ARCH/clang-cl -nologo" CFLAGS="-MT -O2" \
  CXX="$S/build-aux/compile /f/kodi-rt/cross/autotools-$ARCH/clang-cl -nologo" CXXFLAGS="-MT -O2" \
  CPPFLAGS="-D_WIN32_WINNT=0x0603" LD="$RT/lld-link.exe" NM="$RT/llvm-nm.exe" STRIP=":" \
  AR="$S/build-aux/ar-lib $RT/llvm-lib.exe" RANLIB=":"
rc=$?; echo "===CONFIGURE EXIT=$rc==="
[ $rc -eq 0 ] || { tail -40 config.log; echo "CONFIGURE FAILED"; exit 1; }
make -j8 OBJECTS_RES_yes= || { echo "MAKE FAILED"; exit 1; }
make install OBJECTS_RES_yes= || { echo "INSTALL FAILED"; exit 1; }
ls -la "$PFX/lib" | grep -iE 'iconv|charset'
for f in libiconv libcharset; do
  for e in a lib; do [ -f "$PFX/lib/$f.$e" ] && { cp -f "$PFX/lib/$f.$e" "$PFX/lib/${f#lib}.lib"; [ "$e" = a ] && cp -f "$PFX/lib/$f.a" "$PFX/lib/$f.lib"; break; }; done
done
ls -la "$PFX/lib" | grep -iE 'iconv|charset'
echo "LIBICONV DONE $(date '+%F %T')"
