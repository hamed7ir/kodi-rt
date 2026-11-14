#!/bin/bash
# kodi-rt Python stage: build/py/src/Python-3.14.10 = the pristine CPython source (src/deps) plus the edits of
# scripts/py-src-edits.py, and patches/python/kodi-rt-cpython-3.14.10.patch = the diff, as the record.
# Usage (Git Bash): bash scripts/py-prepare-src.sh
set -u
cd /f/kodi-rt || exit 1
P=src/deps/Python-3.14.10
C=build/py/src/Python-3.14.10
[ -f "$P/PCbuild/pythoncore.vcxproj" ] || { echo "pristine source missing: $P"; exit 1; }
rm -rf "$C" && mkdir -p build/py/src && cp -r "$P" "$C" || exit 1
python -I scripts/py-src-edits.py "F:/kodi-rt/$C" || exit 1
mkdir -p patches/python
( cd build/py/src && diff -ru --strip-trailing-cr "../../../$P" Python-3.14.10 ) \
  | sed -e "s#^--- \.\./\.\./\.\./src/deps/#--- a/#" -e "s#^+++ Python-3.14.10#+++ b/Python-3.14.10#" \
  > patches/python/kodi-rt-cpython-3.14.10.patch
echo "patch: $(grep -c '^diff ' patches/python/kodi-rt-cpython-3.14.10.patch) file(s), $(wc -l < patches/python/kodi-rt-cpython-3.14.10.patch) lines"
echo "PREPARE DONE"
