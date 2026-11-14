/*
 * kodi-rt: bit-exact test of libavcodec/arm/hevcdsp_mc10_neon.c (compiled for x64 with include/arm_neon.h, the scalar
 * stand-in) against FFmpeg's own 10-bit C functions (the pure-C x64 reference build's ff_hevc_dsp_init).
 * Every function the NEON init installs, every width it installs it for, several heights (also not equal to the
 * width), every filter phase mx/my, random 10-bit sources; also checks that nothing is written outside the block.
 * Prints one line per function family and "MC10 EMU TEST: PASS" or "FAIL".
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libavutil/cpu.h"
#include "libavcodec/hevc/dsp.h"

void ff_hevc_dsp_init_mc10_neon(HEVCDSPContext *c);

#define SSTRIDE  (MAX_PB_SIZE + 32)              /* source samples per row */
#define SROWS    (MAX_PB_SIZE + 32)
#define CANARY   0x5A5A

static const int widths[10] = { 2, 4, 6, 8, 12, 16, 24, 32, 48, 64 };
static const int heights[]  = { 2, 4, 6, 8, 12, 16, 24, 32, 48, 64, 1, 3 };

static uint32_t rng = 1;
static uint32_t rnd(void) { rng = rng * 1664525u + 1013904223u; return rng >> 8; }

static uint16_t srcbuf[SROWS * SSTRIDE];
static int16_t  src2buf[(MAX_PB_SIZE + 8) * MAX_PB_SIZE];
static int16_t  d16a[(MAX_PB_SIZE + 4) * MAX_PB_SIZE], d16b[(MAX_PB_SIZE + 4) * MAX_PB_SIZE];
static uint16_t dpa[(MAX_PB_SIZE + 4) * (MAX_PB_SIZE + 8)], dpb[(MAX_PB_SIZE + 4) * (MAX_PB_SIZE + 8)];
#define DSTRIDE  (MAX_PB_SIZE + 8)               /* pixel destination samples per row */

static long tested, failed;

static void fill(int extreme)
{
    for (int i = 0; i < SROWS * SSTRIDE; i++)
        srcbuf[i] = extreme ? ((rnd() & 1) ? 1023 : 0) : (rnd() & 1023);
    /* src2 holds a 14-bit intermediate prediction: the values put_hevc_qpel/epel produce for 10-bit samples */
    for (int i = 0; i < (int)(sizeof(src2buf) / sizeof(src2buf[0])); i++)
        src2buf[i] = (int16_t)((int)(rnd() % 34000) - 7000);
}

static const uint8_t *srcp(void) { return (const uint8_t *)(srcbuf + 8 * SSTRIDE + 8); }

typedef void (*plain_fn)(int16_t *, const uint8_t *, ptrdiff_t, int, intptr_t, intptr_t, int);
typedef void (*uni_fn)(uint8_t *, ptrdiff_t, const uint8_t *, ptrdiff_t, int, intptr_t, intptr_t, int);
typedef void (*bi_fn)(uint8_t *, ptrdiff_t, const uint8_t *, ptrdiff_t, const int16_t *, int, intptr_t, intptr_t, int);

static int check_plain(const char *name, plain_fn ref, plain_fn neu, int w, int h, int mx, int my)
{
    for (size_t i = 0; i < sizeof(d16a) / sizeof(d16a[0]); i++) d16a[i] = d16b[i] = (int16_t)CANARY;
    ref(d16a, srcp(), SSTRIDE * 2, h, mx, my, w);
    neu(d16b, srcp(), SSTRIDE * 2, h, mx, my, w);
    tested++;
    for (int y = 0; y < MAX_PB_SIZE + 4; y++)
        for (int x = 0; x < MAX_PB_SIZE; x++) {
            const int in = y < h && x < w;
            const int16_t a = d16a[y * MAX_PB_SIZE + x], b = d16b[y * MAX_PB_SIZE + x];
            if (a != b || (!in && b != (int16_t)CANARY)) {
                if (failed < 20)
                    printf("  MISMATCH %s w%d h%d mx%d my%d at (%d,%d): ref %d neon %d%s\n", name, w, h, mx, my,
                           x, y, a, b, in ? "" : " (outside the block)");
                failed++;
                return 1;
            }
        }
    return 0;
}

