# kodi-rt Stage 4: the source edits behind the LAYERED patches (0017 on), which may change files that an earlier patch
# already owns (every new patch goes here, shared files or not). scripts/s4-dev-edits.py makes 0001-0016 (each file
# in exactly one patch, diffed whole against the pinned commit). For a layered patch, scripts/s4-make-patches.sh first stages the tree the earlier patches made
# (git add of the patch's files), runs that patch's block from this script, and diffs the working tree against the
# index, so the patch holds only its own change and git apply takes the patches in number order.
# Usage: python -I scripts/s4-dev-edits-2.py <dev clone> <patch number>     (one block per run)
import sys, os

root, which = sys.argv[1], sys.argv[2]

def edit(rel, old, new):
    p = os.path.join(root, rel)
    s = open(p, encoding='utf-8', newline='').read()
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{rel}: expected 1 match, found {n}:\n{old}')
    open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
    print(f'edited {rel}')

# ---------------------------------------------------------------- 0017: "Open with" plays in the running Kodi
# (on top of 0010's WinEventsWin32.cpp and 0015's WinMain.cpp.) Written by the original kodi-rt session from
# reports/proposed-edits/openwith-running-instance.py (Hamed, 2026-11-14: "Open with" should play the file when Kodi is
# already running): a second kodi.exe hands the files of its command line to the running instance, which plays them.
#
# Why: Kodi runs once per data folder (WinMain.cpp's mutexes). A second start, e.g. from Explorer's "Open with" while
# Kodi is open, only brought the running window to the front and exited, so the file it was started with never
# played. Now it sends the file paths (made absolute, since the running Kodi has another current folder) with
# WM_COPYDATA; the running Kodi's window procedure posts them as TMSG_MEDIA_PLAY with a CFileItemList, the message
# JSON-RPC's Player.Open uses, which picks the video or music playlist and plays them.
def p0017():
    edit('xbmc/windowing/windows/WinEventsWin32.h',
         'public:\n'
         '  bool MessagePump() override;\n',
         'public:\n'
         '  // kodi-rt: WM_COPYDATA id for files a second kodi.exe hands to the running one (WinMain.cpp)\n'
         '  static constexpr ULONG_PTR COPYDATA_OPEN_FILES = 0x4B4F4446; // "KODF"\n'
         '\n'
         '  bool MessagePump() override;\n')
    edit('xbmc/platform/win32/WinMain.cpp',
         '#include "CompileInfo.h"\n'
         '#include "ServiceBroker.h"\n',
         '#include "CompileInfo.h"\n'
         '#include "FileItem.h"\n'
         '#include "FileItemList.h"\n'
         '#include "ServiceBroker.h"\n')
    edit('xbmc/platform/win32/WinMain.cpp',
         '#include "utils/Digest.h"\n',
         '#include "utils/Digest.h"\n'
         '#include "windowing/windows/WinEventsWin32.h"\n')
    edit('xbmc/platform/win32/WinMain.cpp',
         '  handle = CreateMutexW(nullptr, FALSE, mutexName.c_str());\n'
         '  if (handle != NULL && GetLastError() == ERROR_ALREADY_EXISTS)\n'
         '    return true;\n'
         '\n'
         '  return false;\n'
         '}\n'
         '} // namespace\n',
         '  handle = CreateMutexW(nullptr, FALSE, mutexName.c_str());\n'
         '  if (handle != NULL && GetLastError() == ERROR_ALREADY_EXISTS)\n'
         '    return true;\n'
         '\n'
         '  return false;\n'
         '}\n'
         '\n'
         '/*!\n'
         ' * \\brief kodi-rt: hand the files of this command line to the running instance, which plays them.\n'
         ' *\n'
         ' * \\param[in] hwnd the running instance\'s window\n'
         ' * \\param[in] files the files given on the command line\n'
         ' */\n'
         'void SendFilesToRunningInstance(HWND hwnd, const CFileItemList& files)\n'
         '{\n'
         '  std::wstring paths;\n'
         '  for (const auto& item : files)\n'
         '  {\n'
         '    std::wstring path = ToW(item->GetPath());\n'
         '    // a relative path is relative to this process\'s current folder, not the running Kodi\'s\n'
         '    if (path.find(L"://") == std::wstring::npos)\n'
         '    {\n'
         '      const DWORD size = GetFullPathNameW(path.c_str(), 0, nullptr, nullptr);\n'
         '      if (size > 0)\n'
         '      {\n'
         '        std::wstring full(size, L\'\\0\');\n'
         '        const DWORD len = GetFullPathNameW(path.c_str(), size, full.data(), nullptr);\n'
         '        if (len > 0 && len < size)\n'
         '          path = full.substr(0, len);\n'
         '      }\n'
         '    }\n'
         '    paths += path;\n'
         '    paths += L\'\\n\';\n'
         '  }\n'
         '  if (paths.empty())\n'
         '    return;\n'
         '\n'
         '  COPYDATASTRUCT data{CWinEventsWin32::COPYDATA_OPEN_FILES,\n'
         '                      static_cast<DWORD>(paths.size() * sizeof(wchar_t)), paths.data()};\n'
         '  DWORD_PTR result{0};\n'
         '  SendMessageTimeoutW(hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG,\n'
         '                      5000, &result);\n'
         '}\n'
         '} // namespace\n')
    edit('xbmc/platform/win32/WinMain.cpp',
         '      // switch to the running instance\n'
         '      ShowWindow(hwnd, SW_RESTORE);\n'
         '      SetForegroundWindow(hwnd);\n'
         '    }\n',
         '      // switch to the running instance\n'
         '      ShowWindow(hwnd, SW_RESTORE);\n'
         '      SetForegroundWindow(hwnd);\n'
         '      SendFilesToRunningInstance(hwnd, params->GetPlaylist());\n'
         '    }\n')
    edit('xbmc/windowing/windows/WinEventsWin32.cpp',
         '#include "ServiceBroker.h"\n'
         '#include "Util.h"\n',
         '#include "FileItem.h"\n'
         '#include "FileItemList.h"\n'
         '#include "ServiceBroker.h"\n'
         '#include "Util.h"\n')
    edit('xbmc/windowing/windows/WinEventsWin32.cpp',
         '    case WM_TIMER:\n'
         '    {\n'
         '      if (wParam == ID_TIMER_HDR)\n',
         '    case WM_COPYDATA:\n'
         '    {\n'
         '      // kodi-rt: files a second kodi.exe was started with (WinMain.cpp), played like files on the command line\n'
         '      const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lParam);\n'
         '      if (data == nullptr || data->dwData != COPYDATA_OPEN_FILES || data->lpData == nullptr)\n'
         '        break;\n'
         '      const std::wstring paths(static_cast<const wchar_t*>(data->lpData),\n'
         '                               data->cbData / sizeof(wchar_t));\n'
         '      auto* list = new CFileItemList; // deleted by the TMSG_MEDIA_PLAY handler\n'
         '      for (const auto& path : StringUtils::Split(FromW(paths), \'\\n\'))\n'
         '      {\n'
         '        if (!path.empty())\n'
         '          list->Add(std::make_shared<CFileItem>(path, false));\n'
         '      }\n'
         '      if (list->IsEmpty())\n'
         '      {\n'
         '        delete list;\n'
         '        break;\n'
         '      }\n'
         '      CLog::LogF(LOGINFO, "playing {} file(s) from another kodi.exe", list->Size());\n'
         '      CServiceBroker::GetAppMessenger()->PostMsg(TMSG_MEDIA_PLAY, -1, -1, static_cast<void*>(list));\n'
         '      return TRUE;\n'
         '    }\n'
         '    case WM_TIMER:\n'
         '    {\n'
         '      if (wParam == ID_TIMER_HDR)\n')

