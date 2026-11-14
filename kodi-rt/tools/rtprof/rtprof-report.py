#!/usr/bin/env python3
# kodi-rt: read an rtprof.txt from the tablet and symbolize its kodi.exe samples with the gated kodi.exe/kodi.pdb.
# Prints the per-5-s CPU lines, then for each thread with samples: CPU seconds, priority, start function, and its top
# functions by sample count (samples in other DLLs are shown as module+offset; ntdll waits are marked "waiting").
# Usage: python -I rtprof-report.py <rtprof.txt> <gated kodi.exe> <llvm-symbolizer.exe> [functions per thread, 12]
import collections, os, re, subprocess, sys

path, exe, sym = sys.argv[1], os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3])
top_n = int(sys.argv[4]) if len(sys.argv) > 4 else 12
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()

threads, cur = [], None
for line in lines:
    m = re.match(r'thread (\d+): cpu ([\d.]+) s, priority (-?\d+), start (\S+), (\d+) samples', line)
    if m:
        cur = {'tid': int(m.group(1)), 'cpu': float(m.group(2)), 'prio': int(m.group(3)), 'start': m.group(4),
               'n': int(m.group(5)), 'pcs': []}
        threads.append(cur)
        continue
    m = re.match(r'\s+(\d+)\s+(\S+)$', line)
    if m and cur is not None:
        cur['pcs'].append((int(m.group(1)), m.group(2)))

# symbolize every kodi.exe offset in one llvm-symbolizer run
offs = sorted({loc.split('+')[1] for t in threads for _, loc in t['pcs'] + [(0, t['start'])]
               if loc.lower().startswith('kodi.exe+')})
names = {}
if offs:
    r = subprocess.run([sym, f'--obj={exe}', '--relative-address', '--functions=short', '--no-inlines'],
                       input='\n'.join(offs) + '\n', capture_output=True, text=True)
    for off, block in zip(offs, r.stdout.strip().split('\n\n')):
        b = block.splitlines()
        loc = os.path.basename(b[1].replace('\\', '/')) if len(b) > 1 else ''
        names[off] = f'{b[0]} ({loc})' if b else '?'

def label(loc):
    if loc.lower().startswith('kodi.exe+'):
        return names.get(loc.split('+')[1], loc)
    if loc.lower().startswith('ntdll.dll+'):
        return loc + '  [ntdll: usually waiting]'
    return loc

print('== CPU over time')
for line in lines:
    if line.startswith('t='):
        print(line)
print()
for t in sorted(threads, key=lambda t: -t['cpu']):
    if t['cpu'] < 0.5 and t['n'] == 0:
        continue
    print(f"== thread {t['tid']}: {t['cpu']:.1f} s CPU, priority {t['prio']}, start {label(t['start'])}, "
          f"{t['n']} samples")
    agg = collections.Counter()
    for n, loc in t['pcs']:
        agg[label(loc)] += n
    total = sum(agg.values()) or 1
    for name, n in agg.most_common(top_n):
        print(f'   {100.0 * n / total:5.1f}%  {name}')
    print()
