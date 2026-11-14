# kodi-rt Stage 4: show the compile command of a few Kodi sources and the kodi.exe link command of a configured
# build, to check the flags (target, /MT, no SSE defines, SDK pins) before building.
# Usage: python -I scripts/s4-show-flags.py F:/kodi-rt/build/s4/kodi-build
import json, os, re, sys

bd = sys.argv[1]
cc = json.load(open(os.path.join(bd, 'compile_commands.json'), encoding='utf-8'))
print(len(cc), 'compile commands')
exts = {}
for e in cc:
    x = e['file'].lower().rsplit('.', 1)[-1]
    exts[x] = exts.get(x, 0) + 1
print('by extension:', exts)
for want in ('xbmc/Application.cpp', 'xbmc/platform/win32/CPUInfoWin32.cpp', 'xbmc/utils/log.cpp'):
    for e in cc:
        if e['file'].replace(os.sep, '/').replace('\\', '/').endswith(want):
            print('==', want)
            print(e['command'])
            break
# flags that must not appear in any compile command
bad = {'/MD': 0, '/MDd': 0, '-D__SSE__': 0, '-D__SSE2__': 0, '/GL': 0, '/arch:SSE2': 0}
for e in cc:
    toks = e['command'].split()
    for b in bad:
        if b in toks:
            bad[b] += 1
print('forbidden flags (count of commands):', bad)
nomt = [e['file'] for e in cc if not ({'/MT', '-MT'} & set(e['command'].split())) and not e['file'].lower().endswith(('.rc', '.asm', '.s'))]
print('commands without /MT:', len(nomt), nomt[:5])
nb = open(os.path.join(bd, 'build.ninja'), encoding='utf-8').read()
m = re.search(r'\nbuild kodi\.exe[^\n]*\n((?:  [^\n]*\n)+)', nb)
if m:
    for line in m.group(1).splitlines():
        if line.strip().startswith(('LINK_FLAGS', 'LINK_LIBRARIES', 'LINK_PATH', 'TARGET_PDB')):
            print(line[:4000])
else:
    print('no "build kodi.exe" statement found')
