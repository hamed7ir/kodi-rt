/*
 * h264md5 -- kodi-rt Stage 0 decode check (not part of ffmpeg-rt).
 *
 * Decodes every video frame of each clip and prints an MD5 of each frame's visible pixels (planes packed with
 * align 1, i.e. what av_image_copy_to_buffer gives) and an MD5 over the whole stream. H.264/HEVC/VP9 decoding is
 * bit-exact, so the ARM32 build (rt2.2, NEON on) must print exactly what the x64 C-only reference build prints.
 *
 * stdout: deterministic lines only (compared byte for byte with the reference).
 * stderr: build identity, CPU flags, thread setting, timings (not compared).
 *
 * Usage: h264md5 [--threads N] [--perturb] clip [clip ...]
 *   --threads N  decoder thread_count (0 = FFmpeg picks; default 1)
 *   --perturb    flip one byte of frame 1 before hashing, so the output MUST differ (proves the check can fail)
 * Exit code: number of clips that failed to open or decoded no frame.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/cpu.h>
#include <libavutil/imgutils.h>
#include <libavutil/md5.h>
#include <libavutil/pixdesc.h>
#include <libavutil/time.h>

static void to_hex(const uint8_t *d, int n, char *out)
{
    static const char x[] = "0123456789abcdef";
    int i;
    for (i = 0; i < n; i++) {
        out[2 * i] = x[d[i] >> 4];
        out[2 * i + 1] = x[d[i] & 15];
    }
    out[2 * n] = 0;
}

static const char *base_name(const char *p)
{
    const char *b = p, *s;
    for (s = p; *s; s++)
        if (*s == '/' || *s == '\\' || *s == ':') b = s + 1;
    return b;
}

static const char *errstr(int err)
{
    static char buf[AV_ERROR_MAX_STRING_SIZE];
    memset(buf, 0, sizeof(buf));
    av_strerror(err, buf, sizeof(buf));
    return buf;
}

static int g_perturb = 0;

/* hash one decoded frame; returns 0 on success */
static int hash_frame(AVFrame *f, int n, struct AVMD5 *all, uint8_t **buf, int *cap)
{
    uint8_t d[16];
    char hx[33];
    int size = av_image_get_buffer_size(f->format, f->width, f->height, 1);
    if (size <= 0) {
        printf("  frame %4d unsupported pix_fmt %d\n", n, f->format);
        return -1;
    }
    if (size > *cap) {
        av_free(*buf);
        *buf = av_malloc(size);
        if (!*buf) { *cap = 0; return -1; }
        *cap = size;
    }
    if (av_image_copy_to_buffer(*buf, size, (const uint8_t * const *)f->data, f->linesize,
                                f->format, f->width, f->height, 1) < 0) {
        printf("  frame %4d copy failed\n", n);
        return -1;
    }
    if (g_perturb && n == 1) (*buf)[size / 2] ^= 0x01;
    av_md5_sum(d, *buf, size);
    av_md5_update(all, *buf, size);
    to_hex(d, 16, hx);
    printf("  frame %4d %c pts=%lld %dx%d %s md5=%s\n", n, av_get_picture_type_char(f->pict_type),
           (long long)f->best_effort_timestamp, f->width, f->height,
           av_get_pix_fmt_name(f->format) ? av_get_pix_fmt_name(f->format) : "?", hx);
    return 0;
}

