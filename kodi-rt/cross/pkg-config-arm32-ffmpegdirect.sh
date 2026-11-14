#!/bin/bash
# kodi-rt: a minimal pkg-config for FFmpeg's configure in scripts/s10-ffmpeg.sh (this server has no pkg-config).
# It knows exactly two packages, our static ARM32 builds, and reports every other one as missing:
#   openssl     3.5.7   prefix/arm32 (FFmpeg's GPL check wants "openssl >= 3.0.0" through pkg-config)
#   libxml-2.0  2.15.4  prefix/arm32-addons (scripts/s10-addon-deps.sh libxml2; FFmpeg's DASH demuxer)
# Libraries are given as -l<name> (configure keeps those out of its compile tests and turns them into <name>.lib
# for lld-link; the library folders are in s10-ffmpeg.sh's --extra-ldflags), with the Windows libraries the static
# builds need. Answers --version, --exists, --modversion, --cflags, --libs; a version constraint (">= 3.0.0", also
# inside one quoted argument, as FFmpeg passes it) is checked against the versions above with sort -V.
P=F:/kodi-rt/prefix/arm32
A=F:/kodi-rt/prefix/arm32-addons
modes=" "; words=()
for a in "$@"; do
  case $a in
    --version) echo 0.29.2; exit 0 ;;
    --exists|--modversion|--cflags|--libs|--cflags-only-I|--libs-only-l) modes="$modes$a " ;;
    --*) ;;
    *) for w in $a; do words+=("$w"); done ;;
  esac
done
out=()
i=0
while [ $i -lt ${#words[@]} ]; do
  name=${words[$i]}; op=; want=
  case ${words[$((i + 1))]:-} in '>='|'<='|'='|'>'|'<') op=${words[$((i + 1))]}; want=${words[$((i + 2))]:-}; i=$((i + 2)) ;; esac
  i=$((i + 1))
  case $name in
    openssl) ver=3.5.7; cflags="-I$P/include"
             libs="-llibssl -llibcrypto -lzs -lcrypt32 -ladvapi32 -lws2_32 -luser32" ;;   # our OpenSSL has zlib (zs.lib)
    libxml-2.0) ver=2.15.4; cflags="-I$A/include/libxml2 -DLIBXML_STATIC"; libs="-llibxml2s -lbcrypt -lws2_32" ;;
    *) echo "Package $name was not found (kodi-rt pkg-config stand-in)" >&2; exit 1 ;;
  esac
  if [ -n "$op" ]; then
    lo=$(printf '%s\n%s\n' "$want" "$ver" | sort -V | head -1)
    case $op in
      '>=') [ "$lo" = "$want" ] || { echo "Requested '$name >= $want' but version of $name is $ver" >&2; exit 1; } ;;
      '>')  [ "$lo" = "$want" ] && [ "$want" != "$ver" ] || exit 1 ;;
      '=')  [ "$want" = "$ver" ] || exit 1 ;;
      '<=') [ "$lo" = "$ver" ] || exit 1 ;;
      '<')  [ "$lo" = "$ver" ] && [ "$want" != "$ver" ] || exit 1 ;;
    esac
  fi
  case $modes in *" --modversion "*) out+=("$ver") ;; esac
  case $modes in *" --cflags "*|*" --cflags-only-I "*) out+=("$cflags") ;; esac
  case $modes in *" --libs "*|*" --libs-only-l "*) out+=("$libs") ;; esac
done
[ ${#out[@]} -gt 0 ] && echo "${out[*]}"
exit 0
