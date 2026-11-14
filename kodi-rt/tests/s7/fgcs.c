/*
 * kodi-rt: Kodi's video filter graph for a 10-bit frame and an 8-bit-only renderer (DVDVideoCodecFFmpeg::FilterOpen,
 * patch 0014's format list), and the colorspace of its buffer source.
 *   buffer (Kodi's args) -> buffersink (pixel_formats = Kodi's m_formats, passed with its NONE terminator counted, as
 *   Kodi does), linked directly; avfilter_graph_config inserts the scaler. Frames: 1280x544 yuv420p10le tagged
 *   BT.709, limited range, like the x265 file's.
 *   mode "kodi":  args without colorspace/range (Kodi today)
 *   mode "fixed": args + ":colorspace=<frame's>:range=<frame's>" (the proposed fix)
 * Prints swscale's/avfilter's verbose lines that name the conversion, the output frame's format and colorspace, a
 * checksum of the output planes, and the time per frame.
 * Usage: fgcs kodi|fixed [frames=100]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <windows.h>

#include "libavfilter/avfilter.h"
#include "libavfilter/buffersink.h"
#include "libavfilter/buffersrc.h"
#include "libavutil/frame.h"
#include "libavutil/log.h"
#include "libavutil/opt.h"
#include "libavutil/pixdesc.h"

static double now(void)
{
  LARGE_INTEGER f, c;
  QueryPerformanceFrequency(&f);
  QueryPerformanceCounter(&c);
  return (double)c.QuadPart / (double)f.QuadPart;
}

static void log_cb(void *avcl, int level, const char *fmt, va_list vl)
{
  char line[1024];
  int prefix = 1;
  (void)avcl;
  if (level > AV_LOG_VERBOSE)
    return;
  av_log_format_line(avcl, level, fmt, vl, line, sizeof(line), &prefix);
  if (strstr(line, "intermediate") || strstr(line, "color matrix") || strstr(line, "->") ||
      strstr(line, "rror") || strstr(line, "scale"))
    fprintf(stdout, "  log: %s", line);
}

int main(int argc, char **argv)
{
  const int fixed = argc > 1 && !strcmp(argv[1], "fixed");
  const int n = argc > 2 ? atoi(argv[2]) : 100;
  const int w = 1280, h = 544;
  int ret;

  av_log_set_level(AV_LOG_VERBOSE);
  av_log_set_callback(log_cb);

  AVFilterGraph *graph = avfilter_graph_alloc();
  const AVFilter *srcf = avfilter_get_by_name("buffer");
  const AVFilter *sinkf = avfilter_get_by_name("buffersink");
  char args[512];
  snprintf(args, sizeof(args), "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d%s", w, h,
           AV_PIX_FMT_YUV420P10LE, 1, 1000, 1, 1, fixed ? ":colorspace=1:range=1" : "");
  printf("mode %s: buffer args \"%s\"\n", fixed ? "fixed" : "kodi", args);

  AVFilterContext *out = avfilter_graph_alloc_filter(graph, sinkf, "out");
  /* Kodi: m_formats = GetPixFormats() (patch 0014's list; the NONE terminator only for avfilter < 10.6.100), and
   * av_opt_set_array(..., m_formats.size(), ...) */
  enum AVPixelFormat fmts[] = { AV_PIX_FMT_D3D11VA_VLD, AV_PIX_FMT_YUV420P, AV_PIX_FMT_NV12 };
  ret = av_opt_set_array(out, "pixel_formats", AV_OPT_SEARCH_CHILDREN, 0, 3, AV_OPT_TYPE_PIXEL_FMT, fmts);
  if (ret < 0) { printf("av_opt_set_array failed %d\n", ret); return 1; }
  if ((ret = avfilter_init_str(out, NULL)) < 0) { printf("init out failed %d\n", ret); return 1; }
  AVFilterContext *in = NULL;
  if ((ret = avfilter_graph_create_filter(&in, srcf, "src", args, NULL, graph)) < 0) { printf("src failed %d\n", ret); return 1; }
  if ((ret = avfilter_link(in, 0, out, 0)) < 0) { printf("link failed %d\n", ret); return 1; }
  if ((ret = avfilter_graph_config(graph, NULL)) < 0) { printf("config failed %d\n", ret); return 1; }

  AVFrame *src = av_frame_alloc(), *dst = av_frame_alloc();
  src->width = w; src->height = h; src->format = AV_PIX_FMT_YUV420P10LE;
  src->colorspace = AVCOL_SPC_BT709; src->color_range = AVCOL_RANGE_MPEG;
  src->color_primaries = AVCOL_PRI_BT709; src->color_trc = AVCOL_TRC_BT709;
  if (av_frame_get_buffer(src, 0) < 0) return 1;
  for (int p = 0; p < 3; p++) {
    int pw = p ? w / 2 : w, ph = p ? h / 2 : h;
    for (int y = 0; y < ph; y++) {
      unsigned short *row = (unsigned short *)(src->data[p] + (size_t)y * src->linesize[p]);
      for (int x = 0; x < pw; x++)
        row[x] = (unsigned short)(p ? 512 + ((x * 3 + y) % 300) - 150 : 64 + ((x + 2 * y) % 876));
    }
  }

  double t0 = 0;
  unsigned long long sum = 0;
  for (int i = 0; i < n + 1; i++) {
    if (i == 1)
      t0 = now();   /* frame 0 builds the scaler; time the rest */
    src->pts = i;
    if ((ret = av_buffersrc_add_frame_flags(in, src, AV_BUFFERSRC_FLAG_KEEP_REF)) < 0) { printf("add failed %d\n", ret); return 1; }
    if ((ret = av_buffersink_get_frame(out, dst)) < 0) { printf("get failed %d\n", ret); return 1; }
    if (i == 0) {
      printf("output: %s, colorspace %s, range %s\n", av_get_pix_fmt_name(dst->format),
             av_color_space_name(dst->colorspace), av_color_range_name(dst->color_range));
      const int ph[3] = { h, h / 2, h / 2 }, pw[3] = { w, w / 2, w / 2 };
      for (int p = 0; p < 3 && dst->data[p]; p++)
        for (int y = 0; y < ph[p]; y++)
          for (int x = 0; x < pw[p]; x++)
            sum = sum * 31 + dst->data[p][(size_t)y * dst->linesize[p] + x];
      printf("output checksum %016llx; Y(100,100)=%d U(50,50)=%d V(50,50)=%d (input Y %d U %d V %d, 10-bit)\n", sum,
             dst->data[0][100 * dst->linesize[0] + 100], dst->data[1][50 * dst->linesize[1] + 50],
             dst->data[2][50 * dst->linesize[2] + 50],
             ((unsigned short *)(src->data[0] + 100 * src->linesize[0]))[100],
             ((unsigned short *)(src->data[1] + 50 * src->linesize[1]))[50],
             ((unsigned short *)(src->data[2] + 50 * src->linesize[2]))[50]);
    }
    av_frame_unref(dst);
  }
  double t = now() - t0;
  printf("RESULT %s: %.2f ms per frame (%d frames)\n", fixed ? "fixed" : "kodi", 1000.0 * t / n, n);
  av_frame_free(&src);
  av_frame_free(&dst);
  avfilter_graph_free(&graph);
  return 0;
}
