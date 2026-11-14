/*
 * kodi-rt: which swscale path converts yuv420p10le -> yuv420p (Kodi's 10->8-bit step, patch 0014), and how long it
 * takes per 1280x544 frame. Prints swscale's own verbose lines (they name the converter it chose), then the time.
 * Usage: convbench [frames=200] [flags: bicubic|bilinear|point]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#include "libavutil/frame.h"
#include "libavutil/log.h"
#include "libavutil/pixdesc.h"
#include "libswscale/swscale.h"

static double now(void)
{
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart / (double)f.QuadPart;
}

int main(int argc, char **argv)
{
    const int w = 1280, h = 544, n = argc > 1 ? atoi(argv[1]) : 200;
    int flags = SWS_BICUBIC;
    AVFrame *src = av_frame_alloc(), *dst = av_frame_alloc();
    struct SwsContext *sws;
    double t0, t1;

    if (argc > 2 && !strcmp(argv[2], "bilinear")) flags = SWS_BILINEAR;
    if (argc > 2 && !strcmp(argv[2], "point"))    flags = SWS_POINT;
    av_log_set_level(AV_LOG_DEBUG);
    src->format = AV_PIX_FMT_YUV420P10LE; src->width = w; src->height = h;
    src->colorspace = AVCOL_SPC_BT709; src->color_range = AVCOL_RANGE_MPEG;
    dst->format = AV_PIX_FMT_YUV420P; dst->width = w; dst->height = h;
    dst->colorspace = AVCOL_SPC_BT709; dst->color_range = AVCOL_RANGE_MPEG;
    if (av_frame_get_buffer(src, 32) < 0 || av_frame_get_buffer(dst, 32) < 0)
        return 1;
    for (int p = 0; p < 3; p++) {
        const int ph = p ? h / 2 : h, pw = p ? w / 2 : w;
        for (int y = 0; y < ph; y++) {
            uint16_t *row = (uint16_t *)(src->data[p] + y * src->linesize[p]);
            for (int x = 0; x < pw; x++)
                row[x] = (uint16_t)((x * 7 + y * 13 + p * 101) & 1023);
        }
    }

    /* the legacy API: what swscale picks for this pair */
    printf("== sws_getContext + sws_scale (flags %d)\n", flags);
    fflush(stdout);
    sws = sws_getContext(w, h, src->format, w, h, dst->format, flags, NULL, NULL, NULL);
    if (!sws)
        return 1;
    t0 = now();
    for (int i = 0; i < n; i++)
        sws_scale(sws, (const uint8_t *const *)src->data, src->linesize, 0, h, dst->data, dst->linesize);
    t1 = now();
    printf("legacy sws_scale: %.3f ms per frame (%d frames)\n", (t1 - t0) * 1000.0 / n, n);
    sws_freeContext(sws);

    /* the frame API vf_scale uses in FFmpeg 8+ */
    printf("== sws_scale_frame (what vf_scale calls)\n");
    fflush(stdout);
    sws = sws_alloc_context();
    av_opt_set_int(sws, "sws_flags", flags, 0);
    av_opt_set_int(sws, "threads", 1, 0);
    av_log_set_level(AV_LOG_VERBOSE);
    t0 = now();
    for (int i = 0; i < n; i++) {
        if (sws_scale_frame(sws, dst, src) < 0) {
            printf("sws_scale_frame failed\n");
            return 1;
        }
        if (i == 0)
            av_log_set_level(AV_LOG_INFO);
    }
    t1 = now();
    printf("sws_scale_frame: %.3f ms per frame (%d frames)\n", (t1 - t0) * 1000.0 / n, n);
    sws_free_context(&sws);
    av_frame_free(&src);
    av_frame_free(&dst);
    return 0;
}
