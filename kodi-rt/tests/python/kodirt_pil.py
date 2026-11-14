# kodi-rt: test of Kodi's script.module.pil (Pillow 12.0.0 with libjpeg-turbo, zlib, FreeType, raqm/HarfBuzz/FriBidi).
# Prints "PIL PASS <name>" / "PIL FAIL <name>: <error>" per check, then "PIL ALL PASS (<n> checks)" or "PIL FAILED (...)".
# Exit code 0 only when everything passed. Offline.
# Known answers: the JPEG bytes Pillow writes and the pixels it decodes are the same on every architecture (libjpeg-turbo's
# SIMD code - SSE2/AVX2 on x86/x64, Neon on ARM32 - gives the same results as its C code), and FreeType/raqm render
# with integer arithmetic; their sha256 were taken on x64 (--print-hashes) and must match on x86 and the Surface RT.
# Usage: python kodirt_pil.py <add-on lib folder, e.g. ...\script.module.pil\lib> <assets folder> [--print-hashes]
import hashlib, io, os, sys, traceback

LIB, ASSETS = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
PRINT = '--print-hashes' in sys.argv
sys.path.insert(0, LIB)
results, CHECKS, HASHES = [], [], {}

EXPECTED = {
    # taken on x64 (prefix/x64, 2026-11-14) with --print-hashes
    'jpeg-encode-q90': 'e744f7f8bb288ace6172b0e886bcc7e2e831d5100a58ba45ea6138c712372755',
    'jpeg-encode-q75-444': 'c6d4c6c18b7b1e73f65349db9766fbf237624e95fa7b47df2bef14d957e5571a',
    'jpeg-encode-q85-progressive-optimize': '2b27ebb3a9ede4c33de20eb1a409ea878db453da0ee024dc0d6fd55caf4640ce',
    'jpeg-decode-hopper': '719b9eeda0a26779271f4c33a329c8488f821149a67b9955f873a49995294c3a',
    'jpeg-decode-hopper-draft': '8254b29bc5d425d3a19c5f463efdbfa2bed56dd8501479e0a605ea434e303d8e',
    'jpeg-decode-pattern': '515b4db2d5b60971c3ee3d3d7fb34896403efc5918ce6559a44434ac1bb64d70',
    'draw-text-basic': '876354671cdbddadf4fde05dc7504ac4414b59474f7f4790c329fa069ba59362',
    'draw-text-raqm': 'a373f426395d576f830f4ed20aadf4cdb20f3516ac69667dd3ad9423efcefa5f',
    'draw-text-arabic-raqm': '51ad4f5e5668fa388d7172980603e33ef4582cd5e6d49680f9aef6b480cdef51',
}

def check(name):
    def wrap(fn):
        CHECKS.append((name, fn)); return fn
    return wrap

def kat(key, data):
    h = hashlib.sha256(data).hexdigest()
    HASHES[key] = h
    if not PRINT:
        want = EXPECTED.get(key)
        assert want is not None, f'no expected hash for {key}'
        assert h == want, f'{key}: {h} != expected {want}'
    return h

