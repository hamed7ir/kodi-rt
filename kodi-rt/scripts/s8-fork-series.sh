#!/bin/bash
# kodi-rt: write the fork's commit series from release-docs/fork/series.tsv: one diff per commit in
# release-docs/fork/series/, made and checked in a scratch clone of src/xbmc at bffa625c (build/s9/forkprep; index and
# tree objects only, no commits). Check: after the whole series the tree equals build/s9/kodi (the x64/x86 source:
# the release source build/s7/kodi + detours-optional), apart from project/BuildDependencies/tools (host tools the
# build adds). release/fork/make-fork.sh (run by Hamed) commits the series with series/series.txt's messages.
# Usage (Git Bash): bash scripts/s8-fork-series.sh
set -u
W=/f/kodi-rt
TSV=$W/release-docs/fork/series.tsv
OUT=$W/release-docs/fork/series
S=$W/build/s9/forkprep
BASE=bffa625cc84860f241772d87a654844b98bebb60
rm -rf "$S" "$OUT"; mkdir -p "$OUT" || exit 1
git clone -q --no-checkout file:///F:/kodi-rt/src/xbmc "$S" || exit 1
cd "$S" || exit 1
git checkout -q "$BASE" || exit 1
: > "$OUT/series.txt"
n=0
while IFS=$'\t' read -r file how subject body; do
  case $file in ''|'#'*) continue ;; esac
  git add -A && T0=$(git write-tree) || exit 1
  IFS=';' read -r -a acts <<< "$how"   # several actions for one commit: "edit:x.py;copy:a=b"
  for act in "${acts[@]}"; do
  case $act in
    patch:*)        git apply --whitespace=nowarn "$W/patches/${act#patch:}" || { echo "FAILED: $act"; exit 1; } ;;
    patch-unedit:*) r=${act#patch-unedit:}; p=${r%%:*}; e=${r#*:}
                    git apply --whitespace=nowarn "$W/patches/$p" || { echo "FAILED: $act"; exit 1; }
                    python -I "$W/scripts/s8-unapply-edits.py" "$S" "$W/reports/proposed-edits/$e" > /dev/null || { echo "FAILED: $act"; exit 1; } ;;
    edit:*)         python -I "$W/scripts/s7-apply-edits.py" "$S" "$W/reports/proposed-edits/${act#edit:}" > /dev/null || { echo "FAILED: $act"; exit 1; } ;;
    copy:*)         IFS=',' read -r -a pairs <<< "${act#copy:}"
                    for pr in "${pairs[@]}"; do cp -f "$W/${pr%%=*}" "$S/${pr#*=}" || { echo "FAILED: $act"; exit 1; }; done ;;
    *) echo "unknown: $act"; exit 1 ;;
  esac
  done
  git add -A && T1=$(git write-tree) || exit 1
  [ "$T0" != "$T1" ] || { echo "EMPTY: $file"; exit 1; }
  git diff-tree -p --binary "$T0" "$T1" > "$OUT/$file"
  [ "$body" = '""' ] && body=
  printf '%s\t%s\t%s\n' "$file" "$subject" "$body" >> "$OUT/series.txt"
  n=$((n + 1))
  printf '%s  %s\n' "$file" "$(git diff-tree --shortstat "$T0" "$T1")"
done < "$TSV"
d=$(diff -rq -x .git "$S" "$W/build/s9/kodi" 2>&1 | grep -v '^Only in .*/build/s9/kodi/project/BuildDependencies: tools$')
if [ -n "$d" ]; then echo "SERIES DIFFERS FROM build/s9/kodi:"; echo "$d" | head -20; exit 1; fi
echo "series: $n commits in $OUT; the result equals build/s9/kodi"
echo "SERIES DONE"
