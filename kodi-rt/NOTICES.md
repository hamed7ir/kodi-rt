kodi-rt is built from Kodi (GPL-2.0-or-later, Team Kodi / the XBMC Foundation), FFmpeg and the libraries below,
with patches and tooling that are GPLv3 (`LICENSE.txt`). Each upstream keeps its own license; its full text ships in
its source archive (`downloads/MANIFEST.tsv` lists every archive with its sha512). kodi-rt is not an official Kodi
build, and Team Kodi has nothing to do with it.

## in kodi.exe

| project | version | license |
|---|---|---|
| Kodi | master bffa625c (23.0 alpha 1) | GPL-2.0-or-later (its own third-party code: `LICENSES/` in Kodi's tree) |
| FFmpeg | 9.0.2 | GPL-2.0-or-later (built with `--enable-gpl`) |
| dav1d | 1.5.3 | BSD-2-Clause |
| zlib | 1.3.2 | zlib |
| libass | 0.17.5 | ISC |
| FreeType | 2.14.2 | FreeType License |
| HarfBuzz | 14.2.0 | MIT |
| FriBidi | 1.0.17 | LGPL-2.1-or-later |
| curl | 8.20.0 | curl (MIT-style) |
| OpenSSL | 3.5.7 | Apache-2.0 |
| brotli | 1.2.0 | MIT |
| nghttp2 | 1.69.0 | MIT |
| zstd | 1.5.7 | BSD-3-Clause |
| SQLite | 3.39.4 | public domain |
| PCRE2 | 10.47 | BSD-3-Clause |
| TagLib | 2.3.2 | LGPL-2.1 / MPL-1.1 |
| Exiv2 | 0.28.8 | GPL-2.0-or-later |
| libiconv | 1.18 | LGPL-2.1-or-later |
| LZO | 2.10 | GPL-2.0-or-later |
| fstrcmp | 0.7.D001 | GPL-3.0-or-later |
| fmt | 12.1.0 | MIT |
| spdlog | 1.17.0 | MIT |
| nlohmann/json | 3.12.0 | MIT |
| utfcpp | 4.0.6 | BSL-1.0 |
| TinyXML | 2.6.2 | zlib |
| TinyXML-2 | 11.0.0 | zlib |
| crossguid | ca1bf4b | MIT |
| FlatBuffers | 23.3.3 | Apache-2.0 |
| Effects11 (FX11) | 11.30 | MIT |
| C++/WinRT `base.h` (Windows SDK 10.0.26100, with its arm32 branches restored in `cross/cppwinrt-arm32`) | 2.0.250303.5 | MIT |

## next to it

| file | project | license |
|---|---|---|
| `dvdnav.dll` | libdvdnav 7.0.0 + libdvdread 7.0.1 | GPL-2.0-or-later |
| `python314.dll`, `system\python` | CPython 3.14.10, with its bundled mimalloc, expat, sqlite3, zlib, liblzma (xz 5.8.3), bzip2 1.0.8 and OpenSSL modules, and libffi 3.5.2 for ctypes | PSF-2.0 (bundled parts: MIT, public domain, zlib, 0BSD, bzip2, Apache-2.0; libffi: MIT) |
| `addons\script.module.pycryptodome` | pycryptodome 3.23.0 (its C modules built per architecture) | BSD-2-Clause and public domain (`LICENSE.rst` in the add-on) |
| `addons\script.module.pil` | Pillow 12.0.0, its C modules with libjpeg-turbo 3.1.4.1, zlib 1.3.2, FreeType 2.14.2, HarfBuzz 14.2.0, FriBidi 1.0.17 and raqm statically linked | MIT-CMU (Pillow); IJG + BSD-3-Clause, zlib, FTL, MIT, LGPL-2.1-or-later, MIT (`LICENSE` and `NOTICE.txt` in the add-on) |
| `Kodi-RT-Setup-*.exe` | Venetium's installer (hamed7ir/venetium, from hamed7ir/DroidFinestra) | GPLv3 |

the build also uses host tools that are not shipped: kodi's prebuilt TexturePacker, pkgconf 2.5.1, swig 4.5.0, and
llvm-rt 2.4 (llvm, apache-2.0 with llvm exceptions).
