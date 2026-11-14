@echo off
rem kodi-rt Stage 6, PGO kit (2026-11-13; PGO + ThinLTO build): Kodi under dbgrun.exe, for when run-kodi.cmd shows no kodi.log or a crash.
rem dbgrun starts kodi.exe -p as a debuggee and, on a fatal exception, writes crash-N.txt (exception, faulting module and
rem offset, module list) and crash-N.dmp (a minidump) into results\dbgrun-kodi. Kodi's own crash dump is not written
rem under a debugger; dbgrun's replaces it. It changes nothing outside this folder.
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
>"%V%" echo kodi-rt stage 6 PGO kit (Kodi+Python, update-4 + filter colourspace fix, PGO + ThinLTO, rt2.4 f6e5f8e0), run-kodi-dbgrun.cmd, 2026-11-13. Started %DATE% %TIME%

rem a log left by an earlier run goes into this results folder first, so any kodi.log found afterwards is this run's
if exist "%PD%\kodi.log" (move /y "%PD%\kodi.log" "%OUT%\previous-run-kodi.log" > nul & >>"%V%" echo note: moved an earlier run's kodi.log to previous-run-kodi.log)
echo [1/2] Starting Kodi under dbgrun. Use it as before; close it if it comes up. This window waits for Kodi.
"%HERE%bin\dbgrun.exe" "%OUT%\dbgrun-kodi" "%APP%\kodi.exe" -p
set "RC=%ERRORLEVEL%"
>>"%V%" echo dbgrun exit code %RC% (kodi.exe's exit code; see dbgrun-kodi\dbgrun.txt)
set "NREP=0"
for %%f in ("%OUT%\dbgrun-kodi\crash-*.txt") do set /a NREP+=1 > nul
>>"%V%" echo dbgrun crash reports: %NREP%

echo [2/2] Collecting Kodi's log...
if exist "%PD%\kodi.log" (copy /y "%PD%\kodi.log" "%OUT%\" > nul & >>"%V%" echo kodi.log: copied) else (>>"%V%" echo kodi.log: NONE)
if exist "%PD%\kodi.old.log" copy /y "%PD%\kodi.old.log" "%OUT%\" > nul
if exist "%PD%" (dir /s /a-d "%PD%" > "%OUT%\portable_data-files.txt" 2>&1)
>>"%V%" echo finished %DATE% %TIME%

echo.
type "%V%"
echo.
echo Done. Zip this folder and send it:
echo   %OUT%
pause
exit /b 0