static int check_pix(const char *name, uni_fn uref, uni_fn uneu, bi_fn bref, bi_fn bneu, int w, int h, int mx, int my)
{
    for (size_t i = 0; i < sizeof(dpa) / sizeof(dpa[0]); i++) dpa[i] = dpb[i] = CANARY;
    if (uref) {
        uref((uint8_t *)dpa, DSTRIDE * 2, srcp(), SSTRIDE * 2, h, mx, my, w);
        uneu((uint8_t *)dpb, DSTRIDE * 2, srcp(), SSTRIDE * 2, h, mx, my, w);
    } else {
        bref((uint8_t *)dpa, DSTRIDE * 2, srcp(), SSTRIDE * 2, src2buf, h, mx, my, w);
        bneu((uint8_t *)dpb, DSTRIDE * 2, srcp(), SSTRIDE * 2, src2buf, h, mx, my, w);
    }
    tested++;
    for (int y = 0; y < MAX_PB_SIZE + 4; y++)
        for (int x = 0; x < DSTRIDE; x++) {
            const int in = y < h && x < w;
            const uint16_t a = dpa[y * DSTRIDE + x], b = dpb[y * DSTRIDE + x];
            if (a != b || (!in && b != CANARY)) {
                if (failed < 20)
                    printf("  MISMATCH %s w%d h%d mx%d my%d at (%d,%d): ref %u neon %u%s\n", name, w, h, mx, my,
                           x, y, a, b, in ? "" : " (outside the block)");
                failed++;
                return 1;
            }
        }
    return 0;
}

int main(void)
{
    HEVCDSPContext ref, neu;
    static const char *dir[2][2] = { { "pixels", "h" }, { "v", "hv" } };
    int installed = 0;

    av_force_cpu_flags(0);
    ff_hevc_dsp_init(&ref, 10);
    memset(&neu, 0, sizeof(neu));
    ff_hevc_dsp_init_mc10_neon(&neu);

    for (int pass = 0; pass < 2; pass++) {
        fill(pass);
        for (int fam = 0; fam < 2; fam++) {                /* 0 qpel, 1 epel */
            const int nphase = fam ? 8 : 4;
            for (int v = 0; v < 2; v++)
                for (int hz = 0; hz < 2; hz++)
                    for (int kind = 0; kind < 3; kind++) {     /* plain, uni, bi */
                        long t0 = tested, f0 = failed;
                        char name[64];
                        snprintf(name, sizeof(name), "put_hevc_%s%s_%s", fam ? "epel" : "qpel",
                                 kind == 1 ? "_uni" : kind == 2 ? "_bi" : "", dir[v][hz]);
                        for (int wi = 0; wi < 10; wi++) {
                            void *n, *r;
                            if (kind == 0) { n = (void *)(fam ? neu.put_hevc_epel : neu.put_hevc_qpel)[wi][v][hz];
                                             r = (void *)(fam ? ref.put_hevc_epel : ref.put_hevc_qpel)[wi][v][hz]; }
                            else if (kind == 1) { n = (void *)(fam ? neu.put_hevc_epel_uni : neu.put_hevc_qpel_uni)[wi][v][hz];
                                                  r = (void *)(fam ? ref.put_hevc_epel_uni : ref.put_hevc_qpel_uni)[wi][v][hz]; }
                            else { n = (void *)(fam ? neu.put_hevc_epel_bi : neu.put_hevc_qpel_bi)[wi][v][hz];
                                   r = (void *)(fam ? ref.put_hevc_epel_bi : ref.put_hevc_qpel_bi)[wi][v][hz]; }
                            if (!n)
                                continue;
                            if (pass == 0)
                                installed++;
                            for (size_t hi = 0; hi < sizeof(heights) / sizeof(heights[0]); hi++)
                                for (int mx = hz ? 1 : 0; mx < (hz ? nphase : 1); mx++)
                                    for (int my = v ? 1 : 0; my < (v ? nphase : 1); my++) {
                                        const int w = widths[wi], h = heights[hi];
                                        if (kind == 0)
                                            check_plain(name, (plain_fn)r, (plain_fn)n, w, h, mx, my);
                                        else if (kind == 1)
                                            check_pix(name, (uni_fn)r, (uni_fn)n, NULL, NULL, w, h, mx, my);
                                        else
                                            check_pix(name, NULL, NULL, (bi_fn)r, (bi_fn)n, w, h, mx, my);
                                    }
                        }
                        if (tested > t0)
                            printf("%-26s %s: %5ld cases, %ld mismatching\n", name, pass ? "extremes" : "random  ",
                                   tested - t0, failed - f0);
                    }
        }
    }
    printf("installed entries: %d; cases: %ld; mismatching: %ld\n", installed, tested, failed);
    printf("MC10 EMU TEST: %s\n", failed || !installed ? "FAIL" : "PASS");
    return failed || !installed;
}
