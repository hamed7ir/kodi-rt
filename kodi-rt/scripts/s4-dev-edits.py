# kodi-rt Stage 4: the source edits behind patches/0001-0016 (the layered ones, 0017 on, are in s4-dev-edits-2.py),
# applied to the patch-development clone
# build/s4/kodi-dev (a local git clone of src/xbmc at bffa625c). Each replacement must match exactly once.
# The patches themselves (git diff of the result, split by topic) are the record; this script makes them reproducible.
# Usage: python -I scripts/s4-dev-edits.py F:/kodi-rt/build/s4/kodi-dev
import sys, os

root = sys.argv[1]

def edit(rel, old, new):
    p = os.path.join(root, rel)
    s = open(p, encoding='utf-8', newline='').read()
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{rel}: expected 1 match, found {n}:\n{old}')
    open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
    print(f'edited {rel}')

# ---------------------------------------------------------------- 0001: CMake (recon rows 1, 2, 4, 5, 6, 10, 12)
edit('cmake/scripts/windows/ArchSetup.cmake',
     'if(CMAKE_GENERATOR_PLATFORM STREQUAL arm64)\n  set(ARCH arm64)\n  set(SDK_TARGET_ARCH arm64)\n',
     'if(CMAKE_GENERATOR_PLATFORM STREQUAL arm64)\n  set(ARCH arm64)\n  set(SDK_TARGET_ARCH arm64)\n'
     'elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL arm AND CMAKE_SIZEOF_VOID_P EQUAL 4)\n'
     '  # kodi-rt: Windows ARM32 (Windows RT 8.1). Built with Ninja and a toolchain file, where\n'
     '  # CMAKE_GENERATOR_PLATFORM is empty, so the toolchain\'s CMAKE_SYSTEM_PROCESSOR decides.\n'
     '  set(ARCH arm)\n  set(SDK_TARGET_ARCH arm)\n')
edit('cmake/scripts/windows/ArchSetup.cmake',
     'set(DEPENDS_PATH ${CMAKE_SOURCE_DIR}/${DEPS_FOLDER_RELATIVE}/${ARCH})\n',
     '# kodi-rt: an existing DEPENDS_PATH (-DDEPENDS_PATH=<prefix>) wins over the default folder\n'
     'if(NOT DEFINED DEPENDS_PATH)\n  set(DEPENDS_PATH ${CMAKE_SOURCE_DIR}/${DEPS_FOLDER_RELATIVE}/${ARCH})\nendif()\n')
edit('cmake/scripts/windows/ArchSetup.cmake',
     '# Do not add SSE flags for ARM64\nif(NOT CMAKE_GENERATOR_PLATFORM STREQUAL arm64)\n',
     '# Do not add SSE flags for ARM64 (kodi-rt: nor ARM32)\nif(NOT CMAKE_GENERATOR_PLATFORM STREQUAL arm64 AND NOT ARCH STREQUAL arm)\n')
edit('cmake/scripts/windows/ArchSetup.cmake',
     'list(APPEND DEPLIBS bcrypt d3d11.lib DInput8.lib DSound.lib winmm.lib',
     '# kodi-rt: no DInput8.lib for ARM32 (SDK 10.0.19041 has no um\\arm\\dinput8.lib; no Kodi source uses DirectInput)\n'
     'if(NOT ARCH STREQUAL arm)\n  list(APPEND DEPLIBS DInput8.lib)\nendif()\n'
     'list(APPEND DEPLIBS bcrypt d3d11.lib DSound.lib winmm.lib')
edit('cmake/scripts/windows/ArchSetup.cmake',
     '# NODEFAULTLIB option\nset(_nodefaultlibs_RELEASE libcmt)\nset(_nodefaultlibs_DEBUG libcmt msvcrt)\n',
     '# NODEFAULTLIB option\n'
     'if(ARCH STREQUAL arm)\n'
     '  # kodi-rt: ARM32 links the static CRT (/MT), whose library IS libcmt; keep the DLL CRTs out instead\n'
     '  set(_nodefaultlibs_RELEASE msvcrt)\n  set(_nodefaultlibs_DEBUG msvcrtd)\n'
     'else()\n'
     '  set(_nodefaultlibs_RELEASE libcmt)\n  set(_nodefaultlibs_DEBUG libcmt msvcrt)\n'
     'endif()\n')

for lang, extra in (('C', ''), ('CXX', ' /GR')):
    rel = f'cmake/scripts/windows/{lang}FlagOverrides.cmake'
    edit(rel,
         f'  set(CMAKE_{lang}_FLAGS_RELEASE "/MD /Ox /Ob2 /Oi /Ot /Oy /GL /DNDEBUG")\nendif()\n',
         f'  set(CMAKE_{lang}_FLAGS_RELEASE "/MD /Ox /Ob2 /Oi /Ot /Oy /GL /DNDEBUG")\n'
         f'  if(CMAKE_SYSTEM_PROCESSOR STREQUAL arm)\n'
         f'    # kodi-rt: Windows ARM32 with clang-cl. The lines above would replace the toolchain file\'s flags\n'
         f'    # (--target, -vctoolsdir/-winsdkdir pins), so keep CMAKE_{lang}_FLAGS_INIT in front. /MT: Windows RT 8.1\n'
         f'    # has no UCRT or VC runtime DLLs. No /GL (LTO is off until Kodi runs), no /MP (clang-cl ignores it).\n'
         f'    set(CMAKE_{lang}_FLAGS "${{CMAKE_{lang}_FLAGS_INIT}} /D_UNICODE /DUNICODE /utf-8 /DRPC_USE_NATIVE_WCHAR /DWIN32 /D_WINDOWS /W3{extra} /Zi'
         + (' /EHsc' if lang == 'CXX' else '') + '")\n'
         f'    set(CMAKE_{lang}_FLAGS_DEBUG "/D_DEBUG /MTd /Ob0 /Od /D_ITERATOR_DEBUG_LEVEL=0")\n'
         f'    set(CMAKE_{lang}_FLAGS_RELEASE "/MT /Ox /Ob2 /Oi /Ot /Oy /DNDEBUG")\n'
         f'  endif()\nendif()\n')

edit('cmake/platform/windows/windows.cmake',
     'set(PLATFORM_REQUIRED_DEPS Detours Effects11)\n',
     '# kodi-rt: no Detours for ARM32: its only user, the D3D driver hook in WinSystemWin32DX.cpp, is compiled out there\n'
     'if(CMAKE_SYSTEM_PROCESSOR STREQUAL arm)\n  set(PLATFORM_REQUIRED_DEPS Effects11)\nelse()\n'
     '  set(PLATFORM_REQUIRED_DEPS Detours Effects11)\nendif()\n')
