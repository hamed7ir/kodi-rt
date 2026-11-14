#!/bin/bash
# kodi-rt Python stage: the host SWIG that generates Kodi's Python bindings. Kodi pins swig 4.5.0 with PCRE2 10.47
# (tools/depends/native/{swig,pcre2}). Kodi's own -DENABLE_INTERNAL_SWIG sets CMAKE_GENERATOR_PLATFORM, which the
# Ninja generator rejects, so SWIG is built here (x64, rt2.4, static) and Kodi gets -DSWIG_EXECUTABLE. SWIG's CMake
# build also wants bison, which this host lacks: it builds from a copy using the release's generated parser.
# Output: build/py/host/bin/swig.exe (+ share/swig/4.5.0). Usage (Git Bash): bash scripts/py-swig.sh
# Log: logs/py-swig.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
K=F:/kodi-rt
H=$K/build/py/host
TC=$K/cross/x64-host-rt24.cmake
LOG=/f/kodi-rt/logs/py-swig.log
{
  set -e
  cd /f/kodi-rt/src/deps
  [ -d pcre2-10.47 ] || tar -xf ../../downloads/sources/pcre2-10.47.tar.bz2
  [ -d swig-4.5.0 ] || tar -xf ../../downloads/sources/swig-4.5.0.tar.gz
  # SWIG's CMake build wants bison: build from a copy that uses the release's generated parser (py-swig-edits.py)
  rm -rf /f/kodi-rt/build/py/src/swig-4.5.0 && mkdir -p /f/kodi-rt/build/py/src
  cp -r swig-4.5.0 /f/kodi-rt/build/py/src/
  python -I $K/scripts/py-swig-edits.py $K/build/py/src/swig-4.5.0
  rm -rf $K/build/py/host-pcre2 $K/build/py/host-swig $H
  "$CMAKE" -G Ninja -S $K/src/deps/pcre2-10.47 -B $K/build/py/host-pcre2 -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=$TC -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$H -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DBUILD_SHARED_LIBS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF -DPCRE2_SUPPORT_JIT=OFF
  "$CMAKE" --build $K/build/py/host-pcre2 -- -j 8
  "$CMAKE" --install $K/build/py/host-pcre2
  "$CMAKE" -G Ninja -S $K/build/py/src/swig-4.5.0 -B $K/build/py/host-swig -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE=$TC -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$H -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
    -DWITH_PCRE=ON -DCMAKE_PREFIX_PATH=$H -DPCRE2_STATIC=ON
  "$CMAKE" --build $K/build/py/host-swig -- -j 8
  "$CMAKE" --install $K/build/py/host-swig
  $H/bin/swig.exe -version
  echo "SWIG DONE"
} > "$LOG" 2>&1
rc=$?
tail -6 "$LOG"
exit $rc
