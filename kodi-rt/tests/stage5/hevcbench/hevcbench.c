/*
 * kodi-rt: how fast this FFmpeg build decodes a file's video stream on the device, outside Kodi.
 * Usage: hevcbench <file> [seconds=15] [threads=4]
 * Decodes the first <seconds> of the video four times: NEON on/off (av_force_cpu_flags) x loop filter on/skipped
 * (skip_loop_filter = all, what advancedsettings.xml's skiploopfilter 48 does), and prints frames, time, fps and the
 * speed relative to real time (1.00x = just fast enough). The last line is "HEVCBENCH DONE".
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/cpu.h"
#include "libavutil/pixdesc.h"

static double now(void)
{
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart / (double)f.QuadPart;
}

static int run(const char *path, int neon, int skiplf, double seconds, int threads, int info)
{
    AVFormatContext *fmt = NULL;
    AVCodecContext *dec = NULL;
    AVPacket *pkt = NULL;
    AVFrame *frm = NULL;
    const AVCodec *codec;
    AVStream *st;
    double fps, t0, t1;
    int ret, vs, frames = 0, target, rc = 1;

    av_force_cpu_flags(neon ? -1 : 0);
    if ((ret = avformat_open_input(&fmt, path, NULL, NULL)) < 0) {
        printf("cannot open the file (error %d)\n", ret);
        return 1;
    }
    if (avformat_find_stream_info(fmt, NULL) < 0 ||
        (vs = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0)) < 0) {
        printf("no video stream found\n");
        goto end;
    }
    st = fmt->streams[vs];
    if (!(codec = avcodec_find_decoder(st->codecpar->codec_id)) || !(dec = avcodec_alloc_context3(codec)) ||
        avcodec_parameters_to_context(dec, st->codecpar) < 0) {
        printf("no decoder for this video\n");
        goto end;
    }
    dec->thread_count = threads;
    dec->thread_type  = FF_THREAD_FRAME | FF_THREAD_SLICE;
    if (skiplf)
        dec->skip_loop_filter = AVDISCARD_ALL;
    if (avcodec_open2(dec, codec, NULL) < 0) {
        printf("cannot open the decoder\n");
        goto end;
    }
    fps = av_q2d(st->avg_frame_rate);
    if (fps <= 0)
        fps = av_q2d(st->r_frame_rate);
    if (fps <= 0)
        fps = 24;
    target = (int)(seconds * fps + 0.5);
    if (info) {
        const char *pf = av_get_pix_fmt_name(dec->pix_fmt);
        printf("video: %s, %dx%d, %s, %.3f fps; decoding the first %d frames (%.0f s) with %d threads\n",
               codec->name, dec->width, dec->height, pf ? pf : "?", fps, target, seconds, threads);
    }
    pkt = av_packet_alloc();
    frm = av_frame_alloc();
    t0 = now();
    while (frames < target && av_read_frame(fmt, pkt) >= 0) {
        if (pkt->stream_index == vs && avcodec_send_packet(dec, pkt) >= 0)
            while (frames < target && avcodec_receive_frame(dec, frm) == 0) {
                frames++;
                av_frame_unref(frm);
            }
        av_packet_unref(pkt);
    }
    if (frames < target && avcodec_send_packet(dec, NULL) >= 0)
        while (frames < target && avcodec_receive_frame(dec, frm) == 0) {
            frames++;
            av_frame_unref(frm);
        }
    t1 = now();
    printf("%-5s loop filter %-7s: %5d frames in %7.2f s = %6.2f fps (%.2fx real time)\n", neon ? "NEON," : "C,",
           skiplf ? "skipped" : "on", frames, t1 - t0, frames / (t1 - t0), frames / (t1 - t0) / fps);
    fflush(stdout);
    rc = frames > 0 ? 0 : 1;
end:
    av_frame_free(&frm);
    av_packet_free(&pkt);
    avcodec_free_context(&dec);
    avformat_close_input(&fmt);
    return rc;
}

int wmain(int argc, wchar_t **wargv)
{
    char path[4 * MAX_PATH];
    double seconds = argc > 2 ? _wtof(wargv[2]) : 15.0;
    int threads = argc > 3 ? _wtoi(wargv[3]) : 4, bad = 0;

    if (argc < 2) {
        printf("usage: hevcbench <video file> [seconds=15] [threads=4]\n");
        return 2;
    }
    if (seconds <= 0)
        seconds = 15.0;
    if (threads <= 0)
        threads = 4;
    /* FFmpeg takes UTF-8 file names on Windows */
    if (!WideCharToMultiByte(CP_UTF8, 0, wargv[1], -1, path, sizeof(path), NULL, NULL)) {
        printf("file name too long\n");
        return 2;
    }
    av_log_set_level(AV_LOG_ERROR);
    printf("hevcbench (kodi-rt), FFmpeg %s\n", av_version_info());
    bad |= run(path, 1, 0, seconds, threads, 1);
    bad |= run(path, 1, 1, seconds, threads, 0);
    bad |= run(path, 0, 0, seconds, threads, 0);
    bad |= run(path, 0, 1, seconds, threads, 0);
    printf("HEVCBENCH DONE%s\n", bad ? " (with errors)" : "");
    return bad;
}