edit('xbmc/platform/win32/utils/CMakeLists.txt',
     '# Do not add SSE headers for ARM64\nif(NOT CMAKE_GENERATOR_PLATFORM STREQUAL arm64)\n',
     '# Do not add SSE headers for ARM64 (kodi-rt: nor ARM32)\nif(NOT CMAKE_GENERATOR_PLATFORM STREQUAL arm64 AND NOT CMAKE_SYSTEM_PROCESSOR STREQUAL arm)\n')

# 0001 additions for the x64/x86 builds (the original session's, 2026-11-13: reports/proposed-edits/detours-optional.py
# and static-crt-nodefaultlib.py; verified there by compile, link and gate in build/s9/kodi for x64 and x86).
# Detours becomes an optional dependency on every architecture (the 0003 driver hook is compiled out without
# detours.h + d3d10umddi.h), and the NODEFAULTLIB choice follows the static CRT (CMAKE_MSVC_RUNTIME_LIBRARY
# MultiThreaded, which every kodi-rt toolchain file sets) instead of ARCH arm. ARM32 configures and links as before.
edit('cmake/platform/windows/windows.cmake',
     '# kodi-rt: no Detours for ARM32: its only user, the D3D driver hook in WinSystemWin32DX.cpp, is compiled out there\n'
     'if(CMAKE_SYSTEM_PROCESSOR STREQUAL arm)\n'
     '  set(PLATFORM_REQUIRED_DEPS Effects11)\n'
     'else()\n'
     '  set(PLATFORM_REQUIRED_DEPS Detours Effects11)\n'
     'endif()\n',
     '# kodi-rt: Detours is optional: its only user, the D3D driver hook in WinSystemWin32DX.cpp, is compiled out without it\n'
     'set(PLATFORM_REQUIRED_DEPS Effects11)\n'
     'list(APPEND PLATFORM_OPTIONAL_DEPS Detours)\n')
edit('cmake/scripts/windows/ArchSetup.cmake',
     'if(ARCH STREQUAL arm)\n'
     '  # kodi-rt: ARM32 links the static CRT (/MT), whose library IS libcmt; keep the DLL CRTs out instead\n',
     'if(CMAKE_MSVC_RUNTIME_LIBRARY STREQUAL "MultiThreaded")\n'
     '  # kodi-rt: the static CRT (/MT, kodi-rt\'s toolchain files), whose library IS libcmt; keep the DLL CRTs out instead\n')

# ---------------------------------------------------------------- 0002: sources (recon rows 7, 8, 9)
edit('xbmc/addons/addoninfo/AddonInfoBuilder.cpp',
     '#elif defined(_M_ARM64)\n    "windows-arm64",\n#else\n',
     '#elif defined(_M_ARM64)\n    "windows-arm64",\n#elif defined(_M_ARM)\n    "windows-arm", // kodi-rt: Windows RT 8.1 (ARM32)\n#else\n')
edit('xbmc/platform/win32/CPUInfoWin32.cpp',
     '#ifndef _M_ARM64\n  int CPUInfo[4]',
     '#if !defined(_M_ARM64) && !defined(_M_ARM) // kodi-rt: __cpuid is x86/x64 only\n  int CPUInfo[4]')
edit('xbmc/platform/win32/threads/Win32Exception.cpp',
     '#elif defined(_M_ARM64)\n  frame.AddrPC.Offset = pEp->ContextRecord->Pc; // Current location in program\n',
     '#elif defined(_M_ARM)\n'
     '  // kodi-rt: Windows ARM32 CONTEXT: Pc, Sp, and R11 as the frame pointer\n'
     '  frame.AddrPC.Offset = pEp->ContextRecord->Pc; // Current location in program\n'
     '  frame.AddrStack.Offset = pEp->ContextRecord->Sp; // Stack pointers current value\n'
     '  frame.AddrFrame.Offset = pEp->ContextRecord->R11; // Value of register used to access local function variables.\n'
     '#elif defined(_M_ARM64)\n  frame.AddrPC.Offset = pEp->ContextRecord->Pc; // Current location in program\n')
edit('xbmc/platform/win32/threads/Win32Exception.cpp',
     '  while(pSW(IMAGE_FILE_MACHINE_I386, hCurProc,',
     '#if defined(_M_ARM)\n  const DWORD stackWalkMachine = IMAGE_FILE_MACHINE_ARMNT; // kodi-rt\n#else\n'
     '  const DWORD stackWalkMachine = IMAGE_FILE_MACHINE_I386;\n#endif\n'
     '  while(pSW(stackWalkMachine, hCurProc,')

# ---------------------------------------------------------------- 0003: the Detours/WDK driver hook (recon row 12)
W = 'xbmc/windowing/windows/WinSystemWin32DX.cpp'
edit(W, '#pragma warning(disable: 4091)\n#include <d3d10umddi.h>\n#pragma warning(default: 4091)\n#include <detours.h>\n',
     '#if !defined(_M_ARM) // kodi-rt: no Detours/WDK headers for ARM32; the driver hook is compiled out\n'
     '#pragma warning(disable: 4091)\n#include <d3d10umddi.h>\n#pragma warning(default: 4091)\n#include <detours.h>\n#endif\n')
edit(W, 'void APIENTRY HookCreateResource(D3D10DDI_HDEVICE hDevice, const D3D10DDIARG_CREATERESOURCE* pResource, D3D10DDI_HRESOURCE hResource, D3D10DDI_HRTRESOURCE hRtResource);\n',
     '#if !defined(_M_ARM)\n'
     'void APIENTRY HookCreateResource(D3D10DDI_HDEVICE hDevice, const D3D10DDIARG_CREATERESOURCE* pResource, D3D10DDI_HRESOURCE hResource, D3D10DDI_HRTRESOURCE hRtResource);\n')
edit(W, 'static PFND3D10DDI_CREATERESOURCE s_fnCreateResourceOrig{ nullptr };\n',
     'static PFND3D10DDI_CREATERESOURCE s_fnCreateResourceOrig{ nullptr };\n#endif\n')
edit(W, 'void CWinSystemWin32DX::UninitHooks()\n{\n',
     'void CWinSystemWin32DX::UninitHooks()\n{\n#if !defined(_M_ARM)\n')
edit(W, '    FreeLibrary(m_hDriverModule);\n    m_hDriverModule = nullptr;\n  }\n}\n\nvoid CWinSystemWin32DX::InitHooks(IDXGIOutput* pOutput)\n{\n',
     '    FreeLibrary(m_hDriverModule);\n    m_hDriverModule = nullptr;\n  }\n#endif\n}\n\n'
     'void CWinSystemWin32DX::InitHooks(IDXGIOutput* pOutput)\n{\n#if defined(_M_ARM)\n'
     '  // kodi-rt: the refresh-rate hook into the D3D user-mode driver (Detours + WDK) is not built for ARM32\n'
     '  (void)pOutput;\n#else\n')

