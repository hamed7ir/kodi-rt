kodi-rt PGO profiling kit (2026-11-13): a COUNTING Kodi, step 1 of the PGO + ThinLTO build.

What it is: the update-4 Kodi (the same patches, Python, and presets: touch keymap, Estuary touch mode, skiploopfilter
48), compiled with a counter in every function of Kodi and FFmpeg. While you use it, it records which code runs and how
often. The optimized build is then compiled from that record (the "profile"), so the code that really runs on the
tablet gets the optimization: the same method that made Venetium about 50% faster.

It is SLOWER than the normal kit, because the counters cost time: x265 will stutter more. That is expected and does
not spoil anything, because the profile counts what runs, not how fast. Your normal Kodi folder stays as it is.

On the Surface RT:
  1. Unzip into a NEW folder (for example C:\kodi-rt-pgo).
  2. Double-click run-kodi.cmd and use Kodi for 10-15 minutes, the way you normally would. Please include:
       - add your Videos folder as a source (Videos > Files > Add videos);
       - the x265 file (720p 10-bit), fullscreen, about 3 minutes, with a pause and a seek or two;
       - then Settings > Player > Videos > Render method: DXVA, and the x265 file again for a minute or two
         (Kodi's other way of drawing video; you can set it back to Auto afterwards);
       - the 1080p H.264 MKV, about 2 minutes;
       - menus: home screen, Videos, Settings, and the video controls (tap during playback).
     Optional: Aeon Nox: SiLVO, a library scan.
  3. Close Kodi normally: power icon at the top left > Exit. The counts are written when Kodi closes, and also once a
     minute while it runs, so a crash loses at most the last minute.
  4. Zip the newest results folder and send it. Its prof folder holds the counts (a kodi-....profraw file, some MB).

You can run run-kodi.cmd more than once: every run adds to the same counts, and each results folder has the total.
If Kodi doesn't appear, closes by itself, or freezes: run run-kodi-dbgrun.cmd and send that results folder.

Files: kodi\ (the counting kodi.exe, python314.dll, python314._pth, dvdnav.dll, Kodi's data folders with
system\python, and in kodi\portable_data\userdata the presets), bin\dbgrun.exe, run-kodi.cmd, run-kodi-dbgrun.cmd,
MANIFEST.txt (sha256 of every file).
