#!/bin/bash
# kodi-rt: assemble the release repo tree release/kodi-rt from the work tree, for Hamed to commit and push himself.
#   docs (README, RECIPE, NOTICES, LICENSE, release notes, .gitignore, pgo/) from release-docs/; the recipe from the
#   work tree: patches, patches-ffmpeg, scripts, cross, installer, tools (sources: rtprof, pgo, dbgrun, mdump*.py), tests
#   (sources only), kit (the presets and the latest kits' hand-written files), downloads/MANIFEST.tsv.
#   Never: binaries, build outputs, downloads, logs, device results, reports.
# Refuses to touch release/kodi-rt once it is a git repo (then copy changes in by hand).
# Usage (Git Bash): bash scripts/s8-assemble-repo.sh [setup exe]
set -u
W=/f/kodi-rt
R=${R:-$W/release/kodi-rt}   # R=<dir>: assemble elsewhere (scripts/s8-assemble-fork.sh)
SETUP=${1:-$W/build/s8/installer/dist/Kodi-RT-Setup-1.0-arm32.exe}
[ -e "$R/.git" ] && { echo "$R is a git repo already: not touching it"; exit 1; }
[ -f "$SETUP" ] || { echo "no $SETUP"; exit 1; }
rm -rf "$R"; mkdir -p "$R" || exit 1
cp "$W/release-docs/README.md" "$W/release-docs/RECIPE.md" "$W/release-docs/NOTICES.md" "$W/release-docs/LICENSE.txt" \
   "$W/release-docs/RELEASE-NOTES-v1.0.md" "$W/release-docs/.gitignore" "$R/" || exit 1
sed -i "s/SETUP_SHA256/$(sha256sum "$SETUP" | cut -d' ' -f1)/" "$R/RELEASE-NOTES-v1.0.md"
cp -r "$W/release-docs/pgo" "$R/" || exit 1
cp -r "$W/patches" "$W/patches-ffmpeg" "$W/scripts" "$W/cross" "$W/installer" "$R/" || exit 1
mkdir -p "$R/tools/dbgrun"
cp -r "$W/tools/rtprof" "$W/tools/pgo" "$R/tools/" && cp "$W"/tools/mdump*.py "$R/tools/" \
  && cp "$W/tools/dbgrun/dbgrun.c" "$W/tools/dbgrun/build.sh" "$R/tools/dbgrun/" || exit 1
( cd "$W" && find tests -type f ! \( -iname '*.exe' -o -iname '*.obj' -o -iname '*.o' -o -iname '*.pdb' -o -iname '*.lib' \
    -o -iname '*.dll' -o -iname '*.ilk' -o -iname '*.dmp' -o -iname '*.a' -o -iname '*.profraw' \) ) | while read -r f; do
  mkdir -p "$R/$(dirname "$f")" && cp "$W/$f" "$R/$f"
done
mkdir -p "$R/kit" && cp -r "$W/kit/keymaps" "$W/kit/portable-data" "$W/kit/python" "$W/kit/rtprof" "$R/kit/" || exit 1
for k in kodi-rt-stage6-pgo kodi-rt-pgo-profile; do
  mkdir -p "$R/kit/$k" && cp "$W/kit/$k"/*.cmd "$W/kit/$k/README.txt" "$R/kit/$k/" || exit 1
done
mkdir -p "$R/downloads" && cp "$W/downloads/sources/MANIFEST.tsv" "$R/downloads/" || exit 1
mkdir -p "$R/branding" && cp "$W/branding/README.txt" "$W/branding/poster-v1.0.png" "$R/branding/" || exit 1   # icon + splash are in the Kodi tree (commit 0018)
find "$R" -name __pycache__ -type d -prune -exec rm -rf {} +

# checks: no binaries (the icon and the xz profile are the only non-text files), nothing big, no private data
FAIL=0
bin=$(find "$R" -type f \( -iname '*.exe' -o -iname '*.obj' -o -iname '*.o' -o -iname '*.pdb' -o -iname '*.lib' -o -iname '*.dll' \
      -o -iname '*.dmp' -o -iname '*.zip' -o -iname '*.profraw' \))
[ -z "$bin" ] || { echo "BINARIES:"; echo "$bin"; FAIL=1; }
big=$(find "$R" -type f -size +1M ! -name 'kodi-20261113.profdata.xz' ! -name 'poster-v1.0.png')
[ -z "$big" ] || { echo "FILES OVER 1 MB:"; echo "$big"; FAIL=1; }
# (LICENSE.txt: the GPL's "no special password or key"; this script: the pattern itself)
priv=$(grep -rIl -iE 'gmail\.com|password|api[_-]?key|BEGIN (RSA|OPENSSH|PRIVATE)' "$R" | grep -vE '/(LICENSE\.txt|s8-assemble-(repo|fork)\.sh)$' || true)
[ -z "$priv" ] || { echo "CHECK FOR PRIVATE DATA:"; echo "$priv"; FAIL=1; }
echo "repo: $R: $(find "$R" -type f | wc -l) files, $(du -sh "$R" | cut -f1)"
( cd "$R" && for d in *; do [ -d "$d" ] && printf '  %-16s %5s files\n' "$d/" "$(find "$d" -type f | wc -l)"; done )
[ $FAIL -eq 0 ] && echo "ASSEMBLE DONE" || { echo "ASSEMBLE: CHECK FAILED"; exit 1; }