# close InitHooks' #else and guard the hook functions: find the end of InitHooks = the line before the first Hook definition
p = os.path.join(root, W)
s = open(p, encoding='utf-8', newline='').read()
marker = 'void APIENTRY HookCreateResource(D3D10DDI_HDEVICE hDevice, const D3D10DDIARG_CREATERESOURCE* pResource, D3D10DDI_HRESOURCE hResource, D3D10DDI_HRTRESOURCE hRtResource)\n{'
i = s.find(marker)
assert i > 0 and s.count(marker) == 1, 'hook definition not found exactly once'
head, tail = s[:i], s[i:]
j = head.rstrip().rfind('\n}')               # the closing brace of InitHooks
assert j > 0
head = head[:j] + '\n#endif\n}' + head[j + 2:]
# the three hook functions end right before CWinSystemWin32DX::IsHDRDisplay(); later member functions stay built
end_marker = '\nbool CWinSystemWin32DX::IsHDRDisplay()'
assert tail.count(end_marker) == 1, 'IsHDRDisplay not found exactly once after the hooks'
k = tail.find(end_marker)
tail = '#if !defined(_M_ARM)\n' + tail[:k] + '#endif // !_M_ARM\n' + tail[k:]
open(p, 'w', encoding='utf-8', newline='').write(head + tail)
print(f'edited {W} (InitHooks #endif, the three hook functions guarded)')

# 0003 additions for the x64/x86 builds (the original session's, 2026-11-13: reports/proposed-edits/detours-optional.py;
# verified there in build/s9/kodi): the guards key on the headers instead of the architecture. The hook is built when
# detours.h and the WDK's d3d10umddi.h are both found (any architecture) and compiled out otherwise; ARM32 has neither,
# so it compiles to the same code as before.
edit(W, '#if !defined(_M_ARM) // kodi-rt: no Detours/WDK headers for ARM32; the driver hook is compiled out\n'
        '#pragma warning(disable: 4091)\n',
        '// kodi-rt: the driver hook needs Detours and the WDK\'s d3d10umddi.h; without them it is compiled out\n'
        '#if __has_include(<detours.h>) && __has_include(<d3d10umddi.h>)\n'
        '#define KODI_RT_DRIVER_HOOK\n'
        '#pragma warning(disable: 4091)\n')
edit(W, '// User Mode Driver hooks definitions\n'
        '#if !defined(_M_ARM)\n',
        '// User Mode Driver hooks definitions\n'
        '#if defined(KODI_RT_DRIVER_HOOK)\n')
edit(W, 'void CWinSystemWin32DX::UninitHooks()\n'
        '{\n'
        '#if !defined(_M_ARM)\n',
        'void CWinSystemWin32DX::UninitHooks()\n'
        '{\n'
        '#if defined(KODI_RT_DRIVER_HOOK)\n')
edit(W, '#if defined(_M_ARM)\n'
        '  // kodi-rt: the refresh-rate hook into the D3D user-mode driver (Detours + WDK) is not built for ARM32\n',
        '#if !defined(KODI_RT_DRIVER_HOOK)\n'
        '  // kodi-rt: the refresh-rate hook into the D3D user-mode driver (Detours + WDK) is not built\n')
edit(W, '#if !defined(_M_ARM)\n'
        'void APIENTRY HookCreateResource(',
        '#if defined(KODI_RT_DRIVER_HOOK)\n'
        'void APIENTRY HookCreateResource(')
edit(W, '#endif // !_M_ARM\n',
        '#endif // KODI_RT_DRIVER_HOOK\n')

# ---------------------------------------------------------------- 0004: an external FFmpeg on Windows
# FindFFMPEG adds its MSYS2 build job (make-mingwlibs.sh: downloads FFmpeg, builds it into MINGW_LIBS_DIR) on every
# Windows configure, even when the libraries were found. With -DWITH_FFMPEG=<prefix> the found ones must be used.
edit('cmake/modules/FindFFMPEG.cmake',
     '  # Always enable build job for windows. Msys scripts handle rebuild requirements\n'
     '  if((WIN32 OR WINDOWS_STORE) AND NOT TARGET ${${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_BUILD_NAME})\n',
     '  # Always enable build job for windows. Msys scripts handle rebuild requirements\n'
     '  # kodi-rt: except for an external FFmpeg (-DWITH_FFMPEG/-DFFMPEG_PATH), which that job would replace\n'
     '  if((WIN32 OR WINDOWS_STORE) AND NOT FFMPEG_PATH AND NOT TARGET ${${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_BUILD_NAME})\n')

# ---------------------------------------------------------------- 0005: FriBidi::FriBidi for the Windows libass config
# Kodi's tools/depends/target/libass/01-win-CMakeLists.patch exports libass::libass with a link interface of
# Freetype::Freetype, FriBidi::FriBidi, Iconv::Iconv and harfbuzz::harfbuzz. FindASS uses that config ("Kodi custom
# libass target used for windows platforms"); FindFreeType, FindIconv and the harfbuzz config define the other three,
# but nothing defines FriBidi::FriBidi, so generation fails once libass comes from a prefix.
edit('cmake/modules/FindFriBidi.cmake',
     '      set_target_properties(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} PROPERTIES LIB_BUILD ON)\n    endif()\n\n',
     '      set_target_properties(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} PROPERTIES LIB_BUILD ON)\n    endif()\n\n'
     '    # kodi-rt: the Windows libass config (tools/depends/target/libass/01-win-CMakeLists.patch) links\n'
     '    # FriBidi::FriBidi; provide it, as FindFreeType provides Freetype::Freetype\n'
     '    if(NOT TARGET FriBidi::FriBidi)\n'
     '      get_target_property(_fribidi_target ${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} ALIASED_TARGET)\n'
     '      if(NOT _fribidi_target)\n'
     '        set(_fribidi_target ${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME})\n'
     '      endif()\n'
     '      add_library(FriBidi::FriBidi ALIAS ${_fribidi_target})\n'
     '    endif()\n\n')

# ---------------------------------------------------------------- 0006: whole archives with clang-cl
# Under Ninja, Kodi links its per-directory static libraries (ENABLE_STATIC_LIBS) as whole archives. whole_archive()
# gives every compiler whose ID is Clang the GNU flags -Wl,--whole-archive, but clang-cl (ID Clang, MSVC frontend)
# links with lld-link, which ignores them, so objects nothing references (self-registration) could be dropped.
# The VS generator build links every object (object libraries), so use /WHOLEARCHIVE for each library.
edit('cmake/scripts/common/ProjectMacros.cmake',
     'function(whole_archive output)\n'
     '  if(CMAKE_CXX_COMPILER_ID STREQUAL GNU OR CMAKE_CXX_COMPILER_ID STREQUAL Clang)\n',
     'function(whole_archive output)\n'
     '  # "MSVC" quoted: unquoted it is the variable MSVC (1 for clang-cl and cl)\n'
     '  if(CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")\n'
     '    # kodi-rt: clang-cl links with lld-link/link.exe, which take /WHOLEARCHIVE, not -Wl,--whole-archive\n'
     '    foreach(library ${ARGN})\n'
     '      list(APPEND ${output} ${library} "-WHOLEARCHIVE:$<TARGET_FILE:${library}>")\n'
     '    endforeach()\n'
     '    set(${output} ${${output}} PARENT_SCOPE)\n'
     '  elseif(CMAKE_CXX_COMPILER_ID STREQUAL GNU OR CMAKE_CXX_COMPILER_ID STREQUAL Clang)\n')