def pattern(w=256, h=192):
    # a deterministic test picture: gradients, sharp edges and a texture (no random numbers, no floats)
    from PIL import Image
    im = Image.new('RGB', (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            r = (x * 255) // (w - 1)
            g = (y * 255) // (h - 1)
            b = ((x ^ y) * 37 + ((x // 16 + y // 16) % 2) * 90) & 255
            px[x, y] = (r, g, b)
    return im

@check('import-features')
def _():
    import PIL
    from PIL import features
    assert PIL.__version__ == '12.0.0', PIL.__version__
    assert os.path.dirname(PIL.__file__).startswith(LIB), PIL.__file__
    want = ('jpg', 'zlib', 'freetype2', 'raqm', 'fribidi', 'harfbuzz', 'libjpeg_turbo')
    missing = [f for f in want if not features.check(f)]
    assert not missing, f'features missing: {missing}'
    print('   Pillow', PIL.__version__, '|', ', '.join(f'{f} {features.version(f)}' for f in want))

@check('jpeg-encode-kat')
def _():
    im = pattern()
    for name, kw in (('q90', dict(quality=90)), ('q75-444', dict(quality=75, subsampling=0)),
                     ('q85-progressive-optimize', dict(quality=85, progressive=True, optimize=True))):
        b = io.BytesIO(); im.save(b, 'JPEG', **kw)
        kat(f'jpeg-encode-{name}', b.getvalue())

@check('jpeg-decode-kat')
def _():
    from PIL import Image
    with Image.open(os.path.join(ASSETS, 'hopper.jpg')) as im:
        im.load()
        assert im.size == (128, 128) and im.mode == 'RGB', (im.size, im.mode)
        kat('jpeg-decode-hopper', im.tobytes())
    with Image.open(os.path.join(ASSETS, 'hopper.jpg')) as im:
        im.draft('RGB', (64, 64)); im.load()           # libjpeg's scaled (reduced) IDCT
        assert im.size == (64, 64), im.size
        kat('jpeg-decode-hopper-draft', im.tobytes())
    b = io.BytesIO(); pattern().save(b, 'JPEG', quality=90); b.seek(0)
    with Image.open(b) as im:
        im.load(); kat('jpeg-decode-pattern', im.tobytes())

@check('lossless-formats')
def _():
    from PIL import Image
    src = pattern()
    with Image.open(os.path.join(ASSETS, 'hopper.png')) as h:
        h.load(); hop = h.convert('RGB')
    for fmt, im, kw in (('PNG', src, dict(optimize=True)), ('PNG', hop, {}), ('BMP', src, {}), ('TIFF', src, {}),
                        ('PPM', src, {}), ('TGA', src, {}), ('WEBP?', None, None)):
        if im is None:
            continue
        b = io.BytesIO(); im.save(b, fmt, **kw); b.seek(0)
        with Image.open(b) as back:
            back.load()
            assert back.convert('RGB').tobytes() == im.tobytes(), fmt
    gif = src.convert('P', palette=Image.ADAPTIVE, colors=64)
    b = io.BytesIO(); gif.save(b, 'GIF'); b.seek(0)
    with Image.open(b) as back:
        back.load(); assert back.convert('RGB').tobytes() == gif.convert('RGB').tobytes()

@check('transforms')
def _():
    from PIL import Image, ImageFilter, ImageOps, ImageChops, ImageStat, ImageEnhance
    im = pattern()
    out = [im.resize((100, 75), Image.Resampling.LANCZOS), im.resize((512, 384), Image.Resampling.BICUBIC),
           im.reduce(4), im.rotate(30, expand=True), im.transpose(Image.Transpose.ROTATE_90),
           im.filter(ImageFilter.GaussianBlur(3)), im.filter(ImageFilter.FIND_EDGES), im.convert('L'),
           im.convert('CMYK'), ImageOps.autocontrast(im, cutoff=2), ImageOps.equalize(im),
           ImageEnhance.Sharpness(im).enhance(2.0), im.quantize(colors=32)]
    for o in out:
        assert o.size[0] > 0 and o.tobytes()
    d = ImageChops.difference(im, im.transpose(Image.Transpose.FLIP_LEFT_RIGHT))
    st = ImageStat.Stat(d)
    assert len(st.mean) == 3 and max(st.extrema[0]) == 255
    im.thumbnail((64, 64)); assert im.size == (64, 48), im.size

@check('draw-text-kat')
def _():
    from PIL import Image, ImageDraw, ImageFont
    noto = os.path.join(ASSETS, 'NotoSans-Regular.ttf')
    for eng, name in ((ImageFont.Layout.BASIC, 'basic'), (ImageFont.Layout.RAQM, 'raqm')):
        f = ImageFont.truetype(noto, 28, layout_engine=eng)
        im = Image.new('RGB', (420, 120), 'white'); d = ImageDraw.Draw(im)
        d.text((10, 10), 'Kodi RT: Pillow 12 on the Surface', font=f, fill=(20, 20, 160))
        d.rectangle((10, 60, 410, 110), outline='black', width=2)
        d.line((10, 60, 410, 110), fill='red', width=3)
        d.polygon([(220, 65), (260, 105), (180, 105)], fill=(0, 140, 0))
        kat(f'draw-text-{name}', im.tobytes())
    # Arabic needs shaping: with raqm the letters join, so the run is narrower than the unjoined BASIC layout
    aref = os.path.join(ASSETS, 'ArefRuqaa-Regular.ttf')
    text = 'كودي على سطح'
    w_raqm = ImageFont.truetype(aref, 40, layout_engine=ImageFont.Layout.RAQM).getlength(text)
    w_basic = ImageFont.truetype(aref, 40, layout_engine=ImageFont.Layout.BASIC).getlength(text)
    assert w_raqm != w_basic, (w_raqm, w_basic)
    im = Image.new('L', (400, 90), 0)
    ImageDraw.Draw(im).text((390, 10), text, font=ImageFont.truetype(aref, 40, layout_engine=ImageFont.Layout.RAQM),
                            fill=255, anchor='ra', direction='rtl')
    kat('draw-text-arabic-raqm', im.tobytes())
    print(f'   Arabic run width: raqm {w_raqm:.0f} px, basic {w_basic:.0f} px')

@check('modules')
def _():
    import importlib
    for m in ('PIL._imaging', 'PIL._imagingft', 'PIL._imagingmath', 'PIL._imagingmorph'):
        mod = importlib.import_module(m)
        assert mod.__file__.endswith('.pyd'), mod.__file__
    from PIL import ImageMath, ImageMorph, Image
    im = Image.new('L', (8, 8), 100)
    assert ImageMath.lambda_eval(lambda a: a['x'] * 2, x=im).getpixel((0, 0)) == 200
    sq = Image.new('L', (12, 12), 0); sq.paste(255, (3, 3, 9, 9))      # a white square: erosion removes its rim
    changed, eroded = ImageMorph.MorphOp(op_name='erosion4').apply(sq)
    assert changed == 20 and eroded.getpixel((5, 5)) == 255 and eroded.getpixel((3, 3)) == 0, changed

def main():
    print('python', sys.version.split()[0], sys.platform, 'pointer bits', 8 * __import__('struct').calcsize('P'), flush=True)
    for name, fn in CHECKS:
        try:
            fn(); results.append((name, None)); print(f'PIL PASS {name}', flush=True)
        except Exception as e:
            results.append((name, e)); print(f'PIL FAIL {name}: {type(e).__name__}: {e}', flush=True)
            traceback.print_exc()
    if PRINT:
        print('EXPECTED = {'); [print(f"    '{k}': '{v}',") for k, v in HASHES.items()]; print('}')
    bad = [r[0] for r in results if r[1] is not None]
    print(f'PIL ALL PASS ({len(results)} checks)' if not bad else f'PIL FAILED ({len(bad)} of {len(results)}): {bad}', flush=True)
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