static int run_clip(const char *path, int threads)
{
    AVFormatContext *fmt = NULL;
    AVCodecContext *ctx = NULL;
    const AVCodec *dec = NULL;
    AVPacket *pkt = NULL;
    AVFrame *frm = NULL;
    struct AVMD5 *all = NULL;
    uint8_t *buf = NULL, d[16];
    char hx[33];
    int cap = 0, ret, si, frames = 0, bad = 0;
    int64_t t0, t1;
    const char *prof;

    printf("clip %s\n", base_name(path));
    if ((ret = avformat_open_input(&fmt, path, NULL, NULL)) < 0) {
        printf("  open failed: %s\n", errstr(ret));
        return 1;
    }
    if ((ret = avformat_find_stream_info(fmt, NULL)) < 0) {
        printf("  find_stream_info failed: %s\n", errstr(ret));
        avformat_close_input(&fmt);
        return 1;
    }
    si = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (si < 0) {
        printf("  no video stream\n");
        avformat_close_input(&fmt);
        return 1;
    }
    dec = avcodec_find_decoder(fmt->streams[si]->codecpar->codec_id);
    if (!dec) {
        printf("  no decoder for codec id %d\n", fmt->streams[si]->codecpar->codec_id);
        avformat_close_input(&fmt);
        return 1;
    }
    ctx = avcodec_alloc_context3(dec);
    all = av_md5_alloc();
    pkt = av_packet_alloc();
    frm = av_frame_alloc();
    if (!ctx || !all || !pkt || !frm) { printf("  alloc failed\n"); return 1; }
    avcodec_parameters_to_context(ctx, fmt->streams[si]->codecpar);
    ctx->thread_count = threads;
    if ((ret = avcodec_open2(ctx, dec, NULL)) < 0) {
        printf("  avcodec_open2 failed: %s\n", errstr(ret));
        return 1;
    }
    prof = avcodec_profile_name(ctx->codec_id, ctx->profile);
    printf("  codec=%s profile=%s level=%d coded=%dx%d\n", dec->name, prof ? prof : "?", ctx->level,
           ctx->width, ctx->height);
    av_md5_init(all);

    t0 = av_gettime_relative();
    for (;;) {
        int eof = av_read_frame(fmt, pkt) < 0;
        if (!eof && pkt->stream_index != si) { av_packet_unref(pkt); continue; }
        ret = avcodec_send_packet(ctx, eof ? NULL : pkt);
        if (!eof) av_packet_unref(pkt);
        if (ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF) {
            printf("  send_packet error: %s\n", errstr(ret));
            bad = 1;
            break;
        }
        while ((ret = avcodec_receive_frame(ctx, frm)) >= 0) {
            frames++;
            if (hash_frame(frm, frames, all, &buf, &cap) < 0) bad = 1;
            av_frame_unref(frm);
        }
        if (ret != AVERROR(EAGAIN) && ret != AVERROR_EOF) {
            printf("  receive_frame error: %s\n", errstr(ret));
            bad = 1;
            break;
        }
        if (eof) break;
    }
    t1 = av_gettime_relative();

    av_md5_final(all, d);
    to_hex(d, 16, hx);
    printf("  frames=%d stream_md5=%s%s\n", frames, hx, bad ? " (ERRORS)" : "");
    fprintf(stderr, "[info] %s: %d frames, threads=%d (requested), %.3f s, %.1f fps\n", base_name(path), frames,
            threads, (t1 - t0) / 1e6, (t1 > t0) ? frames / ((t1 - t0) / 1e6) : 0.0);

    av_free(buf);
    av_free(all);
    av_frame_free(&frm);
    av_packet_free(&pkt);
    avcodec_free_context(&ctx);
    avformat_close_input(&fmt);
    return (frames > 0 && !bad) ? 0 : 1;
}

int main(int argc, char **argv)
{
    int i, threads = 1, failed = 0, nclips = 0;
    int f = av_get_cpu_flags();

    setvbuf(stdout, NULL, _IONBF, 0);
    fprintf(stderr, "[info] libavcodec %u.%u.%u  libavformat %u.%u.%u  libavutil %u.%u.%u\n",
            LIBAVCODEC_VERSION_MAJOR, LIBAVCODEC_VERSION_MINOR, LIBAVCODEC_VERSION_MICRO,
            LIBAVFORMAT_VERSION_MAJOR, LIBAVFORMAT_VERSION_MINOR, LIBAVFORMAT_VERSION_MICRO,
            LIBAVUTIL_VERSION_MAJOR, LIBAVUTIL_VERSION_MINOR, LIBAVUTIL_VERSION_MICRO);
    fprintf(stderr, "[info] av_get_cpu_flags=0x%08x", f);
#ifdef AV_CPU_FLAG_NEON
    fprintf(stderr, " NEON=%s", (f & AV_CPU_FLAG_NEON) ? "yes" : "no");
#endif
    fprintf(stderr, " av_cpu_count=%d\n", av_cpu_count());
    fprintf(stderr, "[info] configuration: %s\n", avcodec_configuration());

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--threads") && i + 1 < argc) { threads = atoi(argv[++i]); continue; }
        if (!strcmp(argv[i], "--perturb")) { g_perturb = 1; continue; }
        nclips++;
        failed += run_clip(argv[i], threads);
    }
    if (!nclips) {
        fprintf(stderr, "usage: h264md5 [--threads N] [--perturb] clip [clip ...]\n");
        return 2;
    }
    printf("summary clips=%d failed=%d\n", nclips, failed);
    return failed;
}
