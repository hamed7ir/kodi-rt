# kodi-rt: apply edit blocks written for scripts/s4-dev-edits.py (edit(rel, old, new), each old matching exactly once)
# to another tree, e.g. the frozen PGO source build/s7/kodi.
# Usage: python -I scripts/s7-apply-edits.py <tree root> <edit file> [...]
import os, sys

root = sys.argv[1]

def edit(rel, old, new):
    p = os.path.join(root, rel)
    s = open(p, encoding='utf-8', newline='').read()
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{rel}: expected 1 match, found {n}:\n{old}')
    open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
    print(f'edited {rel}')

for f in sys.argv[2:]:
    exec(compile(open(f, encoding='utf-8').read(), f, 'exec'), {'edit': edit})