# ---------------------------------------------------------------- 0007: Log(LOGDEBUG, <component>, ...) with clang-cl
# clang-cl compiles with -fms-compatibility, which keeps MSVC's C++98 rule that any integral constant expression
# equal to 0 is a null pointer constant. LOGDEBUG is `constexpr int LOGDEBUG = 0`, so for
# Log(LOGDEBUG, LOGCURL, "...", ...) the overload Log(const std::string& loggerName, int level, ...) is viable too
# (0 -> const char* -> std::string), and it ties with Log(int level, uint32_t component, ...): "call to 'Log' is
# ambiguous" at about 350 call sites. MSVC itself is spared by /permissive-, which only the VS generator build adds.
# An exact overload for int components wins over both and forwards to the uint32_t one: no behavior change.
edit('xbmc/utils/log.h',
     '    Log(MapLogLevel(level), component, format, std::forward<Args>(args)...);\n  }\n\n',
     '    Log(MapLogLevel(level), component, format, std::forward<Args>(args)...);\n  }\n\n'
     '  // kodi-rt: clang-cl (-fms-compatibility) takes any integral constant 0, such as LOGDEBUG, as a null\n'
     '  // pointer constant, so Log(LOGDEBUG, <int component>, ...) would also match the loggerName overload\n'
     '  // below and be ambiguous. An exact match for int components resolves it.\n'
     '  template<typename... Args>\n'
     '  static void Log(int level, int component, fmt::format_string<Args...> format, Args&&... args)\n'
     '  {\n'
     '    Log(level, static_cast<uint32_t>(component), format, std::forward<Args>(args)...);\n'
     '  }\n\n')

# ---------------------------------------------------------------- 0008: Windows-only code that clang rejects
# Kodi's Windows sources are only ever compiled by MSVC, which accepts these three; clang (any target) does not.
# 1. DeviceResources.cpp RETURN_ERR: "return (##ret)" pastes "(" and the argument, an invalid token
#    (-Winvalid-token-paste, an error by default; MSVC ignores the paste). The "##" has no purpose there.
edit('xbmc/rendering/dx/DeviceResources.cpp',
     '#define RETURN_ERR(ret) if (FAILED(hr)) { LOG_HR(hr); breakOnDebug; return (##ret); }\n',
     '#define RETURN_ERR(ret) if (FAILED(hr)) { LOG_HR(hr); breakOnDebug; return (ret); }\n')
# 2. WinRenderer.cpp: a constexpr function whose return type holds std::function and std::string members is not a
#    literal type, an error before C++23 in clang. get() only fills a static vector at startup.
edit('xbmc/cores/VideoPlayer/VideoRenderers/WinRenderer.cpp',
     '  constexpr static render_details get(RenderMethod method, const std::string& name)\n',
     '  static render_details get(RenderMethod method, const std::string& name)\n')
# 3. ExternalPlayer.cpp: WaitForSingleObject returns a DWORD, but it is stored in an int and switched on, so
#    "case WAIT_FAILED:" (0xFFFFFFFF) narrows (-Wc++11-narrowing, an error in clang).
edit('xbmc/cores/ExternalPlayer/ExternalPlayer.cpp',
     '    int res = WaitForSingleObject(m_processInfo.hProcess, INFINITE);\n',
     '    DWORD res = WaitForSingleObject(m_processInfo.hProcess, INFINITE);\n')

# ---------------------------------------------------------------- 0009: an explicit template instantiation
# CMatrix<Order>'s converting constructor CMatrix(const CMatrix<Order - 1>&) is defined only in ConversionMatrix.cpp.
# WinVideoFilter.cpp (Windows only) calls CMatrix<4>(const CMatrix<3>&) with just the declaration in view, relying on
# ConversionMatrix.cpp's implicit instantiation (from CGlMatrix's constructor). MSVC emits that as a COMDAT; clang
# emits implicit instantiations as discardable linkonce_odr and drops this one after inlining it, so kodi.exe has an
# undefined symbol. An explicit instantiation keeps it.
edit('xbmc/cores/VideoPlayer/VideoRenderers/VideoShaders/ConversionMatrix.cpp',
     'template<uint8_t Order>\nCMatrix<Order>::CMatrix(const CMatrix<Order - 1>& other)\n{\n  *this = other.Get();\n}\n',
     'template<uint8_t Order>\nCMatrix<Order>::CMatrix(const CMatrix<Order - 1>& other)\n{\n  *this = other.Get();\n}\n\n'
     '// kodi-rt: used by WinVideoFilter.cpp, which sees only the declaration. Implicit instantiations can be\n'
     '// discarded once inlined (clang does), so instantiate it explicitly.\n'
     'template CMatrix<4>::CMatrix(const CMatrix<3>& other);\n')

# ---------------------------------------------------------------- 0010: touch screens on Windows (Stage 5 run 1)
# Windows gives a desktop app touch TAPS as mouse messages (only pans, two-finger taps etc. come as WM_GESTURE), so
# Kodi took the Surface's touch screen for a mouse: a pointer appeared, touch keymaps never applied to a tap, and a tap
# in fullscreen video opened the 3-second OSD. Windows marks these messages (MI_WP_SIGNATURE 0xFF515700 in
# GetMessageExtraInfo(), bit 0x80 for touch rather than pen). A touch that doesn't move now reaches Kodi as a touch tap,
# and a press-and-hold (which Windows turns into a right click) as a long press, as on Android. A touch that moves
# stays the mouse drag it was (sliders, scroll bars). Also, OnGestureNotify asked for the two-finger tap and
# press-and-tap gestures but set the same bits in dwBlock: now they are only wanted.
W = 'xbmc/windowing/windows/WinEventsWin32.cpp'
edit(W, 'CGenericTouchSwipeDetector* CWinEventsWin32::m_touchSwipeDetector = nullptr;\n',
     'CGenericTouchSwipeDetector* CWinEventsWin32::m_touchSwipeDetector = nullptr;\n'
     '\n'
     '// kodi-rt: Windows gives touch taps to a desktop app as mouse messages, marked with MI_WP_SIGNATURE\n'
     '// (0xFF515700) in GetMessageExtraInfo() and bit 0x80 for touch (not pen). A touch that does not move is\n'
     '// passed on as a touch tap or long press, as on Android; one that moves stays a mouse drag.\n'
     'namespace\n'
     '{\n'
     'bool IsTouchMouseMessage()\n'
     '{\n'
     '  return (static_cast<DWORD>(GetMessageExtraInfo()) & 0xFFFFFF80) == 0xFF515780;\n'
     '}\n'
     'bool g_touchDown = false;\n'
     'bool g_touchDragging = false;\n'
     'POINT g_touchDownPos = {};\n'
     'constexpr int TOUCH_DRAG_THRESHOLD = 10; // pixels\n'
     '} // unnamed namespace\n')
