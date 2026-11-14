/* kodi-rt Stage 3 device test, C libraries (ARM32, static /MT, rt2.4). Self-checking: every check prints
 *   CHECK <name> OK|FAIL <details>
 * and the program ends with "ALL PASSED (N checks)" or "FAILED (k of N checks)"; the exit code is the number of
 * failed checks. Usage: s3test-c.exe <font file> <writable folder>
 *   font: Kodi's Estuary font NotoSans-Regular.ttf (SIL OFL, from Kodi's tree); folder: where the curl file:// test
 *   writes and deletes one small file (the kit passes its results folder, so nothing outside it is touched). */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <zlib.h>
#include <sqlite3.h>
#define PCRE2_CODE_UNIT_WIDTH 8
#ifndef PCRE2_STATIC
#define PCRE2_STATIC
#endif
#include <pcre2.h>
#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <curl/curl.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <hb.h>
#include <hb-ft.h>
#include <fribidi.h>
#include <iconv.h>
#include <ass/ass.h>
#include <lzo/lzo1x.h>
#include <zstd.h>
#include <brotli/decode.h>
#include <brotli/encode.h>
#include <fstrcmp.h>
/* nghttp2.h is not included: it takes ssize_t from <sys/types.h>, which the Microsoft CRT lacks (curl defines
 * ssize_t itself before including it). The nghttp2 version is checked through curl, which links it. */

static int g_checks, g_failed;

static void check(const char *name, int ok, const char *fmt, ...)
{
  char details[512] = "";
  if (fmt) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(details, sizeof details, fmt, ap);
    va_end(ap);
  }
  g_checks++;
  if (!ok)
    g_failed++;
  printf("CHECK %-26s %s %s\n", name, ok ? "OK  " : "FAIL", details);
  fflush(stdout);
}

static const char text[] = "Kodi on the Surface RT, Windows RT 8.1, ARM32. The quick brown fox jumps over the lazy dog.";

/* ---------------------------------------------------------------- zlib */
static void test_zlib(void)
{
  check("zlib.version", strcmp(zlibVersion(), "1.3.2") == 0, "%s", zlibVersion());
  check("zlib.crc32", crc32(0, (const Bytef *)"123456789", 9) == 0xCBF43926UL, "0x%08lx",
        (unsigned long)crc32(0, (const Bytef *)"123456789", 9));
  check("zlib.adler32", adler32(1, (const Bytef *)"Wikipedia", 9) == 0x11E60398UL, "0x%08lx",
        (unsigned long)adler32(1, (const Bytef *)"Wikipedia", 9));
  unsigned char packed[256], unpacked[256];
  uLongf plen = sizeof packed, ulen = sizeof unpacked;
  int r1 = compress2(packed, &plen, (const Bytef *)text, sizeof text, 9);
  int r2 = uncompress(unpacked, &ulen, packed, plen);
  check("zlib.roundtrip", r1 == Z_OK && r2 == Z_OK && ulen == sizeof text && memcmp(unpacked, text, ulen) == 0,
        "%u -> %lu bytes", (unsigned)sizeof text, (unsigned long)plen);
}

/* ---------------------------------------------------------------- sqlite */
static int one_int(sqlite3 *db, const char *sql, long long *out)
{
  sqlite3_stmt *st = NULL;
  int ok = sqlite3_prepare_v2(db, sql, -1, &st, NULL) == SQLITE_OK && sqlite3_step(st) == SQLITE_ROW;
  if (ok)
    *out = sqlite3_column_int64(st, 0);
  sqlite3_finalize(st);
  return ok;
}

