/*
 * kodi-rt: scalar stand-in for the NEON intrinsics libavcodec/arm/hevcdsp_mc10_neon.c uses, so that file can be
 * compiled for x64 and compared bit for bit with FFmpeg's C functions on the server. Each function follows the ARM
 * definition of the instruction (vshrn: shift, keep the low 16 bits; vrshr: add 1 << (n - 1) in wider precision, then
 * shift; vhadd: (a + b) >> 1 in wider precision, floor). Not a general NEON emulation: only what that file needs.
 */
#ifndef KODIRT_ARM_NEON_EMU_H
#define KODIRT_ARM_NEON_EMU_H

#include <stdint.h>
#include <string.h>

typedef struct { int8_t   v[8]; } int8x8_t;
typedef struct { int16_t  v[4]; } int16x4_t;
typedef struct { int16_t  v[8]; } int16x8_t;
typedef struct { uint16_t v[4]; } uint16x4_t;
typedef struct { uint16_t v[8]; } uint16x8_t;
typedef struct { int32_t  v[4]; } int32x4_t;

static inline int8x8_t   vld1_s8(const int8_t *p)      { int8x8_t r;   memcpy(r.v, p, 8);  return r; }
static inline uint16x4_t vld1_u16(const uint16_t *p)   { uint16x4_t r; memcpy(r.v, p, 8);  return r; }
static inline uint16x8_t vld1q_u16(const uint16_t *p)  { uint16x8_t r; memcpy(r.v, p, 16); return r; }
static inline int16x4_t  vld1_s16(const int16_t *p)    { int16x4_t r;  memcpy(r.v, p, 8);  return r; }
static inline int16x8_t  vld1q_s16(const int16_t *p)   { int16x8_t r;  memcpy(r.v, p, 16); return r; }
static inline void vst1_s16(int16_t *p, int16x4_t a)   { memcpy(p, a.v, 8); }
static inline void vst1q_s16(int16_t *p, int16x8_t a)  { memcpy(p, a.v, 16); }
static inline void vst1_u16(uint16_t *p, uint16x4_t a) { memcpy(p, a.v, 8); }
static inline void vst1q_u16(uint16_t *p, uint16x8_t a){ memcpy(p, a.v, 16); }

static inline int16x4_t  vreinterpret_s16_u16(uint16x4_t a)  { int16x4_t r;  memcpy(&r, &a, 8);  return r; }
static inline int16x8_t  vreinterpretq_s16_u16(uint16x8_t a) { int16x8_t r;  memcpy(&r, &a, 16); return r; }
static inline uint16x4_t vreinterpret_u16_s16(int16x4_t a)   { uint16x4_t r; memcpy(&r, &a, 8);  return r; }
static inline uint16x8_t vreinterpretq_u16_s16(int16x8_t a)  { uint16x8_t r; memcpy(&r, &a, 16); return r; }

static inline int16x8_t vmovl_s8(int8x8_t a)
{ int16x8_t r; for (int i = 0; i < 8; i++) r.v[i] = a.v[i]; return r; }
static inline int16x4_t vget_low_s16(int16x8_t a)  { int16x4_t r; memcpy(r.v, a.v, 8);     return r; }
static inline int16x4_t vget_high_s16(int16x8_t a) { int16x4_t r; memcpy(r.v, a.v + 4, 8); return r; }
static inline int16x8_t vcombine_s16(int16x4_t a, int16x4_t b)
{ int16x8_t r; memcpy(r.v, a.v, 8); memcpy(r.v + 4, b.v, 8); return r; }
static inline int16x4_t vdup_n_s16(int16_t x)  { int16x4_t r; for (int i = 0; i < 4; i++) r.v[i] = x; return r; }
static inline int16x8_t vdupq_n_s16(int16_t x) { int16x8_t r; for (int i = 0; i < 8; i++) r.v[i] = x; return r; }
static inline int16x4_t vset_lane_s16(int16_t x, int16x4_t a, int lane) { a.v[lane] = x; return a; }

#define EMU_MINMAX(name, T, n, op) \
static inline T name(T a, T b) { T r; for (int i = 0; i < n; i++) r.v[i] = (a.v[i] op b.v[i]) ? a.v[i] : b.v[i]; return r; }
EMU_MINMAX(vmax_s16,  int16x4_t, 4, >)
EMU_MINMAX(vmaxq_s16, int16x8_t, 8, >)
EMU_MINMAX(vmin_s16,  int16x4_t, 4, <)
EMU_MINMAX(vminq_s16, int16x8_t, 8, <)

static inline int32x4_t vmull_lane_s16(int16x4_t a, int16x4_t v, int lane)
{ int32x4_t r; for (int i = 0; i < 4; i++) r.v[i] = (int32_t)a.v[i] * v.v[lane]; return r; }
static inline int32x4_t vmlal_lane_s16(int32x4_t acc, int16x4_t a, int16x4_t v, int lane)
{ for (int i = 0; i < 4; i++) acc.v[i] = (int32_t)((uint32_t)acc.v[i] + (uint32_t)((int32_t)a.v[i] * v.v[lane])); return acc; }
static inline int16x4_t vshrn_n_s32(int32x4_t a, int n)
{ int16x4_t r; for (int i = 0; i < 4; i++) r.v[i] = (int16_t)(uint16_t)(uint32_t)(a.v[i] >> n); return r; }

static inline int16x8_t vextq_s16(int16x8_t a, int16x8_t b, int n)
{ int16_t t[16]; int16x8_t r; memcpy(t, a.v, 16); memcpy(t + 8, b.v, 16); memcpy(r.v, t + n, 16); return r; }
static inline int16x4_t vext_s16(int16x4_t a, int16x4_t b, int n)
{ int16_t t[8]; int16x4_t r; memcpy(t, a.v, 8); memcpy(t + 4, b.v, 8); memcpy(r.v, t + n, 8); return r; }

static inline int16x8_t vrshrq_n_s16(int16x8_t a, int n)
{ int16x8_t r; for (int i = 0; i < 8; i++) r.v[i] = (int16_t)(((int32_t)a.v[i] + (1 << (n - 1))) >> n); return r; }
static inline int16x4_t vrshr_n_s16(int16x4_t a, int n)
{ int16x4_t r; for (int i = 0; i < 4; i++) r.v[i] = (int16_t)(((int32_t)a.v[i] + (1 << (n - 1))) >> n); return r; }
static inline int16x8_t vhaddq_s16(int16x8_t a, int16x8_t b)
{
    int16x8_t r;
    for (int i = 0; i < 8; i++) r.v[i] = (int16_t)(((int32_t)a.v[i] + b.v[i]) >> 1);
#ifdef KODIRT_EMU_FAULT   /* negative control: the test must report mismatches */
    r.v[3] += 16;
#endif
    return r;
}
static inline int16x4_t vhadd_s16(int16x4_t a, int16x4_t b)
{ int16x4_t r; for (int i = 0; i < 4; i++) r.v[i] = (int16_t)(((int32_t)a.v[i] + b.v[i]) >> 1); return r; }
static inline int16x8_t vshlq_n_s16(int16x8_t a, int n)
{ int16x8_t r; for (int i = 0; i < 8; i++) r.v[i] = (int16_t)(uint16_t)((uint16_t)a.v[i] << n); return r; }
static inline int16x4_t vshl_n_s16(int16x4_t a, int n)
{ int16x4_t r; for (int i = 0; i < 4; i++) r.v[i] = (int16_t)(uint16_t)((uint16_t)a.v[i] << n); return r; }

#endif
