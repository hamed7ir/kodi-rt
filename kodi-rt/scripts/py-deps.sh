#!/bin/bash
# kodi-rt Python stage: the libraries CPython links that the Kodi prefix does not have yet, static and /MT, with
# rt2.4 and their own CMake builds.
#   arm32   xz (liblzma) and libffi (for _ctypes) into prefix/arm32
#   x64ref  xz, zlib and sqlite3 (the Stage 2/3 recipes) into prefix/x64ref, for the x64 reference interpreter
#   x64|x86 xz (liblzma) and libffi into prefix/x64 or prefix/x86 (desktop targets; the rest of those prefixes is the
#           original session's scripts/s9-prefix.sh)
# libffi: cross/cmake/libffi (clang-cl + the MSVC assemblers armasm/ml/ml64, read-only from the VS build tools).
# Usage (Git Bash): bash scripts/py-deps.sh <arm32|x64ref|x64|x86> [xz|libffi|jpeg ...]   Log: logs/py-deps-<variant>.log
set -u
export MSYS2_ARG_CONV_EXCL='*'
CMAKE="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
NINJA="D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe"
MSVCBIN="D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207/bin/Hostx64"
K=F:/kodi-rt
V=$1; shift
WHAT=("$@")
case $V in
  arm32)  TC=$K/cross/arm32-rt24.cmake; PFX=$K/prefix/arm32 ;;
  x64ref) TC=$K/cross/x64-host-rt24.cmake; PFX=$K/prefix/x64ref ;;
  x64|x86) TC=$K/cross/$V-rt24.cmake; PFX=$K/prefix/$V ;;
  *) echo "unknown variant $V"; exit 2 ;;
esac
LOG=/f/kodi-rt/logs/py-deps-$V.log
cm() { # name source-dir cmake-options...
  local name=$1 src=$2; shift 2
  local bd=$K/build/py/deps-$V-$name
  rm -rf "$bd"
  "$CMAKE" -G Ninja -S "$src" -B "$bd" -DCMAKE_MAKE_PROGRAM="$NINJA" -DCMAKE_TOOLCHAIN_FILE=$TC \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PFX -DCMAKE_POLICY_DEFAULT_CMP0091=NEW "$@"
  "$CMAKE" --build "$bd" -- -j 8
  "$CMAKE" --install "$bd"
}
if [ ${#WHAT[@]} = 0 ]; then
  [ $V = x64ref ] && WHAT=(xz zlib sqlite3) || WHAT=(xz libffi)
fi
{
  set -e
  for w in "${WHAT[@]}"; do
    case $w in
      xz) cm xz $K/src/deps/xz-5.8.3 -DBUILD_SHARED_LIBS=OFF -DXZ_NLS=OFF -DXZ_DOC=OFF -DXZ_TOOL_XZ=OFF \
            -DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF -DXZ_TOOL_LZMAINFO=OFF -DXZ_TOOL_SCRIPTS=OFF ;;
      libffi) cm libffi $K/cross/cmake/libffi -DFFI_SRC=$K/src/deps/libffi-3.5.2 -DFFI_MSVC_BIN="$MSVCBIN" \
                -DFFI_ARM_SDK_SHARED="D:/Windows Kits/10/Include/10.0.19041.0/shared" ;;
      # libjpeg-turbo 3.1.4.1 (Kodi's pin) for Pillow: static, its own CMake; SIMD required: ARM32 Neon intrinsics,
      # x86/x64 with NASM (tools/nasm, Kodi's pin 2.15.05)
      jpeg) nasm=(); [ $V = arm32 ] || nasm=(-DCMAKE_ASM_NASM_COMPILER=$K/tools/nasm/nasm.exe)
            cm jpeg $K/src/deps/libjpeg-turbo-3.1.4.1 -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=OFF \
              -DWITH_JAVA=OFF -DWITH_SIMD=ON -DREQUIRE_SIMD=ON -DWITH_CRT_DLL=OFF "${nasm[@]}" ;;
      zlib) cm zlib $K/src/deps/zlib-1.3.2 -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON -DZLIB_BUILD_TESTING=OFF ;;
      sqlite3) cm sqlite3 $K/cross/cmake/sqlite3 -DSQLITE_SRC=$K/build/s3/src/sqlite3 ;;
      *) echo "unknown dependency $w"; exit 2 ;;
    esac
  done
  echo "PY DEPS $V DONE (${WHAT[*]})"
} > "$LOG" 2>&1
rc=$?
tail -2 "$LOG"; ls $PFX/lib | grep -i "lzma\|zs.lib\|sqlite3\|ffi"
exit $rc
