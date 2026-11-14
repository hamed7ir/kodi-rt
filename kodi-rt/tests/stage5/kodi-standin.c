// kodi-rt Stage 5 dry-run stand-in for kodi.exe (x64, for the build server only, never shipped): behaves like Kodi in
// portable mode as far as the kit's scripts can tell. Built in four roles by scripts/s5-package-kit.sh --dryrun-x64:
//   (default)          writes kodi\portable_data\kodi.log and exits 0, like a normal session
//   -DSTANDIN_CRASH    also writes a fake kodi_crashlog-*.dmp and kodi_stacktrace-*.txt and exits 0xC0000005
//                      (ExitProcess, not a real fault: a real one could leave an error dialog open on the server)
//   -DSTANDIN_NOLOG    writes no log and exits 0xC0000005, like a crash before logging starts
//   -DSTANDIN_BREAK    writes the log, then __debugbreak(): under dbgrun this is a fatal exception (crash-1.txt/.dmp)
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static void write_file(const wchar_t* dir, const wchar_t* name, const char* text)
{
  wchar_t path[MAX_PATH];
  swprintf(path, MAX_PATH, L"%ls\\%ls", dir, name);
  FILE* f = _wfopen(path, L"wb");
  if (f)
  {
    fputs(text, f);
    fclose(f);
  }
}

int wmain(int argc, wchar_t** argv)
{
  int portable = 0;
  for (int i = 1; i < argc; ++i)
    if (wcscmp(argv[i], L"-p") == 0)
      portable = 1;
  if (!portable)
    return 3;
  wchar_t dir[MAX_PATH];
  GetModuleFileNameW(NULL, dir, MAX_PATH);
  *wcsrchr(dir, L'\\') = 0;
  wchar_t pd[MAX_PATH];
  swprintf(pd, MAX_PATH, L"%ls\\portable_data", dir);
  CreateDirectoryW(pd, NULL);
#ifndef STANDIN_NOLOG
  write_file(pd, L"kodi.log", "kodi-rt dry-run stand-in: info <general>: Starting Kodi (stand-in)\r\n");
#endif
#ifdef STANDIN_CRASH
  write_file(pd, L"kodi_crashlog-standin-20261112-000000.dmp", "MDMP stand-in\r\n");
  write_file(pd, L"kodi_stacktrace-standin-20261112-000000.txt", "stand-in stack trace\r\n");
  ExitProcess(0xC0000005u);
#endif
#ifdef STANDIN_NOLOG
  ExitProcess(0xC0000005u);
#endif
#ifdef STANDIN_BREAK
  __debugbreak();
#endif
  return 0;
}