static void test_sqlite(void)
{
  check("sqlite.version", strcmp(sqlite3_libversion(), "3.39.4") == 0, "%s threadsafe=%d", sqlite3_libversion(),
        sqlite3_threadsafe());
  sqlite3 *db = NULL;
  if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
    check("sqlite.open", 0, "%s", sqlite3_errmsg(db));
    return;
  }
  int ok = sqlite3_exec(db,
                        "CREATE TABLE t(x INTEGER);"
                        "WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM c WHERE n<100) "
                        "INSERT INTO t SELECT n FROM c;",
                        NULL, NULL, NULL) == SQLITE_OK;
  long long v = 0;
  ok = ok && one_int(db, "SELECT sum(x) FROM t", &v);
  check("sqlite.sum", ok && v == 5050, "sum=%lld", v);
  ok = one_int(db, "SELECT CAST(sqrt(144) AS INTEGER)", &v);
  check("sqlite.math", ok && v == 12, "sqrt(144)=%lld", v);
  ok = sqlite3_exec(db,
                    "CREATE VIRTUAL TABLE f USING fts5(body);"
                    "INSERT INTO f VALUES('kodi media center'),('surface tablet'),('kodi on arm');",
                    NULL, NULL, NULL) == SQLITE_OK &&
       one_int(db, "SELECT count(*) FROM f WHERE f MATCH 'kodi'", &v);
  check("sqlite.fts5", ok && v == 2, "matches=%lld", v);
  ok = sqlite3_exec(db, "CREATE VIRTUAL TABLE r USING rtree(id, x0, x1);", NULL, NULL, NULL) == SQLITE_OK;
  check("sqlite.rtree", ok, NULL);
  sqlite3_close(db);
}

/* ---------------------------------------------------------------- PCRE2 (with JIT, as Kodi's Windows build) */
static void test_pcre2(void)
{
  uint32_t jit = 0;
  pcre2_config(PCRE2_CONFIG_JIT, &jit);
  check("pcre2.jit_available", jit == 1, "PCRE2_CONFIG_JIT=%u", jit);
  int err = 0;
  PCRE2_SIZE erroff = 0;
  pcre2_code *re = pcre2_compile((PCRE2_SPTR) "(\\d+)-(\\d+)", PCRE2_ZERO_TERMINATED, 0, &err, &erroff, NULL);
  if (!re) {
    check("pcre2.compile", 0, "error %d", err);
    return;
  }
  int jr = pcre2_jit_compile(re, PCRE2_JIT_COMPLETE);
  check("pcre2.jit_compile", jr == 0, "rc=%d", jr);
  pcre2_match_data *md = pcre2_match_data_create_from_pattern(re, NULL);
  const char *subject = "track 12-345 of the album";
  int rc = pcre2_match(re, (PCRE2_SPTR)subject, strlen(subject), 0, 0, md, NULL);
  PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
  int ok = rc == 3 && ov[2] == 6 && ov[3] == 8 && ov[4] == 9 && ov[5] == 12;
  check("pcre2.match_jit", ok, "rc=%d groups=%.*s,%.*s", rc, rc == 3 ? (int)(ov[3] - ov[2]) : 0,
        rc == 3 ? subject + ov[2] : "", rc == 3 ? (int)(ov[5] - ov[4]) : 0, rc == 3 ? subject + ov[4] : "");
  rc = pcre2_match(re, (PCRE2_SPTR) "no digits here", 14, 0, 0, md, NULL);
  check("pcre2.nomatch", rc == PCRE2_ERROR_NOMATCH, "rc=%d", rc);
  pcre2_match_data_free(md);
  pcre2_code_free(re);
}

/* ---------------------------------------------------------------- OpenSSL */
static int hex_eq(const unsigned char *b, size_t n, const char *hex)
{
  char buf[129];
  for (size_t i = 0; i < n && i < 64; i++)
    sprintf(buf + 2 * i, "%02x", b[i]);
  return strcmp(buf, hex) == 0;
}

