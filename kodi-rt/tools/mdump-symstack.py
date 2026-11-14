#!/usr/bin/env python3
# kodi-rt: mdump-stack.py's heuristic stack scan, symbolized in one llvm-symbolizer run against the matching exe+pdb.
# Usage: python -I mdump-symstack.py <crash.dmp> <exe with pdb next to it> <llvm-symbolizer.exe> [max] [start hex]
import os, subprocess, sys

dmp, exe, sym = sys.argv[1], os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3])
maxn = sys.argv[4] if len(sys.argv) > 4 else '70'
extra = [sys.argv[5]] if len(sys.argv) > 5 else []
here = os.path.dirname(os.path.abspath(__file__))
scan = subprocess.run([sys.executable, '-I', os.path.join(here, 'mdump-stack.py'), dmp, os.path.basename(exe), maxn]
                      + extra, capture_output=True, text=True, check=True).stdout.splitlines()
print(scan[0])
rows = []
for line in scan[1:]:
    parts = line.split()
    rows.append((parts[0], parts[1].split('+', 1)[1]))
inp = '\n'.join(rv for _, rv in rows) + '\n'
out = subprocess.run([sym, f'--obj={exe}', '--relative-address', '--functions=short', '--no-inlines'],
                     input=inp, capture_output=True, text=True).stdout
blocks = [b.splitlines() for b in out.strip().split('\n\n')]
last = None
for (slot, rv), b in zip(rows, blocks):
    fn = b[0] if b else '?'
    loc = os.path.basename(b[1].replace('\\', '/')) if len(b) > 1 else ''
    mark = '' if fn != last else '   (again)'
    print(f'  {slot:>10} {rv:>10}  {fn}  {loc}{mark}')
    last = fn
