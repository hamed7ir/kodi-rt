/*
 * kodi-rt: x64 stand-in for checkasm.exe, to dry-run the neon10 kit's run-neon10.cmd on the server.
 * Default: prints a checkasm-style pass line, exit 0. -DSTANDIN_FAIL: a failed function, exit 1.
 * -DSTANDIN_NOPASSLINE: exit 0 without the pass line (must still count as FAIL).
 */
#include <stdio.h>

int main(int argc, char **argv)
{
    printf("checkasm (stand-in), args:");
    for (int i = 1; i < argc; i++)
        printf(" %s", argv[i]);
    printf("\n");
#if defined(STANDIN_FAIL)
    printf(" NEON:\n   put_hevc_qpel_h16_10 (hevc_pel.c:113)\n - hevc_pel.qpel [FAILED]\n");
    printf("checkasm: 1 of 42 tests failed\n");
    return 1;
#elif defined(STANDIN_NOPASSLINE)
    printf(" - hevc_pel.qpel [OK]\n");
    return 0;
#else
    printf(" - hevc_pel.qpel [OK]\ncheckasm: all 42 tests passed\n");
    return 0;
#endif
}
