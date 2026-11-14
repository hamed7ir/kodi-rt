@echo off
rem kodi-rt Stage 6, PGO kit (2026-11-13; PGO + ThinLTO build): Kodi on the Surface RT, in portable mode (kodi.exe -p).
rem It starts Kodi, waits for it to close, and copies Kodi's log and any crash dump into a results folder. Everything
rem Kodi writes stays in kodi\portable_data. It changes nothing outside this folder.
setlocal
set "HERE=%~dp0"
set "APP=%HERE%kodi"
set "PD=%APP%\portable_data"
rem an update zip unpacked into a folder of its own has kodi.exe but none of Kodi's own files
if exist "%APP%\system\settings\settings.xml" goto files_ok
echo Kodi's own files are missing here: there is no kodi\system folder next to kodi.exe.
echo This folder holds an update or an incomplete copy. Unpack the full kit into a new folder,
echo or copy an update over the folder of the kit it updates. Nothing was started.
pause
exit /b 1
:files_ok
set "OUT="
if not exist "%HERE%results" set "OUT=%HERE%results"
for /l %%i in (2,1,99) do if not defined OUT if not exist "%HERE%results-%%i" set "OUT=%HERE%results-%%i"
if not defined OUT (echo There is no free name for a results folder. Move the old results folders away first.& pause & exit /b 1)
mkdir "%OUT%"
set "V=%OUT%\VERDICT.txt"
>"%V%" echo kodi-rt stage 6 PGO kit (Kodi+Python, update-4 + filter colourspace fix, PGO + ThinLTO, rt2.4 f6e5f8e0), run-kodi.cmd, 2026-11-13. Started %DATE% %TIME%

echo [1/4] Device information...
>"%OUT%\ver.txt" ver
>>"%OUT%\ver.txt" echo PROCESSOR_ARCHITECTURE=%PROCESSOR_ARCHITECTURE%
>>"%OUT%\ver.txt" echo PROCESSOR_IDENTIFIER=%PROCESSOR_IDENTIFIER%
>>"%OUT%\ver.txt" echo NUMBER_OF_PROCESSORS=%NUMBER_OF_PROCESSORS%

echo [2/4] Checking the system DLLs Kodi needs...
set "NMISS=0"
for %%d in (advapi32.dll avrt.dll bcrypt.dll combase.dll crypt32.dll d3d11.dll d3dcompiler_47.dll dnsapi.dll dsound.dll dwmapi.dll dwrite.dll dxgi.dll gdi32.dll iphlpapi.dll kernel32.dll mpr.dll netapi32.dll ole32.dll oleaut32.dll pdh.dll powrprof.dll setupapi.dll shell32.dll user32.dll winhttp.dll winmm.dll ws2_32.dll wsdapi.dll xaudio2_8.dll) do (
  if not exist "%SystemRoot%\System32\%%d" (>>"%V%" echo system DLL missing: %%d& set /a NMISS+=1 > nul)
)
>>"%V%" echo system DLLs missing: %NMISS%
rem a log left by an earlier run goes into this results folder first, so any kodi.log found afterwards is this run's
if exist "%PD%\kodi.log" (move /y "%PD%\kodi.log" "%OUT%\previous-run-kodi.log" > nul & >>"%V%" echo note: moved an earlier run's kodi.log to previous-run-kodi.log)

echo [3/4] Starting Kodi. Use it (see README.txt), then close it: power icon at the top left ^> Exit.
echo       This window waits until Kodi has closed.
start "" /wait "%APP%\kodi.exe" -p
set "RC=%ERRORLEVEL%"
>>"%V%" echo kodi.exe exit code %RC%  (0 = closed normally; -1073741819 = 0xC0000005, an access violation)

echo [4/4] Collecting Kodi's log...
if exist "%PD%\kodi.log" (copy /y "%PD%\kodi.log" "%OUT%\" > nul & >>"%V%" echo kodi.log: copied) else (>>"%V%" echo kodi.log: NONE - Kodi stopped before it started logging. Run run-kodi-dbgrun.cmd next.)
if exist "%PD%\kodi.old.log" copy /y "%PD%\kodi.old.log" "%OUT%\" > nul
set "NCRASH=0"
for %%f in ("%PD%\kodi_crashlog-*.dmp" "%PD%\kodi_stacktrace-*.txt") do (
  move /y "%%~f" "%OUT%\" > nul
  >>"%V%" echo crash file from Kodi: %%~nxf
  set /a NCRASH+=1 > nul
)
>>"%V%" echo crash files from Kodi: %NCRASH%
if exist "%PD%" (dir /s /a-d "%PD%" > "%OUT%\portable_data-files.txt" 2>&1)
>>"%V%" echo finished %DATE% %TIME%

echo.
type "%V%"
echo.
echo Done. Zip this folder, add your screenshots and notes, and send it:
echo   %OUT%
pause
exit /b 0