static X509 *self_signed(EVP_PKEY *k)
{
  X509 *x = X509_new();
  X509_set_version(x, 2);
  ASN1_INTEGER_set(X509_get_serialNumber(x), 1);
  X509_gmtime_adj(X509_getm_notBefore(x), -60);
  X509_gmtime_adj(X509_getm_notAfter(x), 3600);
  X509_set_pubkey(x, k);
  X509_NAME *n = X509_get_subject_name(x);
  X509_NAME_add_entry_by_txt(n, "CN", MBSTRING_ASC, (const unsigned char *)"kodi-rt", -1, -1, 0);
  X509_set_issuer_name(x, n);
  X509_sign(x, k, EVP_sha256());
  return x;
}

static void test_openssl(void)
{
  const char *ver = OpenSSL_version(OPENSSL_VERSION);
  check("openssl.version", strstr(ver, "3.5.7") != NULL, "%s", ver);

  unsigned char md[EVP_MAX_MD_SIZE];
  unsigned int mdlen = 0;
  EVP_Digest("abc", 3, md, &mdlen, EVP_sha256(), NULL);
  check("openssl.sha256", mdlen == 32 && hex_eq(md, 32, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        NULL);

  /* FIPS-197 appendix C.1: AES-128 */
  static const unsigned char key[16] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
  static const unsigned char pt[16] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                                       0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff};
  unsigned char ct[32];
  int l1 = 0, l2 = 0;
  EVP_CIPHER_CTX *cx = EVP_CIPHER_CTX_new();
  EVP_EncryptInit_ex(cx, EVP_aes_128_ecb(), NULL, key, NULL);
  EVP_CIPHER_CTX_set_padding(cx, 0);
  EVP_EncryptUpdate(cx, ct, &l1, pt, 16);
  EVP_EncryptFinal_ex(cx, ct + l1, &l2);
  EVP_CIPHER_CTX_free(cx);
  check("openssl.aes128", l1 + l2 == 16 && hex_eq(ct, 16, "69c4e0d86a7b0430d8cdb78070b4c55a"), NULL);

  /* RSA: generate, sign, verify */
  EVP_PKEY *rsa = EVP_PKEY_Q_keygen(NULL, NULL, "RSA", (size_t)1024);
  int sok = 0, vok = 0;
  if (rsa) {
    unsigned char sig[512];
    size_t siglen = sizeof sig;
    EVP_MD_CTX *m = EVP_MD_CTX_new();
    sok = EVP_DigestSignInit(m, NULL, EVP_sha256(), NULL, rsa) == 1 &&
          EVP_DigestSign(m, sig, &siglen, (const unsigned char *)text, sizeof text) == 1;
    EVP_MD_CTX_free(m);
    m = EVP_MD_CTX_new();
    vok = sok && EVP_DigestVerifyInit(m, NULL, EVP_sha256(), NULL, rsa) == 1 &&
          EVP_DigestVerify(m, sig, siglen, (const unsigned char *)text, sizeof text) == 1;
    EVP_MD_CTX_free(m);
  }
  check("openssl.rsa_sign_verify", rsa && sok && vok, NULL);
  EVP_PKEY_free(rsa);

  /* TLS: a full handshake between an in-process client and server over a BIO pair, then data both ways */
  EVP_PKEY *k = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "P-256");
  X509 *cert = k ? self_signed(k) : NULL;
  SSL_CTX *sctx = SSL_CTX_new(TLS_server_method()), *cctx = SSL_CTX_new(TLS_client_method());
  int setup = k && cert && sctx && cctx && SSL_CTX_use_certificate(sctx, cert) == 1 &&
              SSL_CTX_use_PrivateKey(sctx, k) == 1 &&
              X509_STORE_add_cert(SSL_CTX_get_cert_store(cctx), cert) == 1;
  int cdone = 0, sdone = 0, ok = 0;
  char got[16] = "";
  if (setup) {
    SSL *s = SSL_new(sctx), *c = SSL_new(cctx);
    BIO *sb = NULL, *cb = NULL;
    BIO_new_bio_pair(&sb, 0, &cb, 0);
    SSL_set_bio(s, sb, sb);
    SSL_set_bio(c, cb, cb);
    SSL_set_verify(c, SSL_VERIFY_PEER, NULL);
    SSL_set_accept_state(s);
    SSL_set_connect_state(c);
    for (int i = 0; i < 200 && !(cdone && sdone); i++) {
      if (!cdone) {
        int r = SSL_do_handshake(c);
        int e = r == 1 ? 0 : SSL_get_error(c, r);
        if (r == 1) cdone = 1;
        else if (e != SSL_ERROR_WANT_READ && e != SSL_ERROR_WANT_WRITE) break;
      }
      if (!sdone) {
        int r = SSL_do_handshake(s);
        int e = r == 1 ? 0 : SSL_get_error(s, r);
        if (r == 1) sdone = 1;
        else if (e != SSL_ERROR_WANT_READ && e != SSL_ERROR_WANT_WRITE) break;
      }
    }
    check("openssl.tls_handshake", cdone && sdone && SSL_get_verify_result(c) == X509_V_OK, "%s %s",
          cdone ? SSL_get_version(c) : "-", cdone ? SSL_get_cipher_name(c) : "-");
    check("openssl.tls13", cdone && SSL_version(c) == TLS1_3_VERSION, NULL);
    if (cdone && sdone && SSL_write(c, "ping", 4) == 4) {
      int n = SSL_read(s, got, sizeof got - 1);
      if (n == 4 && memcmp(got, "ping", 4) == 0 && SSL_write(s, "pong", 4) == 4) {
        n = SSL_read(c, got, sizeof got - 1);
        ok = n == 4 && memcmp(got, "pong", 4) == 0;
      }
    }
    check("openssl.tls_data", ok, NULL);
    SSL_free(c);
    SSL_free(s);
  } else {
    check("openssl.tls_setup", 0, "%s", ERR_error_string(ERR_get_error(), NULL));
  }
  SSL_CTX_free(sctx);
  SSL_CTX_free(cctx);
  X509_free(cert);
  EVP_PKEY_free(k);
}

