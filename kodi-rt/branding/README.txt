kodi-rt branding, made from Kodi's own files at bffa625c (Hamed, 2026-11-13: "the version in splash screen is 22.00
which is false, also make the icon purple not blue"):
  application.ico  tools/windows/packaging/media/application.ico (kodi.exe's icon) with every hue turned by 85 degrees:
                   the blue logo becomes purple, white and grey stay. Also the installer's icon (installer/kodi.ico).
                   python -I scripts/s9-recolor-icon.py <kodi's application.ico> application.ico 85
  splash.jpg       media/splash.jpg, Kodi 22's "Piers" RC artwork that master still ships: the banner says
                   "v. 23.0 - ALPHA 1" (Kodi's version in version.txt) instead of "v. 22.0 - RC", and "PIERS" (22's
                   codename) is no longer lit up among the names.
                   powershell -NoProfile -File scripts\s9-splash.ps1 -In <kodi's splash.jpg> -Out splash.jpg
They go into the Kodi tree as the fork's branding commit (release-docs/fork/series.tsv).
  poster-v1.0.png  the README poster (2880x1200), Venetium's poster layout in purple: branding/poster/poster.html
                   rendered by scripts/s9-poster.ps1 (headless Chrome at 1.5x). Its Kodi screenshots are Kodi's own
                   (tests/s9/poster-shots.ps1, Estuary's violet colour theme); the 1080p numbers are Hamed's, from the
                   Surface RT.
  vendor_logo.png  media/vendor_logo.png (the Kodi logo on Estuary's home and login screens), hue +85 like the icon:
                   powershell -NoProfile -File scripts\s9-recolor-png.ps1 -In <kodi's vendor_logo.png> -Out vendor_logo.png
                   (fork commit 0021, with Estuary's violet colour theme as the default: violet-default-theme.py)
  osd/             the video OSD's fullscreen/window icons (scripts/s9-osd-icons.ps1), in Estuary's OSD icon style
                   (fork commit 0020, with osd-fullscreen-icons.py)
