# kodi-rt Python stage: smoke test of the interpreter and of every module compiled into python314.dll.
# Prints one line per check, "SMOKE PASS <name>" or "SMOKE FAIL <name>: <error>", then "SMOKE ALL PASS (<n> checks)"
# or "SMOKE FAILED (<k> of <n>)". Exit code 0 only when everything passed. Runs offline.
# --require-all: _ssl, _hashlib, _sqlite3 and _zstd must be compiled in too (the Surface RT build); without it they
# are optional (the x64 reference build has no OpenSSL or zstd).
import sys, traceback

results = []
CHECKS = []
REQUIRE_ALL = '--require-all' in sys.argv

def check(name):
    def wrap(fn):
        CHECKS.append((name, fn))
        return fn
    return wrap

@check('builtin-modules')
def _():
    want = ['_socket', 'select', 'pyexpat', '_elementtree', '_bz2', '_lzma', 'unicodedata', '_decimal',
            '_multiprocessing', '_overlapped', '_asyncio', '_queue', '_uuid', '_zoneinfo', 'winsound', 'zlib']
    optional = ['_ssl', '_hashlib', '_sqlite3', '_zstd', '_ctypes']
    if REQUIRE_ALL:
        want += optional[:-1]
    missing = [m for m in want if m not in sys.builtin_module_names]
    assert not missing, f'not compiled in: {missing}'
    print('   optional present:', [m for m in optional if m in sys.builtin_module_names])

@check('arith')
def _():
    assert 2 ** 100 == 1267650600228229401496703205376
    assert (10 ** 50 + 7) % 97 == (pow(10, 50, 97) + 7) % 97 == 4
    assert int('123456789' * 5) * 3 == int('370370367' * 5)
    assert abs(sum(i * 0.1 for i in range(10)) - 4.5) < 1e-9
    import math
    assert math.isclose(math.sqrt(2) ** 2, 2.0) and math.factorial(30) == 265252859812191058636308480000000
    assert float('1e308') * 10 == float('inf') and repr(0.1) == '0.1'

@check('strings-unicode')
def _():
    import unicodedata
    s = 'Kodi عربی 日本 \U0001F600'
    assert s.encode('utf-8').decode('utf-8') == s
    assert unicodedata.name('ع') == 'ARABIC LETTER AIN'
    assert unicodedata.normalize('NFC', 'é') == 'é'
    assert 'straße'.upper() == 'STRASSE' and f'{3.14159:.2f}' == '3.14'

@check('re-json-struct')
def _():
    import re, json, struct
    assert re.findall(r'\d+', 'a1b22c333') == ['1', '22', '333']
    d = {'a': [1, 2.5, None, True], 'b': 'é'}
    assert json.loads(json.dumps(d)) == d
    assert struct.unpack('<IqdH', struct.pack('<IqdH', 1, -2, 3.5, 4)) == (1, -2, 3.5, 4)

@check('decimal')
def _():
    import decimal, _decimal
    assert decimal.Decimal is _decimal.Decimal   # the C version, not the _pydecimal fallback
    with decimal.localcontext() as c:
        c.prec = 50
        x = decimal.Decimal(2).sqrt()
    assert str(x).startswith('1.4142135623730950488016887242096980785696718753769')

@check('compression')
def _():
    import zlib, bz2, lzma
    data = b'Kodi on the Surface RT ' * 2000
    assert zlib.decompress(zlib.compress(data, 9)) == data and zlib.crc32(data) == zlib.crc32(data)
    assert bz2.decompress(bz2.compress(data)) == data
    assert lzma.decompress(lzma.compress(data)) == data
    try:
        from compression import zstd
        assert zstd.decompress(zstd.compress(data)) == data
        print('   zstd ok')
    except ImportError:
        print('   zstd not built')

