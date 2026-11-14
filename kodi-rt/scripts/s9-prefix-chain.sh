#!/bin/bash
# kodi-rt Stage 9: build the x64 prefix (continuing after zlib and libiconv, which ran first as a test), then the whole
# x86 prefix, one after the other (-j8 each, never both at once). Started detached (scripts/launch-detached.ps1 -Shell git).
exec > /f/kodi-rt/logs/s9-prefix-chain.log 2>&1
cd /f/kodi-rt || exit 1
echo "chain start $(date '+%F %T')"
ARCH=x64 bash scripts/s9-prefix.sh small more openssl curl font hand dvd dav1d; echo "x64 exit $?"
ARCH=x86 bash scripts/s9-prefix.sh; echo "x86 exit $?"
echo "chain end $(date '+%F %T')"
