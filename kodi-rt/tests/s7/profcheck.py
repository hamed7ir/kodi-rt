# kodi-rt PGO phase 2: does the profile match? Re-runs Kodi compile commands of build/s7/kodi-build-pgo (from
# `ninja -t commands`, saved as build/s7/tests/profcheck/cmd-*.txt) with the profile warnings switched back on
# (-Wprofile-instr-out-of-date, -Wprofile-instr-unprofiled, -Wbackend-plugin) into a scratch object, and prints what
# clang says about the profile: functions with changed control flow (hash mismatch) or without data.
# Usage: python -I tests/s7/profcheck.py
import glob, os, re, subprocess

bd = r'F:\kodi-rt\build\s7\kodi-build-pgo'
out_dir = r'F:\kodi-rt\build\s7\tests\profcheck'
for f in sorted(glob.glob(os.path.join(out_dir, 'cmd-*.txt'))):
    cmd = open(f, encoding='utf-8').read().strip()
    cmd = cmd.replace('/showIncludes', '')
    cmd = re.sub(r' /Fd\S+', '', cmd)
    obj = os.path.join(out_dir, 'x.obj')
    cmd = re.sub(r' /Fo\S+', lambda m: ' /Fo' + obj, cmd)
    for w in ('profile-instr-out-of-date', 'profile-instr-unprofiled', 'backend-plugin'):
        cmd = cmd.replace('-Wno-' + w, '-W' + w)
    r = subprocess.run(cmd, cwd=bd, capture_output=True, text=True)
    text = r.stdout + r.stderr
    lines = [l for l in text.splitlines() if 'profile' in l.lower() or 'hash mismatch' in l.lower()]
    print(f'== {os.path.basename(f)[4:-4]}: rc {r.returncode}, {len(lines)} profile messages')
    for l in lines[:12]:
        print('   ' + l.strip()[:220])
