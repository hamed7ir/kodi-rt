/*
 * kodi-rt rtprof: a small sampling profiler for another process on Windows RT (ARM32) or x64.
 *   rtprof <process name> <seconds> <output file>
 * Waits up to 5 minutes for the process, then for <seconds>:
 *   - once a second: each thread's CPU time (GetThreadTimes), the process total, and system busy (GetSystemTimes);
 *     a line per 5 s with the busiest threads;
 *   - while the process used more than 1.5 cores in the last second: every ~20 ms, each thread's program counter
 *     (SuspendThread, GetThreadContext, ResumeThread), counted per thread.
 * At the end: the module list (name, base, size) and, per thread, its CPU seconds, priority, start address and its
 * most frequent program counters, as module+offset, for symbolizing on the server. The last line is "RTPROF DONE".
 */
#define WIN32_LEAN_AND_MEAN
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <mmsystem.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define MAXT     256
#define HASHSZ   8192
#define MAXMOD   512

typedef LONG (WINAPI *NtQIT)(HANDLE, int, PVOID, ULONG, PULONG);

typedef struct { DWORD pc; DWORD n; } Slot;
typedef struct {
    DWORD tid;
    HANDLE h;
    int alive;
    int prio;
    DWORD start;
    ULONGLONG cpu_last, cpu_total, cpu_win;
    DWORD samples;
    Slot *hash;
} Thr;

static Thr thr[MAXT];
static int nthr;
static HMODULE mods[MAXMOD];
static MODULEINFO minfo[MAXMOD];
static wchar_t mname[MAXMOD][64];
static int nmod;
static FILE *out;
static NtQIT ntqit;

static ULONGLONG ft(FILETIME f) { return ((ULONGLONG)f.dwHighDateTime << 32) | f.dwLowDateTime; }

static Thr *find_thr(DWORD tid)
{
    for (int i = 0; i < nthr; i++)
        if (thr[i].tid == tid)
            return &thr[i];
    return NULL;
}

static void refresh_threads(DWORD pid)
{
    THREADENTRY32 te;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    for (int i = 0; i < nthr; i++)
        thr[i].alive = 0;
    if (snap == INVALID_HANDLE_VALUE)
        return;
    te.dwSize = sizeof(te);
    for (BOOL ok = Thread32First(snap, &te); ok; ok = Thread32Next(snap, &te)) {
        Thr *t;
        if (te.th32OwnerProcessID != pid)
            continue;
        t = find_thr(te.th32ThreadID);
        if (!t && nthr < MAXT) {
            HANDLE h = OpenThread(THREAD_QUERY_INFORMATION | THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT, FALSE,
                                  te.th32ThreadID);
            if (!h)
                continue;
            t = &thr[nthr++];
            memset(t, 0, sizeof(*t));
            t->tid = te.th32ThreadID;
            t->h = h;
            t->hash = calloc(HASHSZ, sizeof(Slot));
            if (ntqit) {
                PVOID sa = NULL;
                if (ntqit(h, 9 /* ThreadQuerySetWin32StartAddress */, &sa, sizeof(sa), NULL) == 0)
                    t->start = (DWORD)(ULONG_PTR)sa;
            }
            {
                FILETIME c, e, k, u;
                if (GetThreadTimes(h, &c, &e, &k, &u))
                    t->cpu_last = ft(k) + ft(u);
            }
        }
        if (t) {
            t->alive = 1;
            t->prio = GetThreadPriority(t->h);
        }
    }
    CloseHandle(snap);
}

static void count_pc(Thr *t, DWORD pc)
{
    DWORD i = (pc >> 1) * 2654435761u % HASHSZ;
    for (int k = 0; k < HASHSZ; k++, i = (i + 1) % HASHSZ) {
        if (t->hash[i].n == 0) { t->hash[i].pc = pc; t->hash[i].n = 1; return; }
        if (t->hash[i].pc == pc) { t->hash[i].n++; return; }
    }
}

static void sample_all(void)
{
    for (int i = 0; i < nthr; i++) {
        Thr *t = &thr[i];
        CONTEXT ctx;
        if (!t->alive || !t->hash)
            continue;
        if (SuspendThread(t->h) == (DWORD)-1)
            continue;
        memset(&ctx, 0, sizeof(ctx));
        ctx.ContextFlags = CONTEXT_CONTROL;
        if (GetThreadContext(t->h, &ctx)) {
#if defined(_M_ARM)
            count_pc(t, ctx.Pc);
#else
            count_pc(t, (DWORD)ctx.Rip);
#endif
            t->samples++;
        }
        ResumeThread(t->h);
    }
}