/* ---------------------------------------------------------------- curl */
struct sink { char buf[512]; size_t len; };
static size_t on_data(char *p, size_t sz, size_t n, void *u)
{
  struct sink *s = (struct sink *)u;
  size_t len = sz * n;
  if (s->len + len < sizeof s->buf) {
    memcpy(s->buf + s->len, p, len);
    s->len += len;
  }
  return len;
}

static void test_curl(const char *dir)
{
  curl_global_init(CURL_GLOBAL_DEFAULT);
  curl_version_info_data *v = curl_version_info(CURLVERSION_NOW);
  check("curl.version", strcmp(v->version, "8.20.0") == 0, "%s %s", v->version, v->ssl_version ? v->ssl_version : "-");
  check("curl.openssl", v->ssl_version && strstr(v->ssl_version, "OpenSSL/3.5.7") != NULL, NULL);
  check("curl.features", (v->features & CURL_VERSION_SSL) && (v->features & CURL_VERSION_HTTP2) &&
                         (v->features & CURL_VERSION_LIBZ) && (v->features & CURL_VERSION_BROTLI) &&
                         (v->features & CURL_VERSION_ZSTD),
        "features=0x%x", (unsigned)v->features);
  char path[MAX_PATH], url[MAX_PATH + 16];
  snprintf(path, sizeof path, "%s\\curl-file-test.txt", dir);
  FILE *f = fopen(path, "wb");
  if (!f) {
    check("curl.file_url", 0, "cannot write %s", path);
    return;
  }
  fwrite(text, 1, sizeof text - 1, f);
  fclose(f);
  snprintf(url, sizeof url, "file:///%s", path);
  for (char *p = url; *p; p++)
    if (*p == '\\') *p = '/';
  struct sink s = {"", 0};
  CURL *h = curl_easy_init();
  curl_easy_setopt(h, CURLOPT_URL, url);
  curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, on_data);
  curl_easy_setopt(h, CURLOPT_WRITEDATA, &s);
  CURLcode rc = curl_easy_perform(h);
  curl_easy_cleanup(h);
  remove(path);
  check("curl.file_url", rc == CURLE_OK && s.len == sizeof text - 1 && memcmp(s.buf, text, s.len) == 0,
        "rc=%d bytes=%u", (int)rc, (unsigned)s.len);
  char *esc = curl_easy_escape(NULL, "a b&c", 0);
  check("curl.escape", esc && strcmp(esc, "a%20b%26c") == 0, "%s", esc ? esc : "-");
  curl_free(esc);
  curl_global_cleanup();
}

