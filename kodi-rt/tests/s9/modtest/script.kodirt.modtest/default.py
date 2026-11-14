# kodi-rt: checks that ctypes, pycryptodome (Cryptodome) and Pillow (PIL) load and work inside Kodi's own Python,
# imported the way add-ons get them (this add-on requires script.module.pycryptodome and script.module.pil, so Kodi
# puts their lib folders on sys.path). Results: special://home/modtest-result.json and "kodi-rt modtest:" lines in
# kodi.log. Used by tests/s9/addon-modules-test.ps1 (x64/x86 on the server); works the same on the tablet.
import hashlib
import io
import json
import os
import sys
import time
import traceback

import xbmc
import xbmcvfs

res = {'python': sys.version, 'machine': '', 'tests': {}}


def log(msg):
    xbmc.log('kodi-rt modtest: ' + msg, xbmc.LOGINFO)


def test(name, fn):
    t = time.time()
    try:
        out = fn()
        res['tests'][name] = {'ok': True, 'out': out, 'ms': int((time.time() - t) * 1000)}
    except Exception:
        res['tests'][name] = {'ok': False, 'err': traceback.format_exc()[-2000:]}
    r = res['tests'][name]
    log('%s %s %s' % (name, 'OK' if r['ok'] else 'FAIL', json.dumps(r.get('out', r.get('err')))[:400]))


def t_ctypes():
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.WinDLL('kernel32')
    k32.GetTickCount64.restype = ctypes.c_ulonglong
    assert k32.GetTickCount64() > 0
    assert k32.GetCurrentProcessId() == os.getpid()

    class SYSTEM_INFO(ctypes.Structure):
        _fields_ = [('wProcessorArchitecture', wintypes.WORD), ('wReserved', wintypes.WORD),
                    ('dwPageSize', wintypes.DWORD), ('lpMinimumApplicationAddress', ctypes.c_void_p),
                    ('lpMaximumApplicationAddress', ctypes.c_void_p), ('dwActiveProcessorMask', ctypes.c_size_t),
                    ('dwNumberOfProcessors', wintypes.DWORD), ('dwProcessorType', wintypes.DWORD),
                    ('dwAllocationGranularity', wintypes.DWORD), ('wProcessorLevel', wintypes.WORD),
                    ('wProcessorRevision', wintypes.WORD)]
    si = SYSTEM_INFO()
    k32.GetNativeSystemInfo(ctypes.byref(si))
    arch = {0: 'x86', 5: 'arm', 9: 'x64', 12: 'arm64'}.get(si.wProcessorArchitecture, str(si.wProcessorArchitecture))
    res['machine'] = arch
    crt = ctypes.CDLL('msvcrt')
    crt.pow.restype = ctypes.c_double
    crt.pow.argtypes = [ctypes.c_double, ctypes.c_double]
    assert crt.pow(2.0, 10.0) == 1024.0
    cmp_t = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int))
    arr = (ctypes.c_int * 6)(5, 3, 9, 1, 7, 2)
    crt.qsort(arr, len(arr), ctypes.sizeof(ctypes.c_int), cmp_t(lambda a, b: a[0] - b[0]))
    assert list(arr) == [1, 2, 3, 5, 7, 9]
    assert ctypes.pythonapi.Py_IsInitialized() == 1
    return {'native_arch': arch, 'cpus': si.dwNumberOfProcessors, 'page': si.dwPageSize}


def t_crypto():
    import Cryptodome
    from Cryptodome.Cipher import AES, ChaCha20
    from Cryptodome.Hash import SHA256, HMAC
    from Cryptodome.Protocol.KDF import PBKDF2
    from Cryptodome.Random import get_random_bytes
    key = bytes(range(16))
    # FIPS-197 appendix C.1
    ct = AES.new(key, AES.MODE_ECB).encrypt(bytes.fromhex('00112233445566778899aabbccddeeff'))
    assert ct.hex() == '69c4e0d86a7b0430d8cdb78070b4c55a', ct.hex()
    nonce = get_random_bytes(12)
    c = AES.new(key, AES.MODE_GCM, nonce=nonce)
    data, tag = c.encrypt_and_digest(b'kodi-rt on a surface rt')
    assert AES.new(key, AES.MODE_GCM, nonce=nonce).decrypt_and_verify(data, tag) == b'kodi-rt on a surface rt'
    k32 = bytes(range(32))
    n8 = bytes(8)
    assert ChaCha20.new(key=k32, nonce=n8).decrypt(ChaCha20.new(key=k32, nonce=n8).encrypt(b'x' * 100)) == b'x' * 100
    assert SHA256.new(b'abc').hexdigest() == hashlib.sha256(b'abc').hexdigest()
    pb = PBKDF2(b'kodi-rt', b'salt', dkLen=32, count=1000, hmac_hash_module=SHA256)
    assert pb == hashlib.pbkdf2_hmac('sha256', b'kodi-rt', b'salt', 1000, 32)
    assert len(HMAC.new(key, b'msg', digestmod=SHA256).digest()) == 32
    return {'version': Cryptodome.__version__, 'from': os.path.dirname(Cryptodome.__file__)}


def t_pil():
    import PIL
    from PIL import Image, ImageDraw, ImageFont, features
    feats = {f: features.check(f) for f in ('jpg', 'zlib', 'freetype2', 'raqm')}
    assert feats['jpg'] and feats['zlib'] and feats['freetype2'], feats
    im = Image.new('RGB', (96, 48), (90, 30, 140))
    d = ImageDraw.Draw(im)
    d.rectangle((4, 4, 40, 40), fill=(199, 107, 255))
    d.text((46, 14), 'rt', fill=(255, 255, 255), font=ImageFont.load_default(size=18))
    for fmt in ('JPEG', 'PNG'):
        b = io.BytesIO()
        im.save(b, fmt)
        b.seek(0)
        back = Image.open(b)
        back.load()
        assert back.size == (96, 48) and back.mode == 'RGB', (fmt, back.size, back.mode)
    return {'version': PIL.__version__, 'features': feats, 'libjpeg': features.version('jpg'),
            'freetype': features.version('freetype2'), 'from': os.path.dirname(PIL.__file__)}


log('start, ' + sys.version.split()[0])
test('ctypes', t_ctypes)
test('pycryptodome', t_crypto)
test('pillow', t_pil)
res['all_ok'] = all(t['ok'] for t in res['tests'].values())
out = xbmcvfs.translatePath('special://home/modtest-result.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(res, f, indent=1)
log('done, all ok: %s, results in %s' % (res['all_ok'], out))
