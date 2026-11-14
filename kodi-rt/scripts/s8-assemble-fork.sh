#!/bin/bash
# kodi-rt: assemble the fork kit release/fork for Hamed, who makes and pushes the fork himself (COMMANDS-fork.txt):
#   make-fork.sh          release-docs/fork/make-fork.sh: clones the local Kodi copy at bffa625c, commits the series
#   series/               the commit series (scripts/s8-fork-series.sh: one diff per commit + series.txt messages)
#   tree/README.md        the repo's readme (release-docs/fork/README.md), replacing Kodi's in the last commit
#   tree/kodi-rt/         the recipe tree of scripts/s8-assemble-repo.sh (scripts, cross, installer, tools, tests,
#                         kit, docs) without its readme, patches/ = the series (the branch's commits as files),
#                         RELEASE-NOTES-v1.0.md = release-docs/fork/RELEASE-NOTES-v1.0.md with the setups' sha256
#   assets/               the three setups for the release (arm32 = the one already in C:\handoff)
#   COMMANDS-fork.txt     release-docs/fork/COMMANDS-fork.txt with the setups' sha256
# Runs s8-fork-series.sh first (it checks the series against build/s9/kodi). No git commit or push here.
# Usage (Git Bash): bash scripts/s8-assemble-fork.sh
set -u
W=/f/kodi-rt
F=$W/release/fork
D=$W/release-docs/fork
A32=$W/build/s8/installer/dist/Kodi-RT-Setup-1.0-arm32.exe
A64=$W/build/s8/installer-x64/dist/Kodi-RT-Setup-1.0-x64.exe
A86=$W/build/s8/installer-x86/dist/Kodi-RT-Setup-1.0-x86.exe
for f in "$A32" "$A64" "$A86" "$D/README.md" "$D/RELEASE-NOTES-v1.0.md" "$D/make-fork.sh" "$D/COMMANDS-fork.txt"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done
grep -l 'X64X86_TESTED' "$D/README.md" "$D/RELEASE-NOTES-v1.0.md" && { echo "^ still has the X64X86_TESTED placeholder"; exit 1; }
bash $W/scripts/s8-fork-series.sh | tail -2 | grep -q 'SERIES DONE' || { echo "the series check failed (bash scripts/s8-fork-series.sh)"; exit 1; }
rm -rf "$F"; mkdir -p "$F/assets" "$F/tree" || exit 1
cp "$D/make-fork.sh" "$F/" && cp -r "$D/series" "$F/" || exit 1
cp "$A32" "$A64" "$A86" "$F/assets/" || exit 1
sums=$(cd "$F/assets" && sha256sum Kodi-RT-Setup-1.0-*.exe)
# the recipe tree, assembled by s8-assemble-repo.sh into a scratch folder (its checks run there)
T=$W/build/s8/fork-tree
rm -rf "$T"
R=$T bash $W/scripts/s8-assemble-repo.sh "$A32" | tail -1 | grep -q 'ASSEMBLE DONE' || { echo "s8-assemble-repo.sh failed (R=$T)"; exit 1; }
mv "$T" "$F/tree/kodi-rt" || exit 1
K=$F/tree/kodi-rt
rm -f "$K/README.md" "$K/RELEASE-NOTES-v1.0.md" "$K/.gitignore"
rm -rf "$K/patches"/0*.patch && cp "$D/series"/0*.patch "$K/patches/" || exit 1
cp "$D/README.md" "$F/tree/README.md" || exit 1
python -I - "$D/RELEASE-NOTES-v1.0.md" "$K/RELEASE-NOTES-v1.0.md" "$D/COMMANDS-fork.txt" "$F/COMMANDS-fork.txt" "$sums" <<'EOF'
import sys
notes_in, notes_out, cmd_in, cmd_out, sums = sys.argv[1:6]
lines = [l.split() for l in sums.strip().splitlines()]
table = '\n'.join(f'- `{name.lstrip("*")}`: `{h}`' for h, name in lines)
plain = '\n'.join(f'sha256 {name.lstrip("*")}: {h}' for h, name in lines)
for src, dst, key, val in ((notes_in, notes_out, 'SETUP_SHA256S', table), (cmd_in, cmd_out, 'SETUP_SHA256S', plain)):
    s = open(src, encoding='utf-8').read()
    if key not in s:
        raise SystemExit(f'{src}: no {key}')
    open(dst, 'w', encoding='utf-8', newline='\n').write(s.replace(key, val))
EOF
[ $? -eq 0 ] || exit 1
# checks: the tree has no binaries but the icon and the xz profile, nothing private
bin=$(find "$F/tree" -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.lib' -o -iname '*.pdb' -o -iname '*.zip' -o -iname '*.obj' \))
[ -z "$bin" ] || { echo "BINARIES IN THE TREE:"; echo "$bin"; exit 1; }
priv=$(grep -rIl -iE 'gmail\.com|password|api[_-]?key|BEGIN (RSA|OPENSSH|PRIVATE)' "$F" | grep -vE '/(LICENSE\.txt|s8-assemble-(repo|fork)\.sh)$' || true)
[ -z "$priv" ] || { echo "CHECK FOR PRIVATE DATA:"; echo "$priv"; exit 1; }
echo "fork kit: $F"
echo "  series: $(ls "$F/series"/0*.patch | wc -l) commits; tree: $(find "$F/tree" -type f | wc -l) files ($(du -sh "$F/tree" | cut -f1))"
echo "$sums" | sed 's/^/  /'
echo "FORK KIT DONE"