edit(W, '    case WM_MOUSEMOVE:\n'
        '      newEvent.type = XBMC_MOUSEMOTION;\n',
        '    case WM_MOUSEMOVE:\n'
        '      if (IsTouchMouseMessage())\n'
        '      {\n'
        '        // a touch has no hover (Windows moves the pointer to a tap first)\n'
        '        if (!g_touchDown)\n'
        '          return(0);\n'
        '        if (!g_touchDragging)\n'
        '        {\n'
        '          if (abs(GET_X_LPARAM(lParam) - g_touchDownPos.x) < TOUCH_DRAG_THRESHOLD &&\n'
        '              abs(GET_Y_LPARAM(lParam) - g_touchDownPos.y) < TOUCH_DRAG_THRESHOLD)\n'
        '            return(0);\n'
        '          // it moves: a drag after all, so deliver the press that was held back\n'
        '          g_touchDragging = true;\n'
        '          newEvent.type = XBMC_MOUSEBUTTONDOWN;\n'
        '          newEvent.button.x = static_cast<uint16_t>(g_touchDownPos.x);\n'
        '          newEvent.button.y = static_cast<uint16_t>(g_touchDownPos.y);\n'
        '          newEvent.button.button = XBMC_BUTTON_LEFT;\n'
        '          if (appPort)\n'
        '            appPort->OnEvent(newEvent);\n'
        '          newEvent = {};\n'
        '        }\n'
        '      }\n'
        '      newEvent.type = XBMC_MOUSEMOTION;\n')
edit(W, '    case WM_LBUTTONDOWN:\n'
        '    case WM_MBUTTONDOWN:\n'
        '    case WM_RBUTTONDOWN:\n'
        '      newEvent.type = XBMC_MOUSEBUTTONDOWN;\n',
        '    case WM_LBUTTONDOWN:\n'
        '    case WM_MBUTTONDOWN:\n'
        '    case WM_RBUTTONDOWN:\n'
        '      if (IsTouchMouseMessage())\n'
        '      {\n'
        '        // a touch press waits for its release (a tap) or a move (a drag)\n'
        '        if (uMsg == WM_LBUTTONDOWN)\n'
        '        {\n'
        '          g_touchDown = true;\n'
        '          g_touchDragging = false;\n'
        '          g_touchDownPos = {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};\n'
        '        }\n'
        '        return(0);\n'
        '      }\n'
        '      newEvent.type = XBMC_MOUSEBUTTONDOWN;\n')
edit(W, '    case WM_LBUTTONUP:\n'
        '    case WM_MBUTTONUP:\n'
        '    case WM_RBUTTONUP:\n'
        '      newEvent.type = XBMC_MOUSEBUTTONUP;\n',
        '    case WM_LBUTTONUP:\n'
        '    case WM_MBUTTONUP:\n'
        '    case WM_RBUTTONUP:\n'
        '      if (IsTouchMouseMessage() && !(uMsg == WM_LBUTTONUP && g_touchDragging))\n'
        '      {\n'
        '        const float x = static_cast<float>(GET_X_LPARAM(lParam));\n'
        '        const float y = static_cast<float>(GET_Y_LPARAM(lParam));\n'
        '        // kodi-rt diagnostic for Stage 5, to remove once done: where a touch lands, with the window\n'
        '        // and render sizes (taps in a window seemed to hit a neighbouring list item)\n'
        '        RECT client{};\n'
        '        GetClientRect(hWnd, &client);\n'
        '        auto& gfx = DX::Windowing()->GetGfxContext();\n'
        '        CLog::Log(LOGINFO, "kodi-rt touch: {} at {:.0f},{:.0f}, client {}x{}, render {}x{}",\n'
        '                  uMsg == WM_RBUTTONUP ? "long press" : "tap", x, y, client.right, client.bottom,\n'
        '                  gfx.GetWidth(), gfx.GetHeight());\n'
        '        if (uMsg == WM_LBUTTONUP)\n'
        '          CGenericTouchActionHandler::GetInstance().OnTap(x, y, 1);\n'
        '        else if (uMsg == WM_RBUTTONUP) // press-and-hold\n'
        '          CGenericTouchActionHandler::GetInstance().OnLongPress(x, y, 1);\n'
        '        g_touchDown = false;\n'
        '        return(0);\n'
        '      }\n'
        '      if (uMsg == WM_LBUTTONUP)\n'
        '        g_touchDown = g_touchDragging = false;\n'
        '      newEvent.type = XBMC_MOUSEBUTTONUP;\n')
edit(W, '                        { GID_TWOFINGERTAP, GC_TWOFINGERTAP, GC_TWOFINGERTAP },\n'
        '                        { GID_PRESSANDTAP, GC_PRESSANDTAP, GC_PRESSANDTAP }};\n',
        '                        { GID_TWOFINGERTAP, GC_TWOFINGERTAP, 0 }, // kodi-rt: wanted, so not also blocked\n'
        '                        { GID_PRESSANDTAP, GC_PRESSANDTAP, 0 }};\n')

# ---------------------------------------------------------------- 0011: Estuary: fullscreen button in the video OSD
# Hamed (Stage 5 run 2): "we need a button in ui to fullscreen while a movie plays and app is windowed". With touch
# only there is no "\" key. The OSD's right-hand button row gets Action(ToggleFullScreen) with Estuary's own fullscreen
# icon. Run 3: "that button also should make the fullscreen to windowed and viceversa", so it is always shown and
# toggles both ways (it was shown only in a window at first).
edit('addons/skin.estuary/xml/VideoOSD.xml',
     '\t\t\t\t\t\t<onclick>SetProperty(settingsdialog_header,$LOCALIZE[5],home)</onclick>\n'
     '\t\t\t\t\t\t<onclick>ActivateWindow(1101)</onclick>\n'
     '\t\t\t\t\t</control>\n',
     '\t\t\t\t\t\t<onclick>SetProperty(settingsdialog_header,$LOCALIZE[5],home)</onclick>\n'
     '\t\t\t\t\t\t<onclick>ActivateWindow(1101)</onclick>\n'
     '\t\t\t\t\t</control>\n'
     '\t\t\t\t\t<control type="radiobutton" id="70049">\n'
     '\t\t\t\t\t\t<description>kodi-rt: switch between fullscreen and a window</description>\n'
     '\t\t\t\t\t\t<include content="OSDButton">\n'
     '\t\t\t\t\t\t\t<param name="texture" value="icons/now-playing/fullscreen.png"/>\n'
     '\t\t\t\t\t\t</include>\n'
     '\t\t\t\t\t\t<onclick>Action(ToggleFullScreen)</onclick>\n'
     '\t\t\t\t\t</control>\n')

