# kodi-rt: the reverse of scripts/s7-apply-edits.py: undo edit blocks (edit(rel, old, new): the new text, matching
# exactly once, goes back to the old). Used to split a patch that holds more than one change into separate commits.
# Usage: python -I scripts/s8-unapply-edits.py <tree root> <edit file> [...]
import os, sys

root = sys.argv[1]


def edit(rel, old, new):
    p = os.path.join(root, rel)
    s = open(p, encoding='utf-8', newline='').read()
    n = s.count(new)
    if n != 1:
        raise SystemExit(f'{rel}: expected 1 match of the edited text, found {n}:\n{new}')
    open(p, 'w', encoding='utf-8', newline='').write(s.replace(new, old))
    print(f'unedited {rel}')


for f in sys.argv[2:]:
    exec(compile(open(f, encoding='utf-8').read(), f, 'exec'), {'edit': edit})