@check('zip-tar')
def _():
    import io, zipfile, tarfile
    b = io.BytesIO()
    with zipfile.ZipFile(b, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('a.txt', 'hello' * 100)
    with zipfile.ZipFile(io.BytesIO(b.getvalue())) as z:
        assert z.read('a.txt') == b'hello' * 100
    b = io.BytesIO()
    with tarfile.open(fileobj=b, mode='w:xz') as t:
        info = tarfile.TarInfo('x'); payload = b'xyz' * 10; info.size = len(payload)
        t.addfile(info, io.BytesIO(payload))
    with tarfile.open(fileobj=io.BytesIO(b.getvalue()), mode='r:xz') as t:
        assert t.extractfile('x').read() == b'xyz' * 10

@check('xml')
def _():
    import xml.etree.ElementTree as ET, xml.dom.minidom, pyexpat
    root = ET.fromstring('<a x="1"><b>téxt</b><b/></a>')
    assert root.get('x') == '1' and len(root.findall('b')) == 2 and root[0].text == 'téxt'
    assert ET.tostring(root, encoding='unicode').startswith('<a x="1">')
    assert xml.dom.minidom.parseString('<r><c/></r>').documentElement.tagName == 'r'
    assert pyexpat.EXPAT_VERSION

@check('hashlib')
def _():
    import hashlib, hmac
    assert hashlib.sha256(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    assert hashlib.md5(b'abc').hexdigest() == '900150983cd24fb0d6963f7d28e17f72'
    assert hashlib.sha3_256(b'').hexdigest().startswith('a7ffc6f8bf1ed766')
    assert hashlib.blake2b(b'abc').hexdigest().startswith('ba80a53f981c4d0d')
    assert hmac.new(b'k', b'm', 'sha256').hexdigest() == 'b60090e3052297aeb5a080889ce2fc4bca957e756faeb4df7d31800ca1e771ec'
    print('   openssl backend:', hasattr(hashlib, 'openssl_sha256'))

@check('ssl')
def _():
    if '_ssl' not in sys.builtin_module_names and not REQUIRE_ALL:
        print('   _ssl not built here'); return
    import ssl
    print('  ', ssl.OPENSSL_VERSION)
    ctx = ssl.create_default_context()
    assert ctx.verify_mode == ssl.CERT_REQUIRED and ctx.check_hostname
    ctx.load_default_certs()   # Windows certificate stores
    print('   CA certs from the Windows store:', len(ctx.get_ca_certs()))

@check('sqlite3')
def _():
    import sqlite3
    con = sqlite3.connect(':memory:')
    con.execute('create table t (a integer, b text)')
    con.executemany('insert into t values (?, ?)', [(i, str(i) * 3) for i in range(1000)])
    assert con.execute('select count(*), sum(a) from t').fetchone() == (1000, 499500)
    assert con.execute("select json_extract('{\"k\": [1, 2]}', '$.k[1]')").fetchone()[0] == 2
    print('   sqlite', sqlite3.sqlite_version)
    con.close()

@check('threads-queue')
def _():
    import threading, queue
    q = queue.Queue(); out = []
    def worker():
        while (item := q.get()) is not None:
            out.append(item * item)
    ts = [threading.Thread(target=worker) for _ in range(4)]
    [t.start() for t in ts]
    for i in range(1000):
        q.put(i)
    for _ in ts:
        q.put(None)
    [t.join() for t in ts]
    assert sorted(out) == [i * i for i in range(1000)]

@check('socket-select')
def _():
    import socket, select, threading
    srv = socket.socket(); srv.bind(('127.0.0.1', 0)); srv.listen(1)
    port = srv.getsockname()[1]
    def serve():
        c, _ = srv.accept(); c.sendall(c.recv(100).upper()); c.close()
    t = threading.Thread(target=serve); t.start()
    cl = socket.create_connection(('127.0.0.1', port), timeout=10)
    cl.sendall(b'ping')
    r, _, _ = select.select([cl], [], [], 10)
    assert r and cl.recv(100) == b'PING'
    cl.close(); t.join(); srv.close()

@check('asyncio')
def _():
    import asyncio
    async def main():
        rs = await asyncio.gather(*(asyncio.sleep(0.01, result=i) for i in range(20)))
        return sum(rs)
    assert asyncio.run(main()) == 190

@check('subprocess-multiprocessing')
def _():
    import subprocess, multiprocessing
    out = subprocess.run([sys.executable, '-c', 'print(6 * 7)'], capture_output=True, text=True, timeout=120)
    assert out.stdout.strip() == '42', out
    import _multiprocessing, _overlapped
    with multiprocessing.get_context('spawn').Pool(2) as p:
        assert p.map(abs, [-1, -2, 3]) == [1, 2, 3]

@check('os-io-time')
def _():
    import os, tempfile, time, datetime, uuid, locale
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, 'fé.txt')
        with open(p, 'w', encoding='utf-8') as f:
            f.write('x' * 10000)
        assert os.path.getsize(p) == 10000 and os.listdir(d) == ['fé.txt']
    assert time.time() > 1.7e9 and datetime.datetime.now().year >= 2026
    assert uuid.uuid4().version == 4 and uuid.uuid1()
    locale.getlocale()

@check('pickle-marshal-gc')
def _():
    import pickle, marshal, gc, weakref, copy
    obj = {'a': [1, (2, 3)], 'b': {4.5, 'x'}, 'c': b'bytes'}
    assert pickle.loads(pickle.dumps(obj, 5)) == obj
    code = compile('x = 1 + 2', '<s>', 'exec')
    ns = {}; exec(marshal.loads(marshal.dumps(code)), ns); assert ns['x'] == 3
    class A: pass
    a = A(); r = weakref.ref(a); del a; gc.collect(); assert r() is None
    assert copy.deepcopy(obj) == obj

@check('exceptions-recursion')
def _():
    def f(n):
        return f(n + 1) if n < 500 else 1 / 0
    try:
        f(0)
    except ZeroDivisionError as e:
        assert e.__traceback__ is not None
    try:
        def g(): g()
        g()
    except RecursionError:
        pass

@check('ctypes')
def _():
    if '_ctypes' not in sys.builtin_module_names:
        print('   _ctypes not built (deferred)'); return
    import ctypes
    assert ctypes.windll.kernel32.GetTickCount() > 0

def main():
    print('python', sys.version.replace('\n', ' '), flush=True)
    print('platform', sys.platform, 'maxsize', hex(sys.maxsize), 'builtins', len(sys.builtin_module_names), flush=True)
    for name, fn in CHECKS:
        try:
            fn()
            results.append((name, None))
            print(f'SMOKE PASS {name}', flush=True)
        except Exception as e:
            results.append((name, e))
            print(f'SMOKE FAIL {name}: {type(e).__name__}: {e}', flush=True)
            traceback.print_exc()
    n = len(results); bad = [r for r in results if r[1] is not None]
    print(f'SMOKE ALL PASS ({n} checks)' if not bad else f'SMOKE FAILED ({len(bad)} of {n}): {[r[0] for r in bad]}',
          flush=True)
    return 0 if not bad else 1

if __name__ == '__main__':      # multiprocessing's spawn children import this file again
    sys.exit(main())
