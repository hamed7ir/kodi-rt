/* kodi-rt: rtprof dry-run target. Three threads spin in two named functions for <seconds> (default 15). */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

static volatile LONG stop;
static volatile double sink;

__declspec(noinline) static double spin_a(void) { double x = 0; for (int i = 0; i < 1000000; i++) x += i * 0.5; return x; }
__declspec(noinline) static double spin_b(void) { double x = 1; for (int i = 0; i < 1000000; i++) x *= 1.0000001; return x; }

static DWORD WINAPI worker(LPVOID p)
{
    while (!stop)
        sink += ((INT_PTR)p & 1) ? spin_a() : spin_b();
    return 0;
}

int main(int argc, char **argv)
{
    int s = argc > 1 ? atoi(argv[1]) : 15;
    if (s <= 0)
        s = 15;   /* run as a stand-in for "kodi.exe -p" */
    HANDLE h[3];
    for (INT_PTR i = 0; i < 3; i++)
        h[i] = CreateThread(NULL, 0, worker, (LPVOID)i, 0, NULL);
    Sleep(s * 1000);
    stop = 1;
    WaitForMultipleObjects(3, h, TRUE, INFINITE);
    printf("burn done\n");
    return 0;
}
