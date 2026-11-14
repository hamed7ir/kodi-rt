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