# ---------------------------------------------------------------- 0012: CFileStreamBuffer: seek check without wrap
# Stage 5 run 3: Kodi crashed when it opened a 1080p MKV, both in playback and in the file list (stream details), in
# memcpy from CFile::Read's stream buffer, reading at 0xDCBB5BB8. seekoff() tested "gptr()+offset2 >= eback() &&
# gptr()+offset2 < egptr()". A pointer outside the buffer is undefined behaviour; with MSVC's STL, egptr() is
# gptr() + count, so clang folds the second test into "(int)offset2 < count" (signed), and on a 32-bit target a backward
# seek longer than the buffer's address wraps the first one past eback(). Both pass, gbump() moves gptr() out of the
# address space, and the next read faults. Matroska's demuxer seeks back from the Cues at the end of the file, so any
# MKV larger than a few hundred MB hits it; the small MP4 trailer never did. Compare offsets instead.
edit('xbmc/filesystem/File.cpp',
     '  // try to seek within buffer\n'
     '  if(gptr()+offset2 >= eback() && gptr()+offset2 < egptr())\n'
     '  {\n'
     '    gbump(offset2);\n',
     '  // try to seek within buffer\n'
     '  // compare offsets: gptr()+offset2 outside the buffer is undefined and can wrap on 32-bit targets\n'
     '  if (offset2 >= eback() - gptr() && offset2 < egptr() - gptr())\n'
     '  {\n'
     '    gbump(static_cast<int>(offset2));\n')

# ---------------------------------------------------------------- 0013: the skiploopfilter advanced setting works again
# Hamed (Stage 5 run 4): x265 stutters; "how can i enable skip loop filter myself". advancedsettings.xml's
# <skiploopfilter> is applied in CDVDVideoCodecFFmpeg::Open(), but VideoPlayer calls SetCodecControl() before every
# packet, and that resets skip_loop_filter to AVDISCARD_DEFAULT (or NONREF while dropping), so the setting never lasted
# past the first packet. Keep it, and apply it to software decoding only: with DXVA, FFmpeg passes the skip on as
# "deblocking off" in the H.264 slice parameters, which costs quality and gains nothing. FFmpeg's HEVC decoder skips
# both deblocking and SAO for the frames the setting selects (hevc/filter.c).
V = 'xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecFFmpeg'
edit(V + '.h',
     '  int m_codecControlFlags = 0;\n',
     '  int m_codecControlFlags = 0;\n'
     '  AVDiscard m_skipLoopFilter = AVDISCARD_DEFAULT;\n')
edit(V + '.cpp',
     '#include <iterator>\n#include <memory>\n',
     '#include <algorithm>\n#include <iterator>\n#include <memory>\n')
edit(V + '.cpp',
     '  int iSkipLoopFilter = CServiceBroker::GetSettingsComponent()->GetAdvancedSettings()->m_iSkipLoopFilter;\n'
     '  if (iSkipLoopFilter != 0)\n',
     '  int iSkipLoopFilter = CServiceBroker::GetSettingsComponent()->GetAdvancedSettings()->m_iSkipLoopFilter;\n'
     '  m_skipLoopFilter = static_cast<AVDiscard>(iSkipLoopFilter);\n'
     '  if (iSkipLoopFilter != 0)\n')
edit(V + '.cpp',
     '    if (bDrop)\n'
     '    {\n'
     '      m_pCodecContext->skip_frame = AVDISCARD_NONREF;\n'
     '      m_pCodecContext->skip_idct = AVDISCARD_NONREF;\n'
     '      m_pCodecContext->skip_loop_filter = AVDISCARD_NONREF;\n'
     '    }\n'
     '    else\n'
     '    {\n'
     '      m_pCodecContext->skip_frame = AVDISCARD_DEFAULT;\n'
     '      m_pCodecContext->skip_idct = AVDISCARD_DEFAULT;\n'
     '      m_pCodecContext->skip_loop_filter = AVDISCARD_DEFAULT;\n'
     '    }\n',
     '    // the skiploopfilter setting only speeds up software decoding; with DXVA it would just lower quality\n'
     '    const AVDiscard skipLoopFilter = m_pHardware ? AVDISCARD_DEFAULT : m_skipLoopFilter;\n'
     '    if (bDrop)\n'
     '    {\n'
     '      m_pCodecContext->skip_frame = AVDISCARD_NONREF;\n'
     '      m_pCodecContext->skip_idct = AVDISCARD_NONREF;\n'
     '      m_pCodecContext->skip_loop_filter = std::max(AVDISCARD_NONREF, skipLoopFilter);\n'
     '    }\n'
     '    else\n'
     '    {\n'
     '      m_pCodecContext->skip_frame = AVDISCARD_DEFAULT;\n'
     '      m_pCodecContext->skip_idct = AVDISCARD_DEFAULT;\n'
     '      m_pCodecContext->skip_loop_filter = skipLoopFilter;\n'
     '    }\n')
# Addition to 0013 (from the original kodi-rt session, 2026-11-13; same file, so 0013's patch bytes change).
# Stage 6 update 3 (results/stage6-run13, debug logging off): the render loop keeps up (19-50 passes/s) but the video
# thread gets only ~9 pictures/s through the decoder, with late skips every few seconds ("slow motion with skips").
# Kodi opens software decoders with cores * 3 / 2 frame threads (6 here) next to the main, video, audio and
# renderer threads on 4 cores; on ARM32 Windows it now uses one frame thread per core.
edit('xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecFFmpeg.cpp',
     '      int num_threads = CServiceBroker::GetCPUInfo()->GetCPUCount() * 3 / 2;\n'
     '      num_threads = std::max(1, std::min(num_threads, 16));\n',
     '      int num_threads = CServiceBroker::GetCPUInfo()->GetCPUCount() * 3 / 2;\n'
     '#if defined(TARGET_WINDOWS) && defined(_M_ARM)\n'
     '      // one frame thread per core: more starve the rest of playback on quad-core ARM32 tablets\n'
     '      num_threads = CServiceBroker::GetCPUInfo()->GetCPUCount();\n'
     '#endif\n'
     '      num_threads = std::max(1, std::min(num_threads, 16));\n')
