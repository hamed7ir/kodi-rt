@echo off
rem kodi-rt PGO profiling kit (2026-11-13): the counting Kodi under dbgrun.exe, for when run-kodi.cmd shows no kodi.log
rem or a crash. dbgrun starts kodi.exe -p as a debuggee and, on a fatal exception, writes crash-N.txt (exception,
rem faulting module and offset, module list) and crash-N.dmp (a minidump) into results\dbgrun-kodi. Kodi's own crash
rem dump is not written under a debugger; dbgrun's replaces it. The counts go to the same prof folder as run-kodi.cmd's.
rem It changes nothing outside this folder.
setlocal
set "HERE=%~dp0"
set "APP=%HERE%kodi"
set "PD=%APP%\portable_data"
rem an update zip unpacked into a folder of its own has kodi.exe but none of Kodi's own files
if exist "%APP%\system\settings\settings.xml" goto files_ok
echo Kodi's own files are missing here: there is no kodi\system folder next to kodi.exe.
echo This folder holds an incomplete copy. Unpack the whole kit into a new folder. Nothing was started.
pause
exit /b 1
:files_ok
set "OUT="
if not exist "%HERE%results" set "OUT=%HERE%results"
for /l %%i in (2,1,99) do if not defined OUT if not exist "%HERE%results-%%i" set "OUT=%HERE%results-%%i"
if not defined OUT (echo There is no free name for a results folder. Move the old results folders away first.& pause & exit /b 1)
mkdir "%OUT%"
set "V=%OUT%\VERDICT.txt"
>"%V%" echo kodi-rt PGO profiling kit (counting kodi.exe, update-4 build, rt2.4 0318206a), run-kodi-dbgrun.cmd, 2026-11-13. Started %DATE% %TIME%

rem a log left by an earlier run goes into this results folder first, so any kodi.log found afterwards is this run's
if exist "%PD%\kodi.log" (move /y "%PD%\kodi.log" "%OUT%\previous-run-kodi.log" > nul & >>"%V%" echo note: moved an earlier run's kodi.log to previous-run-kodi.log)
echo [1/3] Starting the counting Kodi under dbgrun. Use it as before; close it if it comes up. This window waits for Kodi.
if not exist "%HERE%prof" mkdir "%HERE%prof"
set "LLVM_PROFILE_FILE=%HERE%prof\kodi-%%m.profraw"
"%HERE%bin\dbgrun.exe" "%OUT%\dbgrun-kodi" "%APP%\kodi.exe" -p
set "RC=%ERRORLEVEL%"
>>"%V%" echo dbgrun exit code %RC% (kodi.exe's exit code; see dbgrun-kodi\dbgrun.txt)
set "NREP=0"
for %%f in ("%OUT%\dbgrun-kodi\crash-*.txt") do set /a NREP+=1 > nul
>>"%V%" echo dbgrun crash reports: %NREP%

echo [2/3] Collecting the counts...
mkdir "%OUT%\prof"
for %%f in ("%HERE%prof\*.profraw") do (
  copy /y "%%~f" "%OUT%\prof\" > nul
  >>"%V%" echo counts: %%~nxf, %%~zf bytes
)

echo [3/3] Collecting Kodi's log...
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
