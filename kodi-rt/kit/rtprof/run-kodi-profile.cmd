@echo off
rem kodi-rt (2026-11-13): Kodi with the rtprof profiler next to it. rtprof records which of Kodi's threads use the CPU
rem and samples where they are working, while Kodi is busy (playing video). Start this, play the x265 file fullscreen
rem within 30 s, let it play about 90 s without touching the screen, then exit Kodi. It changes nothing outside this folder.
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
if exist "%HERE%bin\rtprof.exe" goto prof_ok
echo bin\rtprof.exe is missing. Nothing was started.
pause
exit /b 1
:prof_ok
set "OUT="
if not exist "%HERE%results" set "OUT=%HERE%results"
for /l %%i in (2,1,99) do if not defined OUT if not exist "%HERE%results-%%i" set "OUT=%HERE%results-%%i"
if not defined OUT (echo There is no free name for a results folder. Move the old results folders away first.& pause & exit /b 1)
mkdir "%OUT%"
set "V=%OUT%\VERDICT.txt"
>"%V%" echo kodi-rt run-kodi-profile.cmd (Kodi + rtprof), 2026-11-13. Started %DATE% %TIME%
>"%OUT%\ver.txt" ver
>>"%OUT%\ver.txt" echo PROCESSOR_IDENTIFIER=%PROCESSOR_IDENTIFIER%
>>"%OUT%\ver.txt" echo NUMBER_OF_PROCESSORS=%NUMBER_OF_PROCESSORS%
if exist "%PD%\kodi.log" (move /y "%PD%\kodi.log" "%OUT%\previous-run-kodi.log" > nul & >>"%V%" echo note: moved an earlier run's kodi.log to previous-run-kodi.log)

echo [1/3] Starting the profiler, then Kodi.
echo       Play the x265 file fullscreen within 30 seconds, let it play about 90 seconds without
echo       touching the screen, then close Kodi: power icon at the top left ^> Exit.
start "rtprof" /b "%HERE%bin\rtprof.exe" kodi.exe 240 "%OUT%\rtprof.txt" 60 > "%OUT%\rtprof-console.txt" 2>&1
start "" /wait "%APP%\kodi.exe" -p
set "RC=%ERRORLEVEL%"
>>"%V%" echo kodi.exe exit code %RC%  (0 = closed normally; -1073741819 = 0xC0000005, an access violation)

echo [2/3] Waiting for the profiler to write its summary...
rem rtprof notices within a second that Kodi has exited; allow up to 30 s
for /l %%i in (1,1,30) do (
  findstr /c:"RTPROF DONE" "%OUT%\rtprof.txt" > nul 2>&1 && goto prof_done
  ping -n 2 127.0.0.1 > nul
)
:prof_done
findstr /c:"RTPROF DONE" "%OUT%\rtprof.txt" > nul 2>&1 && (>>"%V%" echo rtprof: summary written) || (>>"%V%" echo rtprof: NO summary - see rtprof-console.txt)

echo [3/3] Collecting Kodi's log...
if exist "%PD%\kodi.log" (copy /y "%PD%\kodi.log" "%OUT%\" > nul & >>"%V%" echo kodi.log: copied) else (>>"%V%" echo kodi.log: NONE)
set "NCRASH=0"
for %%f in ("%PD%\kodi_crashlog-*.dmp" "%PD%\kodi_stacktrace-*.txt") do (
  move /y "%%~f" "%OUT%\" > nul
  >>"%V%" echo crash file from Kodi: %%~nxf
  set /a NCRASH+=1 > nul
)
>>"%V%" echo crash files from Kodi: %NCRASH%
>>"%V%" echo finished %DATE% %TIME%

echo.
type "%V%"
echo.
echo Done. Zip this folder and send it:
echo   %OUT%
pause
exit /b 0