/* ---------------------------------------------------------------- FreeType + HarfBuzz */
static void test_fonts(const char *font)
{
  FT_Library lib;
  FT_Face face;
  if (FT_Init_FreeType(&lib) != 0) {
    check("freetype.init", 0, NULL);
    return;
  }
  FT_Int a, b, c;
  FT_Library_Version(lib, &a, &b, &c);
  check("freetype.version", a == 2 && b == 14 && c == 2, "%d.%d.%d", a, b, c);
  int err = FT_New_Face(lib, font, 0, &face);
  check("freetype.open_font", err == 0, "%s err=%d", font, err);
  if (err) {
    FT_Done_FreeType(lib);
    return;
  }
  FT_Set_Pixel_Sizes(face, 0, 32);
  check("harfbuzz.version", strcmp(hb_version_string(), "14.2.0") == 0, "%s", hb_version_string());
  hb_font_t *hf = hb_ft_font_create_referenced(face);
  hb_buffer_t *buf = hb_buffer_create();
  hb_buffer_add_utf8(buf, "Kodi", -1, 0, -1);
  hb_buffer_guess_segment_properties(buf);
  hb_shape(hf, buf, NULL, 0);
  unsigned int n = 0;
  hb_glyph_info_t *gi = hb_buffer_get_glyph_infos(buf, &n);
  hb_glyph_position_t *gp = hb_buffer_get_glyph_positions(buf, &n);
  int ids_ok = n == 4, adv = 0, pixels = 0, bitmaps_ok = 1;
  for (unsigned int i = 0; i < n; i++) {
    ids_ok = ids_ok && gi[i].codepoint != 0 && gp[i].x_advance > 0;
    adv += gp[i].x_advance;
    if (FT_Load_Glyph(face, gi[i].codepoint, FT_LOAD_RENDER) != 0) {
      bitmaps_ok = 0;
      continue;
    }
    FT_Bitmap *bm = &face->glyph->bitmap;
    int lit = 0;
    for (unsigned int y = 0; y < bm->rows; y++)
      for (unsigned int x = 0; x < bm->width; x++)
        lit += bm->buffer[y * bm->pitch + x] > 128;
    bitmaps_ok = bitmaps_ok && bm->rows > 0 && bm->width > 0 && lit > 0;
    pixels += lit;
  }
  check("harfbuzz.shape", ids_ok, "glyphs=%u advance=%d (26.6)", n, adv);
  check("freetype.render", n == 4 && bitmaps_ok, "lit pixels=%d", pixels);
  hb_buffer_destroy(buf);
  hb_font_destroy(hf);
  FT_Done_Face(face);
  FT_Done_FreeType(lib);
}

/* ---------------------------------------------------------------- FriBidi, iconv, libass */
static void test_fribidi(void)
{
  FriBidiChar logical[] = {'a', 'b', 'c', ' ', 0x05D0, 0x05D1, 0x05D2};
  FriBidiChar visual[8] = {0};
  FriBidiParType base = FRIBIDI_PAR_LTR;
  fribidi_log2vis(logical, 7, &base, visual, NULL, NULL, NULL);
  int ok = visual[0] == 'a' && visual[3] == ' ' && visual[4] == 0x05D2 && visual[5] == 0x05D1 && visual[6] == 0x05D0;
  check("fribidi.reorder", ok, "visual[4..6]=%04x %04x %04x", (unsigned)visual[4], (unsigned)visual[5],
        (unsigned)visual[6]);
}

