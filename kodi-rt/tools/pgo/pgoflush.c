/* kodi-rt PGO phase 1 (instrumented builds only): write the profile counts once a minute.
 *
 * The profile runtime (clang_rt.profile-arm.lib) writes its counts once, at a normal exit (atexit). A crash, a hang
 * at exit or a killed process would lose a whole profiling session, so this thread also writes them every 60 s and
 * then sets the in-memory counters back to zero. That is only right when the runtime MERGES each write into the file,
 * i.e. when LLVM_PROFILE_FILE contains %m (or %<N>m): then the file always holds the total so far. Without %m the
 * thread does nothing and the runtime's single exit write stays as it is.
 *
 * At exit, a handler that this thread registers (60 s after start, long after the runtime registered its own exit
 * write; atexit handlers run in reverse order, so this one runs first) waits for a write in progress and stops the
 * thread. The runtime's exit write then adds the counts of the last minute.
 *
 * Linked into kodi.exe as an object by cross/kodi-rt-pgo-instr.cmake, so its initializer is kept; compiled without
 * instrumentation by scripts/s7-configure.sh. Phase 2 (-fprofile-use) does not have it.
 */
#define _CRT_SECURE_NO_WARNINGS /* getenv */
#include <windows.h>
#include <stdlib.h>

int __llvm_profile_write_file(void);
void __llvm_profile_reset_counters(void);

#ifndef KODIRT_PGO_FLUSH_MS
#define KODIRT_PGO_FLUSH_MS 60000 /* tests/pgo builds it with a shorter interval */
#endif

static CRITICAL_SECTION g_lock;
static volatile LONG g_stop;

/* LLVM_PROFILE_FILE names a merge pool: "%m" or "%<digits>m" */
static int merging(void)
{
  const char *p = getenv("LLVM_PROFILE_FILE");
  if (!p)
    return 0;
  for (; *p; p++)
  {
    if (*p != '%')
      continue;
    const char *q = p + 1;
    while (*q >= '0' && *q <= '9')
      q++;
    if (*q == 'm')
      return 1;
  }
  return 0;
}

static void __cdecl kodirt_pgo_stop(void)
{
  EnterCriticalSection(&g_lock); /* waits for a periodic write in progress */
  g_stop = 1;
  LeaveCriticalSection(&g_lock);
}

static DWORD WINAPI kodirt_pgo_flusher(LPVOID unused)
{
  (void)unused;
  Sleep(KODIRT_PGO_FLUSH_MS);
  if (!merging())
    return 0;
  atexit(kodirt_pgo_stop);
  for (;;)
  {
    EnterCriticalSection(&g_lock);
    if (g_stop)
    {
      LeaveCriticalSection(&g_lock);
      return 0;
    }
    /* 0 = written (merged into the file): start counting from zero; on failure keep the counts for the next try */
    if (__llvm_profile_write_file() == 0)
      __llvm_profile_reset_counters();
    LeaveCriticalSection(&g_lock);
    Sleep(KODIRT_PGO_FLUSH_MS);
  }
}

static int __cdecl kodirt_pgo_start(void)
{
  InitializeCriticalSection(&g_lock);
  HANDLE h = CreateThread(NULL, 0, kodirt_pgo_flusher, NULL, 0, NULL);
  if (h)
    CloseHandle(h);
  return 0; /* never fail the CRT start */
}

/* a C initializer of the static CRT (.CRT$XIU, after the CRT's own XIA* entries); external and "used" so neither
 * the compiler nor the linker drops it */
#pragma section(".CRT$XIU", long, read)
__declspec(allocate(".CRT$XIU")) __attribute__((used)) int(__cdecl *const kodirt_pgo_init)(void) = kodirt_pgo_start;