# ---------------------------------------------------------------- 0018: Estuary OSD fullscreen/window icons
# (on top of 0011's VideoOSD.xml.) Written by the original kodi-rt session from
# reports/proposed-edits/osd-fullscreen-icons.py (Hamed, 2026-11-14: the windowed-mode button looked bigger than the
# rest; expand/collapse icons). 0011's one button (icons/now-playing/fullscreen.png, drawn edge to edge) becomes two
# in the OSD's own icon style: 70049 "to a window" (osd/fullscreen/buttons/windowed.png) when System.IsFullscreen,
# 70050 "to fullscreen" (osd/fullscreen/buttons/fullscreen.png) otherwise; both Action(ToggleFullScreen).
# The two PNGs are binary and NOT in patches/ (like the branding): branding/osd/{fullscreen,windowed}.png ->
# addons/skin.estuary/media/osd/fullscreen/buttons/ (the fork carries them in a binary commit).
def p0018():
    edit('addons/skin.estuary/xml/VideoOSD.xml',
         '\t\t\t\t\t<control type="radiobutton" id="70049">\n'
         '\t\t\t\t\t\t<description>kodi-rt: switch between fullscreen and a window</description>\n'
         '\t\t\t\t\t\t<include content="OSDButton">\n'
         '\t\t\t\t\t\t\t<param name="texture" value="icons/now-playing/fullscreen.png"/>\n'
         '\t\t\t\t\t\t</include>\n'
         '\t\t\t\t\t\t<onclick>Action(ToggleFullScreen)</onclick>\n'
         '\t\t\t\t\t</control>\n',
         '\t\t\t\t\t<control type="radiobutton" id="70049">\n'
         '\t\t\t\t\t\t<description>kodi-rt: from fullscreen to a window</description>\n'
         '\t\t\t\t\t\t<include content="OSDButton">\n'
         '\t\t\t\t\t\t\t<param name="texture" value="osd/fullscreen/buttons/windowed.png"/>\n'
         '\t\t\t\t\t\t</include>\n'
         '\t\t\t\t\t\t<onclick>Action(ToggleFullScreen)</onclick>\n'
         '\t\t\t\t\t\t<visible>System.IsFullscreen</visible>\n'
         '\t\t\t\t\t</control>\n'
         '\t\t\t\t\t<control type="radiobutton" id="70050">\n'
         '\t\t\t\t\t\t<description>kodi-rt: from a window to fullscreen</description>\n'
         '\t\t\t\t\t\t<include content="OSDButton">\n'
         '\t\t\t\t\t\t\t<param name="texture" value="osd/fullscreen/buttons/fullscreen.png"/>\n'
         '\t\t\t\t\t\t</include>\n'
         '\t\t\t\t\t\t<onclick>Action(ToggleFullScreen)</onclick>\n'
         '\t\t\t\t\t\t<visible>!System.IsFullscreen</visible>\n'
         '\t\t\t\t\t</control>\n')

