# kodi-rt Stage 4: recompile ONE file of the configured Kodi build with extra compiler arguments, to try a fix
# without a rebuild. Takes the file's command from compile_commands.json as is (a Windows command line), points /Fo at
# a scratch object (the build's own object is untouched), inserts the extra arguments before "-c", and prints the
# compiler's diagnostics (errors and notes only, unless --all).
# Usage (from Git Bash, with MSYS2_ARG_CONV_EXCL='*'):
#   python -I scripts/s4-try-compile.py <build dir> <source path suffix> [--all] [--out=<path>] [-- extra clang-cl args...]
# --out: where /Fo points (default: %TEMP%/kodirt-try.obj), e.g. a .ll with -- /clang:-S /clang:-emit-llvm
import json, os, re, subprocess, sys, tempfile

bd, suffix = sys.argv[1], sys.argv[2].replace('\\', '/')
rest = sys.argv[3:]
show_all = '--all' in rest
extra = rest[rest.index('--') + 1:] if '--' in rest else []
cc = json.load(open(os.path.join(bd, 'compile_commands.json'), encoding='utf-8'))
hits = [e for e in cc if e['file'].replace('\\', '/').endswith(suffix)]
if len(hits) != 1:
    raise SystemExit(f'{len(hits)} compile commands end with {suffix}')
e = hits[0]
outs = [a[6:] for a in rest if a.startswith('--out=')]
out = outs[0] if outs else os.path.join(tempfile.gettempdir(), 'kodirt-try.obj')
cmd, n = re.subn(r' /Fo\S+', ' /Fo' + out.replace('\\', '/'), e['command'])
assert n == 1, 'no single /Fo in the command'
assert cmd.count(' -c ') == 1, 'no single " -c " in the command'
cmd = cmd.replace(' -c ', ' ' + subprocess.list2cmdline(extra) + ' -c ') if extra else cmd
r = subprocess.run(cmd, cwd=e['directory'], capture_output=True, text=True)
lines = (r.stdout + r.stderr).splitlines()
for l in lines:
    if show_all or 'error' in l or 'note:' in l or 'fatal' in l:
        print(l[:400])
print(f'exit {r.returncode}; {sum("error:" in l for l in lines)} error lines')