# Addition to 0013 (the original kodi-rt session's, 2026-11-13; same file): the video filter graph's buffer source
# carries the frames' colorspace and range.
# Found by the PGO profile (results/s7-pgo-run1): the hottest code in Kodi during x265 playback was swscale's
# hScale16To15_c, yuv2bgr24_X_c and ff_rgb24toyv12_c. Kodi's buffer source declares no colorspace, so FFmpeg 7.1+
# negotiates "unspecified" for the scaler's output; the frames say BT.709; swscale takes unspecified as BT.601 and,
# since the YUV matrices differ, converts every frame YUV 10-bit -> BGR24 (scaled path, 4-tap filter) -> YUV 8-bit
# ("YUV color matrix differs for YUV->YUV, using intermediate RGB to convert"), and the picture is then drawn as BT.709.
# Measured with Kodi's exact graph on FFmpeg 9.0.2 (tests/s7/fgcs.c, x64): 1.50 -> 0.18 ms per 1280x544 frame, and
# the output samples become exact (Y 91, U/V 140 for 10-bit 364/562; before: Y 92, U 138, V 139).
# Only for libavfilter >= 10.6.100 (FFmpeg 7.1+), which has these buffer source options, the same guard as the
# pixel_formats array.
edit('xbmc/cores/VideoPlayer/DVDCodecs/Video/DVDVideoCodecFFmpeg.cpp',
     '      m_pCodecContext->sample_aspect_ratio.num != 0 ? m_pCodecContext->sample_aspect_ratio.num : 1,\n'
     '      m_pCodecContext->sample_aspect_ratio.num != 0 ? m_pCodecContext->sample_aspect_ratio.den : 1);\n',
     '      m_pCodecContext->sample_aspect_ratio.num != 0 ? m_pCodecContext->sample_aspect_ratio.num : 1,\n'
     '      m_pCodecContext->sample_aspect_ratio.num != 0 ? m_pCodecContext->sample_aspect_ratio.den : 1);\n'
     '#if LIBAVFILTER_BUILD >= AV_VERSION_INT(10, 6, 100)\n'
     '  // The buffer source declares the colorspace and range of the frames it gets (the frame about to be filtered).\n'
     '  // Without them the scaler\'s output is negotiated as "unspecified", swscale takes that as BT.601, and a BT.709\n'
     '  // frame is converted YUV -> RGB -> YUV through an intermediate on every frame (instead of a plain bit-depth\n'
     '  // conversion), with shifted colours. Seen with 10-bit video and 8-bit-only renderers.\n'
     '  args += StringUtils::Format(\n'
     '      ":colorspace={}:range={}",\n'
     '      static_cast<int>(m_pDecodedFrame ? m_pDecodedFrame->colorspace : m_pCodecContext->colorspace),\n'
     '      static_cast<int>(m_pDecodedFrame ? m_pDecodedFrame->color_range : m_pCodecContext->color_range));\n'
     '#endif\n')

# ---------------------------------------------------------------- 0014: 10-bit video on GPUs without 16-bit textures
# Stage 5 run 4: a 720p 10-bit x265 file stuttered. Its frames (yuv420p10) can be drawn by the shader renderer
# (R16_UNORM textures) or the DXVA renderer (P010); the Tegra 3 at feature level 9_1 has neither ("Texture format ...
# is not supported" in the log), so the software renderer drew them: swscale to BGRA, full chroma interpolation, every
# frame on the CPU, on top of the CPU decoding. CProcessInfoWin::GetRenderFormats() offered the 10/16-bit formats
# regardless. Without either texture format it now offers 8-bit formats only, so the codec's own filter graph converts
# 10 to 8 bits (a same-size swscale pass, YUV420P listed before NV12 so that the cheap planar copy is chosen) and the
# GPU does the colour conversion and scaling.
edit('xbmc/cores/VideoPlayer/Process/windows/ProcessInfoWin.cpp',
     '#include "cores/VideoPlayer/Process/ProcessInfo.h"\n',
     '#include "cores/VideoPlayer/Process/ProcessInfo.h"\n'
     '#include "rendering/dx/RenderContext.h"\n')
edit('xbmc/cores/VideoPlayer/Process/windows/ProcessInfoWin.cpp',
     'std::vector<AVPixelFormat> CProcessInfoWin::GetRenderFormats()\n'
     '{\n'
     '  return {\n',
     'std::vector<AVPixelFormat> CProcessInfoWin::GetRenderFormats()\n'
     '{\n'
     '  // 10/16-bit frames need R16_UNORM (shader renderer) or P010 (DXVA renderer) textures. Without them\n'
     '  // (feature level 9_x GPUs), let the codec convert to 8 bits rather than the software renderer to RGB.\n'
     '  if (!DX::Windowing()->IsFormatSupport(DXGI_FORMAT_R16_UNORM, D3D11_FORMAT_SUPPORT_TEXTURE2D) &&\n'
     '      !DX::Windowing()->IsFormatSupport(DXGI_FORMAT_P010, D3D11_FORMAT_SUPPORT_TEXTURE2D))\n'
     '    return {AV_PIX_FMT_D3D11VA_VLD, AV_PIX_FMT_YUV420P, AV_PIX_FMT_NV12};\n'
     '\n'
     '  return {\n')
# IsFormatSupport() read the support bits even when CheckFormatSupport() failed (it does for formats the device
# lacks), i.e. an uninitialised variable: a failure now means "not supported".
edit('xbmc/rendering/dx/RenderSystemDX.cpp',
     '  UINT supported;\n'
     '  pD3DDev->CheckFormatSupport(format, &supported);\n'
     '  return (supported & usage) != 0;\n',
     '  UINT supported = 0;\n'
     '  if (FAILED(pD3DDev->CheckFormatSupport(format, &supported)))\n'
     '    return false;\n'
     '  return (supported & usage) != 0;\n')

# ---------------------------------------------------------------- 0015: Windows ARM32: playback CPU share (+ diagnostic)
# (from the original kodi-rt session, 2026-11-13)
# Stage 5 runs 6-7 (x265 720p 10-bit, debug + Video/Audio component logs): FFmpeg alone decodes the file at 1.57-2.58x
# real time on the tablet (hevcbench), yet in Kodi "video late by 500-590 ms, skipping to next keyframe" came every
# 2-5 s, and CRenderManager::PrepareNextRender ran about 9 times a second (50-180 ms apart). The main thread renders GUI
# and video and uploads each software frame to a GPU texture (CRendererBase::Render); it shared the four cores at normal
# priority with six FFmpeg frame threads, so the render loop starved and buffers were not freed ("timeout waiting for
# buffer"). The main thread now runs above normal priority on ARM32. A temporary log line (remove after Stage 5) gives,
# every 5 s, the number of video renders and their main-thread time, to show what is left if this is not enough.
# Stage 6 run 1 (update 2): the render loop reached 26-40 passes/s, but the late skips went on, and the decoder output
# about 15 frames/s in Kodi (with FFmpeg debug logging on, and hurry dropping non-reference frames, which both distort
# it). A second temporary line, from the video thread, every 5 s at info level (so it works without debug logging):
# pictures from the decoder, pictures shown, late skips and the packets they skipped.
edit('xbmc/platform/win32/WinMain.cpp',
     '    SetUnhandledExceptionFilter(CreateMiniDump);\n'
     '  }\n'
     '\n'
     '  int status{0};\n',
     '    SetUnhandledExceptionFilter(CreateMiniDump);\n'
     '  }\n'
     '\n'
     '#if defined(_M_ARM)\n'
     '  // the main thread renders GUI and video; software video decoding starves it on quad-core ARM32 otherwise\n'
     '  SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_ABOVE_NORMAL);\n'
     '#endif\n'
     '\n'
     '  int status{0};\n')