/* keeps the previous list when the process has exited (enumeration then fails) */
static void load_modules(HANDLE proc)
{
    static HMODULE tmp[MAXMOD];
    static MODULEINFO tinfo[MAXMOD];
    static wchar_t tname[MAXMOD][64];
    DWORD need = 0;
    int n;
    if (!K32EnumProcessModules(proc, tmp, sizeof(tmp), &need))
        return;
    n = (int)(need / sizeof(HMODULE));
    if (n > MAXMOD)
        n = MAXMOD;
    for (int i = 0; i < n; i++) {
        if (!K32GetModuleInformation(proc, tmp[i], &tinfo[i], sizeof(tinfo[i])))
            return;
        if (!K32GetModuleBaseNameW(proc, tmp[i], tname[i], 64))
            wcscpy(tname[i], L"?");
    }
    memcpy(mods, tmp, n * sizeof(HMODULE));
    memcpy(minfo, tinfo, n * sizeof(MODULEINFO));
    memcpy(mname, tname, n * sizeof(tname[0]));
    nmod = n;
}

static void where(DWORD a, char *buf, size_t n)
{
    for (int i = 0; i < nmod; i++) {
        DWORD b = (DWORD)(ULONG_PTR)minfo[i].lpBaseOfDll;
        if (a >= b && a < b + minfo[i].SizeOfImage) {
            snprintf(buf, n, "%ls+0x%lx", mname[i], a - b);
            return;
        }
    }
    snprintf(buf, n, "0x%08lx", a);
}

static int cmp_slot(const void *x, const void *y)
{
    const Slot *a = x, *b = y;
    return a->n < b->n ? 1 : a->n > b->n ? -1 : 0;
}

static int cmp_thr(const void *x, const void *y)
{
    const Thr *a = x, *b = y;
    return a->cpu_total < b->cpu_total ? 1 : a->cpu_total > b->cpu_total ? -1 : 0;
}

