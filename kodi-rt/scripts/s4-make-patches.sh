#!/bin/bash
# kodi-rt Stage 4: regenerate patches/0001-0016 from scripts/s4-dev-edits.py.
#   resets the patch-development clone build/s4/kodi-dev to the pinned commit, applies the edits, and writes one
#   patch per topic (git diff of that topic's files). Usage (Git Bash): bash scripts/s4-make-patches.sh [outdir]
set -u
cd /f/kodi-rt || exit 1
D=build/s4/kodi-dev
OUT=${1:-patches}
[ -d "$D/.git" ] || git clone -q --no-hardlinks src/xbmc "$D" || exit 1
git -C "$D" reset -q --hard bffa625cc84860f241772d87a654844b98bebb60 || exit 1
[ -z "$(git -C "$D" status --porcelain)" ] || { echo "dev clone not clean"; exit 1; }
python -I scripts/s4-dev-edits.py F:/kodi-rt/$D || exit 1
mkdir -p "$OUT"
mk() { local name=$1; shift; git -C "$D" diff -- "$@" > "$OUT/$name"; echo "$OUT/$name: $(grep -c '^diff --git' "$OUT/$name") files, $(wc -l < "$OUT/$name") lines"; }
mk 0001-windows-arm32-cmake.patch cmake/platform/windows/windows.cmake cmake/scripts/windows/ArchSetup.cmake \
   cmake/scripts/windows/CFlagOverrides.cmake cmake/scripts/windows/CXXFlagOverrides.cmake xbmc/platform/win32/utils/CMakeLists.txt
mk 0002-windows-arm32-sources.patch xbmc/addons/addoninfo/AddonInfoBuilder.cpp xbmc/platform/win32/CPUInfoWin32.cpp \
   xbmc/platform/win32/threads/Win32Exception.cpp
mk 0003-windows-arm32-no-detours-hook.patch xbmc/windowing/windows/WinSystemWin32DX.cpp
mk 0004-windows-external-ffmpeg.patch cmake/modules/FindFFMPEG.cmake
mk 0005-windows-fribidi-target-for-libass.patch cmake/modules/FindFriBidi.cmake
mk 0006-windows-clang-cl-whole-archive.patch cmake/scripts/common/ProjectMacros.cmake
mk 0007-clang-cl-log-overload.patch xbmc/utils/log.h
mk 0008-windows-clang-strictness.patch xbmc/rendering/dx/DeviceResources.cpp \
   xbmc/cores/VideoPlayer/VideoRenderers/WinRenderer.cpp xbmc/cores/ExternalPlayer/ExternalPlayer.cpp
mk 0009-conversionmatrix-explicit-instantiation.patch xbmc/cores/VideoPlayer/VideoRenderers/VideoShaders/ConversionMatrix.cpp
mk 0010-windows-touch-taps.patch xbmc/windowing/windows/WinEventsWin32.cpp
mk 0011-estuary-osd-fullscreen-button.patch addons/skin.estuary/xml/VideoOSD.xml
mk 0012-filestreambuffer-seek-check.patch xbmc/filesystem/File.cpp
mk 0013-videocodec-ffmpeg-keep-skiploopfilter.patch xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecFFmpeg.cpp \
   xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecFFmpeg.h
mk 0014-windows-8bit-render-formats-without-r16.patch xbmc/cores/VideoPlayer/Process/windows/ProcessInfoWin.cpp \
   xbmc/rendering/dx/RenderSystemDX.cpp
mk 0015-windows-arm32-render-thread-priority.patch xbmc/platform/win32/WinMain.cpp \
   xbmc/cores/VideoPlayer/VideoRenderers/windows/RendererBase.cpp xbmc/cores/VideoPlayer/VideoPlayerVideo.cpp
mk 0016-windows-clang-gpu-memcpy-sse41-target.patch xbmc/platform/win32/utils/gpu_memcpy_sse4.h
# every changed file must be in exactly one patch
all=$(git -C "$D" diff --name-only | sort); inp=$(cat "$OUT"/00[01][0-9]-*.patch | sed -n 's#^diff --git a/\([^ ]*\) .*#\1#p' | sort)
[ "$all" = "$inp" ] || { echo "CHANGED FILES NOT COVERED:"; diff <(echo "$all") <(echo "$inp"); exit 1; }
echo "PATCHES DONE"
