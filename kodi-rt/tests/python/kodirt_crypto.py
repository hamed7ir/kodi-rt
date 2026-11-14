# kodi-rt: test of Kodi's script.module.pycryptodome (Cryptodome package + its C modules loaded with ctypes).
# Prints "CRYPTO PASS <name>" / "CRYPTO FAIL <name>: <error>" per check, then "CRYPTO ALL PASS (<n> checks)" or
# "CRYPTO FAILED (...)". Exit code 0 only when everything passed. Offline.
# Usage: python kodirt_crypto.py <add-on lib folder, e.g. ...\script.module.pycryptodome\lib> [--selftest]
#   --selftest  also runs pycryptodome's own SelfTest suite (slow tests skipped; takes minutes on the Surface RT)
import os, sys, time, traceback

LIB = os.path.abspath(sys.argv[1])
sys.path.insert(0, LIB)
results, CHECKS = [], []

def check(name):
    def wrap(fn):
        CHECKS.append((name, fn)); return fn
    return wrap

@check('import')
def _():
    import Cryptodome
    assert Cryptodome.__version__ == '3.23.0', Cryptodome.__version__
    assert os.path.dirname(Cryptodome.__file__).startswith(LIB), Cryptodome.__file__
    from Cryptodome.Util import _raw_api
    print('   Cryptodome', Cryptodome.__version__, 'backend', _raw_api.backend)

@check('aes-kat')
def _():
    from Cryptodome.Cipher import AES
    # FIPS-197 appendix C.1 (AES-128)
    key = bytes(range(16)); pt = bytes.fromhex('00112233445566778899aabbccddeeff')
    ct = AES.new(key, AES.MODE_ECB).encrypt(pt)
    assert ct.hex() == '69c4e0d86a7b0430d8cdb78070b4c55a', ct.hex()
    assert AES.new(key, AES.MODE_ECB).decrypt(ct) == pt
    # FIPS-197 C.3 (AES-256)
    key = bytes(range(32))
    assert AES.new(key, AES.MODE_ECB).encrypt(pt).hex() == '8ea2b7ca516745bfeafc49904b496089'

@check('aes-modes')
def _():
    from Cryptodome.Cipher import AES
    from Cryptodome.Random import get_random_bytes
    from Cryptodome.Util.Padding import pad, unpad
    key, data = get_random_bytes(16), get_random_bytes(1000) + b'kodi-rt'
    iv = get_random_bytes(16)
    ct = AES.new(key, AES.MODE_CBC, iv).encrypt(pad(data, 16))
    assert unpad(AES.new(key, AES.MODE_CBC, iv).decrypt(ct), 16) == data
    nonce = get_random_bytes(8)
    ct = AES.new(key, AES.MODE_CTR, nonce=nonce).encrypt(data)
    assert AES.new(key, AES.MODE_CTR, nonce=nonce).decrypt(ct) == data
    c = AES.new(key, AES.MODE_GCM); ct, tag = c.encrypt_and_digest(data)
    d = AES.new(key, AES.MODE_GCM, nonce=c.nonce)
    assert d.decrypt_and_verify(ct, tag) == data
    for mode in (AES.MODE_CFB, AES.MODE_OFB):
        assert AES.new(key, mode, iv).decrypt(AES.new(key, mode, iv).encrypt(data)) == data
    print('   AES-NI module loaded:', 'yes' if getattr(AES, '_raw_aesni_lib', None) else 'no')