static void test_iconv(void)
{
  iconv_t cd = iconv_open("ISO-8859-1", "UTF-8");
  char in[] = "caf\xc3\xa9", out[8] = {0};
  char *ip = in, *op = out;
  size_t il = 5, ol = sizeof out;
  size_t r = cd == (iconv_t)-1 ? (size_t)-1 : iconv(cd, &ip, &il, &op, &ol);
  check("iconv.utf8_to_latin1", r != (size_t)-1 && memcmp(out, "caf\xe9", 4) == 0, NULL);
  if (cd != (iconv_t)-1) iconv_close(cd);
  cd = iconv_open("UTF-16LE", "UTF-8");
  char out16[16] = {0};
  ip = in; il = 5; op = out16; ol = sizeof out16;
  r = cd == (iconv_t)-1 ? (size_t)-1 : iconv(cd, &ip, &il, &op, &ol);
  check("iconv.utf8_to_utf16le", r != (size_t)-1 && sizeof out16 - ol == 8 && (unsigned char)out16[6] == 0xE9 &&
                                 out16[7] == 0, NULL);
  if (cd != (iconv_t)-1) iconv_close(cd);
}

static void test_libass(const char *font)
{
  static const char script[] =
      "[Script Info]\nScriptType: v4.00+\nPlayResX: 384\nPlayResY: 288\n\n"
      "[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
      "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, "
      "MarginL, MarginR, MarginV, Encoding\n"
      "Style: Default,Noto Sans,24,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,"
      "10,1\n\n"
      "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
      "Dialogue: 0,0:00:00.00,0:00:05.00,Default,,0,0,0,,Kodi on Windows RT\n";
  ASS_Library *lib = ass_library_init();
  if (!lib) {
    check("libass.init", 0, NULL);
    return;
  }
  /* Kodi's call order (DVDSubtitlesLibass.cpp:172, then :223): ass_set_fonts_dir before ass_set_fonts. Kodi's
   * Windows patch 02 makes the DirectWrite provider load fonts from lib->fonts_dir and strlen() it unchecked, so
   * without this call it crashes (run 1 on the device: strlen(NULL) in ass_directwrite_add_provider). */
  char fontdir[MAX_PATH];
  snprintf(fontdir, sizeof fontdir, "%s", font);
  char *bs = strrchr(fontdir, '\\');
  if (bs) *bs = 0;
  ass_set_fonts_dir(lib, fontdir);
  ASS_Renderer *r = ass_renderer_init(lib);
  if (!r) {
    check("libass.init", 0, NULL);
    ass_library_done(lib);
    return;
  }
  ass_set_frame_size(r, 640, 360);
  /* the default font is Kodi's NotoSans; the font provider is autodetected (DirectWrite on Windows, as in Kodi) */
  ass_set_fonts(r, font, "Noto Sans", ASS_FONTPROVIDER_AUTODETECT, NULL, 1);
  ASS_Track *t = ass_read_memory(lib, (char *)script, sizeof script - 1, NULL);
  check("libass.parse", t && t->n_events == 1, "events=%d", t ? t->n_events : -1);
  int changed = 0, images = 0;
  long area = 0;
  for (ASS_Image *im = t ? ass_render_frame(r, t, 1000, &changed) : NULL; im; im = im->next) {
    images++;
    area += (long)im->w * im->h;
  }
  check("libass.render", images > 0 && area > 0, "images=%d area=%ld", images, area);
  if (t) ass_free_track(t);
  ass_renderer_done(r);
  ass_library_done(lib);
}

