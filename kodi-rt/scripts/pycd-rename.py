# kodi-rt: pycryptodome's "separate namespace" package, as its setup.py create_cryptodome_lib() makes it when
# .separate_namespace exists (Kodi's depends build touches it): copy lib/Crypto to Cryptodome and, in the .py/.pyi
# files, replace "Crypto." -> "Cryptodome.", "Crypto " -> "Cryptodome ", 'Crypto' / "Crypto" -> the same with
# Cryptodome. Reads the (patched) source tree as data only.
# Usage: python -I scripts/pycd-rename.py <.../lib/Crypto> <out/Cryptodome>
import os, shutil, sys

src, dst = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
assert os.path.basename(src) == 'Crypto' and os.path.basename(dst) == 'Cryptodome'
if not os.path.isfile(os.path.join(src, '__init__.py')):
    raise SystemExit(f'not the pycryptodome package: {src} (pass a Windows path)')
if os.path.exists(dst):
    shutil.rmtree(dst)
n = edited = 0
for root, dirs, files in os.walk(src):
    out_root = os.path.join(dst, os.path.relpath(root, src))
    os.makedirs(out_root, exist_ok=True)
    for fn in files:
        s, d = os.path.join(root, fn), os.path.join(out_root, fn)
        n += 1
        if fn.rsplit('.', 1)[-1] in ('py', 'pyi'):
            text = open(s, encoding='utf-8').read()
            new = (text.replace('Crypto.', 'Cryptodome.').replace('Crypto ', 'Cryptodome ')
                       .replace("'Crypto'", "'Cryptodome'").replace('"Crypto"', '"Cryptodome"'))
            edited += new != text
            open(d, 'w', encoding='utf-8', newline='\n').write(new)
            shutil.copystat(s, d)
        else:
            shutil.copy2(s, d)
if n < 100 or edited < 50:
    raise SystemExit(f'{dst}: only {n} files, {edited} edited: something is wrong')
print(f'{dst}: {n} files, {edited} with Crypto -> Cryptodome replacements')
