/* kodi-rt: test for tools/pgo/pgoflush.c (built with KODIRT_PGO_FLUSH_MS=1000 by tests/pgo/run-flushtest.sh).
 * work() is called exactly <calls> times over about <seconds> s, while pgoflush writes and resets the counts every
 * second. Mode "exit": a normal exit, so the merged profile must count work() exactly <calls> times (no loss, no
 * double counting). Mode "kill": TerminateProcess at the end (no exit write), so the profile holds the counts up to
 * the last periodic write: fewer than <calls>, but more than zero. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile long sink;

__declspec(noinline) static void work(int i)
{
  sink += i & 7;
}

int main(int argc, char **argv)
{
  int calls = argc > 1 ? atoi(argv[1]) : 3500;
  int seconds = argc > 2 ? atoi(argv[2]) : 4;
  int kill = argc > 3 && !strcmp(argv[3], "kill");
  DWORD per_ms = (DWORD)(seconds * 1000) / (DWORD)calls;
  for (int i = 0; i < calls; i++)
  {
    work(i);
    if (per_ms)
      Sleep(per_ms);
    else if (i % 100 == 0)
      Sleep(1);
  }
  printf("flushtest: %d calls done (%s)\n", calls, kill ? "kill" : "exit");
  fflush(stdout);
  if (kill)
    TerminateProcess(GetCurrentProcess(), 3);
  return 0;
}