int main(int argc, char **argv)
{
    wchar_t want[MAX_PATH];
    DWORD pid = 0;
    HANDLE proc;
    int seconds, waited = 0, maxwait = 300;
    LARGE_INTEGER f, t0, tn;
    FILETIME si, sk, su;
    ULONGLONG sys_idle, sys_busy, last_idle, last_busy;
    double busy_cores = 0;

    if (argc < 4) {
        printf("usage: rtprof <process name> <seconds> <output file> [seconds to wait for the process, 300]\n");
        return 2;
    }
    MultiByteToWideChar(CP_ACP, 0, argv[1], -1, want, MAX_PATH);
    seconds = atoi(argv[2]);
    if (argc > 4 && atoi(argv[4]) > 0)
        maxwait = atoi(argv[4]);
    if (!(out = fopen(argv[3], "w"))) {
        printf("cannot write %s\n", argv[3]);
        return 2;
    }
    ntqit = (NtQIT)GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQueryInformationThread");
    printf("rtprof: waiting for %s ...\n", argv[1]);
    while (!pid && waited < maxwait * 2) {
        PROCESSENTRY32W pe;
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        pe.dwSize = sizeof(pe);
        for (BOOL ok = Process32FirstW(snap, &pe); ok; ok = Process32NextW(snap, &pe))
            if (!_wcsicmp(pe.szExeFile, want))
                pid = pe.th32ProcessID;
        CloseHandle(snap);
        if (!pid) {
            Sleep(500);
            waited++;
        }
    }
    if (!pid) {
        fprintf(out, "process %s not found within %d s\nRTPROF DONE (no process)\n", argv[1], maxwait);
        fclose(out);
        printf("%s did not start within %d s\n", argv[1], maxwait);
        return 1;
    }
    proc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!proc) {
        fprintf(out, "cannot open process %lu (error %lu)\nRTPROF DONE (no access)\n", pid, GetLastError());
        fclose(out);
        return 1;
    }
    timeBeginPeriod(1);
    printf("rtprof: profiling %s (pid %lu) for %d s; keep it running ...\n", argv[1], pid, seconds);
    fprintf(out, "rtprof: %s pid %lu, %d s, %lu processors\n", argv[1], pid, seconds,
            (unsigned long)GetActiveProcessorCount(ALL_PROCESSOR_GROUPS));
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&t0);
    GetSystemTimes(&si, &sk, &su);
    last_idle = ft(si);
    last_busy = ft(sk) + ft(su) - ft(si);
    refresh_threads(pid);
    /* the module list must be read while the process lives: now, and every 5 s for DLLs loaded later */
    load_modules(proc);
    for (int sec = 1; sec <= seconds; sec++) {
        ULONGLONG proc_delta = 0;
        DWORD code = 0;
        if (sec % 5 == 0)
            load_modules(proc);
        /* about one second: sample every ~20 ms while the process is busy */
        for (int k = 0; k < 50; k++) {
            if (busy_cores > 1.5)
                sample_all();
            Sleep(20);
        }
        if (!GetExitCodeProcess(proc, &code) || code != STILL_ACTIVE) {
            fprintf(out, "process exited after %d s\n", sec);
            break;
        }
        refresh_threads(pid);
        for (int i = 0; i < nthr; i++) {
            FILETIME c, e, kk, u;
            if (thr[i].alive && GetThreadTimes(thr[i].h, &c, &e, &kk, &u)) {
                ULONGLONG now = ft(kk) + ft(u), d = now - thr[i].cpu_last;
                thr[i].cpu_last = now;
                thr[i].cpu_total += d;
                thr[i].cpu_win += d;
                proc_delta += d;
            }
        }
        QueryPerformanceCounter(&tn);
        GetSystemTimes(&si, &sk, &su);
        sys_idle = ft(si) - last_idle;
        sys_busy = ft(sk) + ft(su) - ft(si) - last_busy;
        last_idle = ft(si);
        last_busy = ft(sk) + ft(su) - ft(si);
        busy_cores = proc_delta / 1e7;
        if (sec % 5 == 0) {
            int top[6] = { -1, -1, -1, -1, -1, -1 };
            double el = (double)(tn.QuadPart - t0.QuadPart) / f.QuadPart;
            for (int i = 0; i < nthr; i++)
                for (int j = 0; j < 6; j++)
                    if (top[j] < 0 || thr[i].cpu_win > thr[top[j]].cpu_win) {
                        for (int m = 5; m > j; m--)
                            top[m] = top[m - 1];
                        top[j] = i;
                        break;
                    }
            fprintf(out, "t=%5.1fs  last 1 s: process %.0f%% of one core, system busy %.0f%%  | busiest in last 5 s:",
                    el, busy_cores * 100.0, sys_busy + sys_idle ? 100.0 * sys_busy / (double)(sys_busy + sys_idle) : 0.0);
            for (int j = 0; j < 6 && top[j] >= 0; j++)
                fprintf(out, " %lu:%.0f%%(p%d)", thr[top[j]].tid, thr[top[j]].cpu_win / 5e5, thr[top[j]].prio);
            fprintf(out, "\n");
            fflush(out);
            for (int i = 0; i < nthr; i++)
                thr[i].cpu_win = 0;
        }
    }
    timeEndPeriod(1);
    load_modules(proc);
    fprintf(out, "\nmodules:\n");
    for (int i = 0; i < nmod; i++)
        fprintf(out, "  %-28ls base 0x%08lx size 0x%lx\n", mname[i], (DWORD)(ULONG_PTR)minfo[i].lpBaseOfDll,
                (DWORD)minfo[i].SizeOfImage);
    qsort(thr, nthr, sizeof(Thr), cmp_thr);
    fprintf(out, "\nthreads (by CPU time):\n");
    for (int i = 0; i < nthr; i++) {
        Thr *t = &thr[i];
        char s[96];
        int used = 0;
        if (!t->hash)
            continue;
        where(t->start, s, sizeof(s));
        fprintf(out, "thread %lu: cpu %.2f s, priority %d, start %s, %lu samples\n", t->tid, t->cpu_total / 1e7,
                t->prio, s, t->samples);
        qsort(t->hash, HASHSZ, sizeof(Slot), cmp_slot);
        for (int k = 0; k < HASHSZ && t->hash[k].n && used < 30; k++, used++) {
            where(t->hash[k].pc, s, sizeof(s));
            fprintf(out, "    %6lu  %s\n", t->hash[k].n, s);
        }
    }
    fprintf(out, "RTPROF DONE\n");
    fclose(out);
    printf("rtprof: done\n");
    return 0;
}