@check('hashes')
def _():
    import hashlib
    from Cryptodome.Hash import SHA256, SHA1, MD5, SHA512, SHA3_256, BLAKE2b, HMAC
    assert SHA256.new(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    blob = os.urandom(100000)
    for ours, ref in ((SHA256, 'sha256'), (SHA1, 'sha1'), (MD5, 'md5'), (SHA512, 'sha512'), (SHA3_256, 'sha3_256')):
        assert ours.new(blob).hexdigest() == hashlib.new(ref, blob).hexdigest(), ref
    assert BLAKE2b.new(digest_bits=512, data=blob).hexdigest() == hashlib.blake2b(blob).hexdigest()
    import hmac
    assert HMAC.new(b'k', blob, SHA256).hexdigest() == hmac.new(b'k', blob, 'sha256').hexdigest()

@check('stream-ciphers')
def _():
    from Cryptodome.Cipher import ChaCha20, ChaCha20_Poly1305, Salsa20, DES3, ARC4
    key = bytes(range(32)); data = b'x' * 777
    c = ChaCha20.new(key=key, nonce=bytes(12)); ct = c.encrypt(data)
    assert ChaCha20.new(key=key, nonce=bytes(12)).decrypt(ct) == data
    c = ChaCha20_Poly1305.new(key=key); ct, tag = c.encrypt_and_digest(data)
    assert ChaCha20_Poly1305.new(key=key, nonce=c.nonce).decrypt_and_verify(ct, tag) == data
    assert Salsa20.new(key=key, nonce=bytes(8)).decrypt(Salsa20.new(key=key, nonce=bytes(8)).encrypt(data)) == data
    k3 = DES3.adjust_key_parity(bytes(range(1, 25)))
    assert DES3.new(k3, DES3.MODE_ECB).decrypt(DES3.new(k3, DES3.MODE_ECB).encrypt(b'8bytes!!')) == b'8bytes!!'
    assert ARC4.new(b'key').decrypt(ARC4.new(b'key').encrypt(data)) == data

@check('kdf')
def _():
    import hashlib
    from Cryptodome.Protocol.KDF import PBKDF2, scrypt
    from Cryptodome.Hash import SHA256
    assert PBKDF2(b'pw', b'salt', 32, count=1000, hmac_hash_module=SHA256) == hashlib.pbkdf2_hmac('sha256', b'pw', b'salt', 1000, 32)
    assert scrypt(b'pw', b'salt', 32, N=2**10, r=8, p=1) == hashlib.scrypt(b'pw', salt=b'salt', n=2**10, r=8, p=1, dklen=32)

@check('public-key')
def _():
    from Cryptodome.PublicKey import ECC, RSA
    from Cryptodome.Signature import DSS, eddsa, pkcs1_15
    from Cryptodome.Cipher import PKCS1_OAEP
    from Cryptodome.Hash import SHA256
    h = SHA256.new(b'kodi-rt')
    k = ECC.generate(curve='P-256')
    sig = DSS.new(k, 'fips-186-3').sign(h); DSS.new(k.public_key(), 'fips-186-3').verify(h, sig)
    e = ECC.generate(curve='ed25519')
    s = eddsa.new(e, 'rfc8032').sign(b'kodi-rt'); eddsa.new(e.public_key(), 'rfc8032').verify(b'kodi-rt', s)
    t = time.time()
    r = RSA.generate(1024)
    gen = time.time() - t
    ct = PKCS1_OAEP.new(r.public_key()).encrypt(b'secret')
    assert PKCS1_OAEP.new(r).decrypt(ct) == b'secret'
    pkcs1_15.new(r.public_key()).verify(h, pkcs1_15.new(r).sign(h))
    from Cryptodome.Math import Numbers
    print(f'   RSA-1024 keygen {gen:.1f} s; Math implementation {Numbers._implementation}')

@check('all-modules-load')
def _():
    # every C module in one process (each is a /MT DLL with its own C runtime), then the FLS slots left
    import ctypes
    from ctypes import wintypes
    pyds = sorted(os.path.join(r, f) for r, _, fs in os.walk(os.path.join(LIB, 'Cryptodome')) for f in fs if f.endswith('.pyd'))
    handles = [ctypes.CDLL(p) for p in pyds]
    k32 = ctypes.WinDLL('kernel32', use_last_error=True)
    k32.FlsAlloc.restype, k32.FlsAlloc.argtypes = wintypes.DWORD, [ctypes.c_void_p]
    k32.FlsFree.restype, k32.FlsFree.argtypes = wintypes.BOOL, [wintypes.DWORD]
    got = []
    while len(got) < 5000:
        i = k32.FlsAlloc(None)
        if i == 0xFFFFFFFF:
            break
        got.append(i)
    for i in got:
        k32.FlsFree(i)
    print(f'   {len(handles)} C modules loaded; FLS slots still free after that: {len(got)}')
    assert len(handles) in (40, 42), len(handles)
    assert len(got) >= 16, f'only {len(got)} FLS slots left'

@check('selftest')
def _():
    if '--selftest' not in sys.argv:
        print('   skipped (pass --selftest)'); return
    import io, unittest
    from Cryptodome import SelfTest
    out = io.StringIO()
    t = time.time()
    try:
        SelfTest.run(stream=out, verbosity=1, config={'slow_tests': False})
    except SelfTest.SelfTestError as e:
        print(out.getvalue()[-3000:]); raise
    tail = [l for l in out.getvalue().splitlines() if l.startswith(('Ran ', 'OK', 'FAILED'))]
    print(f'   SelfTest {time.time() - t:.0f} s:', ' / '.join(tail))

def main():
    print('python', sys.version.split()[0], sys.platform, 'pointer bits', 8 * __import__('struct').calcsize('P'), flush=True)
    for name, fn in CHECKS:
        try:
            fn(); results.append((name, None)); print(f'CRYPTO PASS {name}', flush=True)
        except Exception as e:
            results.append((name, e)); print(f'CRYPTO FAIL {name}: {type(e).__name__}: {e}', flush=True)
            traceback.print_exc()
    bad = [r[0] for r in results if r[1] is not None]
    print(f'CRYPTO ALL PASS ({len(results)} checks)' if not bad else f'CRYPTO FAILED ({len(bad)} of {len(results)}): {bad}', flush=True)
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