R = 'xbmc/cores/VideoPlayer/VideoRenderers/windows/RendererBase.cpp'
edit(R, '#include "utils/log.h"\n'
        '#include "windowing/GraphicContext.h"\n'
        '\n'
        'using namespace Microsoft::WRL;\n',
        '#include "utils/log.h"\n'
        '#include "windowing/GraphicContext.h"\n'
        '\n'
        '#include <algorithm>\n'
        '#include <chrono>\n'
        '\n'
        'using namespace Microsoft::WRL;\n')
edit(R, '{\n'
        '  m_iBufferIndex = index;\n'
        '  ManageTextures();\n'
        '  Render(target, sourceRect, destRect, viewRect, flags);\n'
        '}\n',
        '{\n'
        '  // kodi-rt diagnostic for Stage 5, to remove once done: video renders and their main-thread time per 5 s\n'
        '  static int s_calls = 0;\n'
        '  static int64_t s_totalUs = 0, s_maxUs = 0;\n'
        '  static auto s_since = std::chrono::steady_clock::now();\n'
        '  const auto t0 = std::chrono::steady_clock::now();\n'
        '\n'
        '  m_iBufferIndex = index;\n'
        '  ManageTextures();\n'
        '  Render(target, sourceRect, destRect, viewRect, flags);\n'
        '\n'
        '  const auto t1 = std::chrono::steady_clock::now();\n'
        '  const int64_t us = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count();\n'
        '  s_calls++;\n'
        '  s_totalUs += us;\n'
        '  s_maxUs = std::max(s_maxUs, us);\n'
        '  if (t1 - s_since >= std::chrono::seconds(5))\n'
        '  {\n'
        '    CLog::Log(LOGINFO, "kodi-rt render: {} video renders in {:.1f} s, {} us each on average, {} us at most",\n'
        '              s_calls, std::chrono::duration<double>(t1 - s_since).count(), s_totalUs / s_calls, s_maxUs);\n'
        '    s_calls = 0;\n'
        '    s_totalUs = s_maxUs = 0;\n'
        '    s_since = t1;\n'
        '  }\n'
        '}\n')
P = 'xbmc/cores/VideoPlayer/VideoPlayerVideo.cpp'
edit(P, '#include <algorithm>\n'
        '#include <iomanip>\n',
        '#include <algorithm>\n'
        '#include <chrono>\n'
        '#include <iomanip>\n')
edit(P, 'using namespace std::chrono_literals;\n'
        '\n'
        'class CDVDMsgVideoCodecChange : public CDVDMsg\n',
        'using namespace std::chrono_literals;\n'
        '\n'
        'namespace\n'
        '{\n'
        '// kodi-rt diagnostic for Stage 5, to remove once done: the video thread\'s work per 5 s, at info level\n'
        'enum class RtVideoEvent\n'
        '{\n'
        '  Picture,\n'
        '  Shown,\n'
        '  LateSkip,\n'
        '  SkippedPacket,\n'
        '  Count\n'
        '};\n'
        '\n'
        'void KodiRtVideoStat(RtVideoEvent ev)\n'
        '{\n'
        '  static int counts[static_cast<int>(RtVideoEvent::Count)] = {};\n'
        '  static auto since = std::chrono::steady_clock::now();\n'
        '  counts[static_cast<int>(ev)]++;\n'
        '  const auto now = std::chrono::steady_clock::now();\n'
        '  if (now - since >= 5s)\n'
        '  {\n'
        '    CLog::Log(LOGINFO,\n'
        '              "kodi-rt video: {} pictures from the decoder, {} shown, {} late skips ({} packets "\n'
        '              "skipped) in {:.1f} s",\n'
        '              counts[0], counts[1], counts[2], counts[3],\n'
        '              std::chrono::duration<double>(now - since).count());\n'
        '    std::fill(std::begin(counts), std::end(counts), 0);\n'
        '    since = now;\n'
        '  }\n'
        '}\n'
        '} // namespace\n'
        '\n'
        'class CDVDMsgVideoCodecChange : public CDVDMsg\n')
edit(P, '            m_skipToKeyFrame = true;\n'
        '          }\n'
        '        }\n'
        '      }\n'
        '      if (m_skipToKeyFrame)\n'
        '      {\n'
        '        m_iDroppedFrames++;\n'
        '        continue;\n'
        '      }\n',
        '            m_skipToKeyFrame = true;\n'
        '            KodiRtVideoStat(RtVideoEvent::LateSkip);\n'
        '          }\n'
        '        }\n'
        '      }\n'
        '      if (m_skipToKeyFrame)\n'
        '      {\n'
        '        m_iDroppedFrames++;\n'
        '        KodiRtVideoStat(RtVideoEvent::SkippedPacket);\n'
        '        continue;\n'
        '      }\n')
edit(P, '    m_outputSate = OutputPicture(&m_picture);\n'
        '\n'
        '    if (m_outputSate == OUTPUT_AGAIN)\n'
        '    {\n'
        '      return true;\n'
        '    }\n',
        '    m_outputSate = OutputPicture(&m_picture);\n'
        '    KodiRtVideoStat(RtVideoEvent::Picture);\n'
        '\n'
        '    if (m_outputSate == OUTPUT_AGAIN)\n'
        '    {\n'
        '      return true;\n'
        '    }\n')
edit(P, '  }\n'
        '\n'
        '  return OUTPUT_NORMAL;\n'
        '}\n',
        '  }\n'
        '\n'
        '  KodiRtVideoStat(RtVideoEvent::Shown);\n'
        '  return OUTPUT_NORMAL;\n'
        '}\n')

# ---------------------------------------------------------------- 0016: gpu_memcpy() gets the SSE4.1 target under clang
# The original session's, for the x64/x86 builds (2026-11-13, reports/proposed-edits/gpu-memcpy-sse41-target.py;
# verified there in build/s9/kodi). gpu_memcpy uses _mm_stream_load_si128 (MOVNTDQA, SSE4.1); MSVC allows any
# intrinsic anywhere, clang only inlines it into a function compiled for sse4.1. Its only caller (RendererShaders.cpp)
# uses it only when the CPU has SSE4 (CPU_FEATURE_SSE4), so the rest of Kodi stays at the SSE2 baseline. ARM32 never
# includes this header (0001 leaves the SSE headers out of the ARM32 build).
edit('xbmc/platform/win32/utils/gpu_memcpy_sse4.h',
     '//  optimally use a 2K offset between them.\n'
     'inline void* gpu_memcpy(void* d, const void* s, size_t size)\n',
     '//  optimally use a 2K offset between them.\n'
     '#if defined(__clang__)\n'
     '// kodi-rt: clang needs the SSE4.1 target for _mm_stream_load_si128; callers check CPU_FEATURE_SSE4 first\n'
     '__attribute__((target("sse4.1")))\n'
     '#endif\n'
     'inline void* gpu_memcpy(void* d, const void* s, size_t size)\n')
