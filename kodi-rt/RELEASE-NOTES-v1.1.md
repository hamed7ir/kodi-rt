## kodi-rt v1.1

- python now has ctypes, pycryptodome and pillow (1.0 didn't), which a lot of add-ons need
- arm32: inputstream.adaptive (youtube needs it), ffmpegdirect, rtmp, iptv simple, vfs.rar and vfs.libarchive in the
  setup. kodi's repository has none for 32-bit arm
- x64/x86: binary add-ons from kodi's repository need microsoft's visual c++ 2015-2022 redistributable
- the fullscreen button is the same size as the other video controls
- purple kodi logo, and estuary's violet theme by default

`arm32` is for windows rt 8.1 (surface rt, surface 2), `x64` and `x86` for windows 8.1 and later. install it over 1.0, your kodi data stays.

- `Kodi-RT-Setup-1.1-arm32.exe`: `d36049c48451d891edce2cd327764e4e82f7be09a841188db4ae8e7ed039cafb`
- `Kodi-RT-Setup-1.1-x64.exe`: `1396a7bb90ce611cca4b95c0b98d64a9a093923b191e51f7c4fede839e83c4c9`
- `Kodi-RT-Setup-1.1-x86.exe`: `03472c58ebbe09a1b2b052647c87982af73f8893735d3185cafa6e97e04b5c70`
