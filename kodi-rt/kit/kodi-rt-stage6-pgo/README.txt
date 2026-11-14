kodi-rt Stage 6 PGO kit (2026-11-13): the optimized Kodi, for a NEW folder.

What it is: the Kodi of the clean full kit (update 4: patches 0001-0015, Python, and the presets: touch keymap, Estuary
touch mode, skiploopfilter 48), now compiled with your profile (PGO) and ThinLTO, Kodi and FFmpeg together. Plus one fix
the profile found: for x265, Kodi converted every frame 10-bit YUV -> RGB -> 8-bit YUV (and shifted the colours a
little); now it is a direct 10-to-8-bit conversion with the right colours. Debug logging is off.

Run it on the Surface RT:
  1. Unzip into a NEW folder (for example C:\kodi-rt-pgo-build).
  2. Double-click run-kodi.cmd. Add your Videos folder as a source (Videos > Files > Add videos) and set
     Settings > Player > Videos > Render method: DXVA, as you had it.
  3. In the same run: start the x265 file fullscreen and let it play about 90 seconds without touching the screen.
     Stop it, set Render method back to Auto, and play the x265 file again for about 90 seconds. Then the 1080p H.264
     file for about a minute. Exit Kodi (power icon at the top left > Exit).
  4. Zip the newest results folder and send it, and tell me how x265 looks.
  (run-kodi-profile.cmd does the same with the profiler running next to Kodi, for its first 4 minutes.)

If Kodi doesn't appear, closes by itself, or freezes: run run-kodi-dbgrun.cmd and send that results folder.

Files: kodi\ (kodi.exe, python314.dll, python314._pth, dvdnav.dll, Kodi's data folders with system\python, and in
kodi\portable_data\userdata the presets), bin\dbgrun.exe, bin\rtprof.exe, run-kodi.cmd, run-kodi-profile.cmd,
run-kodi-dbgrun.cmd, MANIFEST.txt (sha256 of every file).