/* ---------------------------------------------------------------- lzo, zstd, brotli, fstrcmp, nghttp2, dvdnav */
static void test_small(const char *exe_dir)
{
  unsigned char packed[512], unpacked[256];
  static unsigned char wrk[LZO1X_1_MEM_COMPRESS];
  lzo_uint plen = sizeof packed, ulen = sizeof unpacked;
  int ok = lzo_init() == LZO_E_OK &&
           lzo1x_1_compress((const unsigned char *)text, sizeof text, packed, &plen, wrk) == LZO_E_OK &&
           lzo1x_decompress_safe(packed, plen, unpacked, &ulen, NULL) == LZO_E_OK && ulen == sizeof text &&
           memcmp(unpacked, text, ulen) == 0;
  check("lzo2.roundtrip", ok, "%s", lzo_version_string());

  size_t zl = ZSTD_compress(packed, sizeof packed, text, sizeof text, 3);
  size_t zu = ZSTD_isError(zl) ? 0 : ZSTD_decompress(unpacked, sizeof unpacked, packed, zl);
  check("zstd.roundtrip", !ZSTD_isError(zl) && zu == sizeof text && memcmp(unpacked, text, zu) == 0, "%s",
        ZSTD_versionString());

  size_t bl = sizeof packed, bu = sizeof unpacked;
  ok = BrotliEncoderCompress(BROTLI_DEFAULT_QUALITY, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC, sizeof text,
                             (const uint8_t *)text, &bl, packed) &&
       BrotliDecoderDecompress(bl, packed, &bu, unpacked) == BROTLI_DECODER_RESULT_SUCCESS && bu == sizeof text &&
       memcmp(unpacked, text, bu) == 0;
  check("brotli.roundtrip", ok, NULL);

  /* (not "near": windows.h defines near and far as empty macros) */
  double same = fstrcmp("Kodi", "Kodi"), similar = fstrcmp("Kodi", "Kody");
  check("fstrcmp.similarity", same == 1.0 && similar > 0.5 && similar < 1.0, "%.3f %.3f", same, similar);

  curl_version_info_data *cv = curl_version_info(CURLVERSION_NOW);
  check("nghttp2.version", cv->nghttp2_version && strcmp(cv->nghttp2_version, "1.69.0") == 0, "%s",
        cv->nghttp2_version ? cv->nghttp2_version : "-");

  /* libdvdnav is a DLL that Kodi loads at run time (DllPaths_win32.h: dvdnav.dll next to kodi.exe) */
  char dll[MAX_PATH];
  snprintf(dll, sizeof dll, "%s\\dvdnav.dll", exe_dir);
  HMODULE h = LoadLibraryA(dll);
  typedef const char *(*version_fn)(void);
  version_fn vf = h ? (version_fn)GetProcAddress(h, "dvdnav_version") : NULL;
  const char *dv = vf ? vf() : NULL;
  check("dvdnav.dll_load", h && vf && dv, "%s (LoadLibrary error %lu)", dv ? dv : "-", h ? 0UL : GetLastError());
  if (h) FreeLibrary(h);
}

int main(int argc, char **argv)
{
  if (argc < 3) {
    fprintf(stderr, "usage: s3test-c <font file> <writable folder>\n");
    return 100;
  }
  char exe_dir[MAX_PATH];
  GetModuleFileNameA(NULL, exe_dir, MAX_PATH);
  char *slash = strrchr(exe_dir, '\\');
  if (slash) *slash = 0;
  printf("kodi-rt stage 3 C library test\n");
  test_zlib();
  test_sqlite();
  test_pcre2();
  test_openssl();
  test_curl(argv[2]);
  test_fonts(argv[1]);
  test_fribidi();
  test_iconv();
  test_libass(argv[1]);
  test_small(exe_dir);
  if (g_failed == 0)
    printf("ALL PASSED (%d checks)\n", g_checks);
  else
    printf("FAILED (%d of %d checks)\n", g_failed, g_checks);
  return g_failed;
}
