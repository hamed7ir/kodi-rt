## kodi-rt v1.0

the first release: kodi master (23.0 alpha, bffa625c) with python 3.14, for windows rt 8.1 on arm32, tested on my
surface rt (tegra 3). there are x64 and x86 builds of it too, for windows 8.1 and later pcs.

**install:** the setup for your windows, per user, no admin:

- `Kodi-RT-Setup-1.0-arm32.exe`: windows rt 8.1 (surface rt, surface 2)
- `Kodi-RT-Setup-1.0-x64.exe`: 64-bit windows 8.1 and later
- `Kodi-RT-Setup-1.0-x86.exe`: 32-bit windows 8.1 and later

it puts kodi in `%LocalAppData%\Programs\Kodi RT` with start menu and desktop shortcuts; kodi keeps your library and
settings in `%AppData%\Kodi`. "check requirements" in the setup says if anything is missing. uninstall leaves your
kodi data alone.

what's in it:

- **pgo + thinlto** build of kodi and ffmpeg together for arm32 (llvm-rt 2.4), compiled from a profile of real use on
  the surface rt. 720p 10-bit x265 now plays in software at 24 fps with no skipped frames; before it ran at 15-18 with
  skips
- **a kodi bug the profile found:** kodi converted every 10-bit frame yuv -> rgb -> yuv in ffmpeg's scaler, because its
  filter graph didn't say which colorspace the frames are in. slow, and the colours came out a bit off. fixed in 0014
- **neon** for ffmpeg's 10-bit hevc motion compensation on arm32 (`kodi-rt/patches-ffmpeg/0001`), checked bit-exact
  against the c code on the device
- **1080p h.264** plays on the gpu (d3d11 dxva). on the tablet 10-bit video is shown in 8 bits, feature level 9_1 has
  no 10-bit textures (0015)
- **touch:** a tap is a tap (0010), two-finger tap is back, a tap keeps the video controls up, estuary's touch mode
  on (arm32), and a fullscreen button in the video controls (0011)
- **skiploopfilter 48** for software video on the tablet by default. to change it, put your own `<skiploopfilter>` in
  `%AppData%\Kodi\userdata\advancedsettings.xml` (0 is full quality, slower)
- **python 3.14.10**, kodi's own pin: add-ons and skins that need python work
- a crash opening big mkv files is fixed (0012)
- **open with:** the setup puts kodi rt in explorer's open with menu for the video, music and playlist types it plays,
  per user, without taking over your default apps. if kodi is already open, the file plays in that kodi (0019)
- **purple icon**, so it doesn't look like the official kodi, and the splash says 23.0 alpha instead of kodi 22's
  "22.0 rc" (0018)
- **x64 and x86** builds from the same commits; three small changes make desktop builds possible (in 0001, 0003
  and 0017). no pgo there; ffmpeg and dav1d have their x86 assembly (checkasm passes on my build server). checked
  on my build server only (windows server 2022 over rdp, no gpu): the setups install and uninstall cleanly, and kodi
  starts, plays an h.264 clip in software, runs python and closes cleanly

the numbers are the commits on the `kodi-rt` branch, also in `kodi-rt/patches/`.

known issues:

- no ctypes, pillow or pycryptodome in python yet, so add-ons that need them fail
- it is kodi master, so expect alpha bugs
- not tested on the surface 2 yet

sha256:

- `Kodi-RT-Setup-1.0-arm32.exe`: `f28b9966cbb6ab5c36b6f8c90441d91b00131f47c4dc4db72198a50d4ad06293`
- `Kodi-RT-Setup-1.0-x64.exe`: `844c9cacc2a5b492cacbacc0ade8b32f99f7f87bf48118458af5c63d96d804cf`
- `Kodi-RT-Setup-1.0-x86.exe`: `7143fc2e97bc4be2c1eb4ab179994244ab80ef4b965c5c973637c06c07dd0f35`
