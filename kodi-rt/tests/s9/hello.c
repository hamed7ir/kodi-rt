/* kodi-rt: smoke test of the x64/x86 cross files (cc-<arch>.sh + <arch>-target-link.rsp): prints the pointer size,
 * a 64-bit division and a double, so a wrong target or CRT shows. */
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    volatile int64_t a = 1234567890123LL, b = 97;
    volatile double d = 2.5;
    printf("pointer %u bytes, %lld / %lld = %lld, %.2f\n", (unsigned)sizeof(void *), (long long)a, (long long)b,
           (long long)(a / b), d * 3);
    return 0;
}
