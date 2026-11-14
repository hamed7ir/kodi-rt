@echo off
rem kodi-rt Stage 3: OpenSSL 3.5.7 (Kodi's pin) for desktop Windows ARM32, static, rt2.4, into F:\kodi-rt\prefix\arm32.
rem Options as Kodi's depends (tools/depends/target/openssl/Makefile): no-shared zlib no-tests no-asm no-module, with
rem the prefix's zlib. Target: cross\openssl-arm32.conf (desktop, not OpenSSL's OneCore VC-WIN32-ARM). Out-of-tree build.
rem The target name must start with "VC-": apps\lib\build.info adds win32_init.c (win32_utf8argv) only for
rem targets matching ^(VC-|mingw|BC-), and openssl.exe does not link without it (measured).
rem Perl: Strawberry Perl 5.42.3.1 portable (native Windows perl, as OpenSSL's NOTES-WINDOWS asks for VC targets).
rem nmake builds serially. install_sw installs libraries and headers only (nothing into OPENSSLDIR).
rem Run detached: powershell -File scripts\launch-detached.ps1 -Shell cmd -Script F:\kodi-rt\scripts\s3-openssl-arm32.cmd
setlocal
call :main > F:\kodi-rt\logs\s3-openssl-arm32.log 2>&1
exit /b %ERRORLEVEL%

:main
echo start %DATE% %TIME%
set "PATH=F:\kodi-rt\tools\strawberry-perl\perl\bin;D:\Program Files\vs22buildtools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64;%SystemRoot%\system32;%SystemRoot%"
set "SRC=F:\kodi-rt\src\deps\openssl-3.5.7"
set "B=F:\kodi-rt\build\s3\openssl-arm32"
set "PFX=F:\kodi-rt\prefix\arm32"
perl -v | findstr /c:"This is perl"
"F:\kodi-rt\tc\rt24b-cr\bin\clang-cl.exe" --version | findstr /c:"clang version"
if exist "%B%" rmdir /s /q "%B%"
mkdir "%B%"
cd /d "%B%" || exit /b 1
perl "%SRC%\Configure" VC-WIN32-ARM-kodirt --config=F:\kodi-rt\cross\openssl-arm32.conf ^
  no-shared zlib --with-zlib-include=F:/kodi-rt/prefix/arm32/include --with-zlib-lib=F:/kodi-rt/prefix/arm32/lib/z.lib ^
  no-tests no-asm no-module --prefix=%PFX% --libdir=lib
if errorlevel 1 (echo CONFIGURE FAILED& exit /b 1)
perl configdata.pm -d | findstr /i /c:"CC " /c:"CFLAGS" /c:"LDFLAGS" /c:"defines" /c:"ex_libs" /c:"bn_ops"
echo === nmake %TIME%
nmake /nologo > F:\kodi-rt\logs\s3-openssl-arm32-nmake.log 2>&1
if errorlevel 1 (echo NMAKE FAILED: see F:\kodi-rt\logs\s3-openssl-arm32-nmake.log& exit /b 1)
rem install_sw copies ossl_static.pdb, which clang-cl never writes (it ignores /Fd: the debug info stays in the
rem objects). An empty placeholder lets install_sw finish (2026-11-12 this was done by hand); it is removed from
rem the prefix afterwards.
type nul > ossl_static.pdb
echo === nmake install_sw %TIME%
nmake /nologo install_sw > F:\kodi-rt\logs\s3-openssl-arm32-install.log 2>&1
if errorlevel 1 (echo INSTALL FAILED: see F:\kodi-rt\logs\s3-openssl-arm32-install.log& exit /b 1)
if exist "%PFX%\lib\ossl_static.pdb" del /q "%PFX%\lib\ossl_static.pdb"
dir /b "%PFX%\lib\libcrypto*.lib" "%PFX%\lib\libssl*.lib"
echo OPENSSL DONE %DATE% %TIME%
exit /b 0