# ---------------------------------------------------------------- 0019: violet as the default colour theme
# (system/settings/settings.xml, not in an earlier patch.) Written by the original kodi-rt session from
# reports/proposed-edits/violet-default-theme.py (Hamed, 2026-11-14: "make the purple color default for the theme"):
# lookandfeel.skincolors defaults to Estuary's violet theme instead of SKINDEFAULT. CGUIColorManager loads the skin's
# colors/defaults.xml and then colors/violet.xml if the skin has one, so other skins keep their colours; settings
# still at their default follow it, a chosen theme stays. Its companion, the purple Kodi logo (branding/
# vendor_logo.png -> media/vendor_logo.png), is binary and NOT in patches/ (the fork has it in a binary commit).
def p0019():
    edit('system/settings/settings.xml',
         '        <setting id="lookandfeel.skincolors" type="string" parent="lookandfeel.skin" label="14078" help="36106">\n'
         '          <level>1</level>\n'
         '          <default>SKINDEFAULT</default>\n',
         '        <setting id="lookandfeel.skincolors" type="string" parent="lookandfeel.skin" label="14078" help="36106">\n'
         '          <level>1</level>\n'
         '          <default>violet</default> <!-- kodi-rt: Estuary\'s violet theme by default -->\n')

BLOCKS = {'0017': p0017, '0018': p0018, '0019': p0019}
if which not in BLOCKS:
    raise SystemExit(f'no layered patch {which} (have: {", ".join(BLOCKS)})')
BLOCKS[which]()
