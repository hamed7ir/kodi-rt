@echo off
rem kodi-rt Stage 3: OpenSSL 3.5.7 (Kodi's pin) for desktop Windows x64 or x86, static, rt2.4 f6e5f8e0, into
rem F:\kodi-rt\prefix\<arch>. The x86 twin of s3-openssl-arm32.cmd (see its comments): Kodi's depends options
rem (no-shared zlib no-tests no-asm no-module) with the prefix's zlib, target from cross\openssl-<arch>.conf
rem (OpenSSL's own VC-WIN64A / VC-WIN32 with rt2.4's clang-cl, lld-link and llvm-lib). no-asm as in Kodi's depends;
rem OpenSSL's x86 assembly would also need nasm, which is not on this server.
rem Usage: s3-openssl.cmd x64   or   s3-openssl.cmd x86
rem Run detached: powershell -File scripts\launch-detached.ps1 -Shell cmd -Script "F:\kodi-rt\scripts\s3-openssl.cmd x64"
setlocal
set "ARCH=%~1"
if "%ARCH%"=="x64" (set "TARGET=VC-WIN64A-kodirt") else if "%ARCH%"=="x86" (set "TARGET=VC-WIN32-kodirt") else (
  echo usage: s3-openssl.cmd x64^|x86
  exit /b 2
)
call :main > F:\kodi-rt\logs\s3-%ARCH%-openssl.log 2>&1
exit /b %ERRORLEVEL%

:main
echo start %DATE% %TIME% (%ARCH%, %TARGET%)
set "PATH=F:\kodi-rt\tools\strawberry-perl\perl\bin;D:\Program Files\vs22buildtools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64;%SystemRoot%\system32;%SystemRoot%"
set "SRC=F:\kodi-rt\src\deps\openssl-3.5.7"
set "B=F:\kodi-rt\build\s3-%ARCH%\openssl"
set "PFX=F:\kodi-rt\prefix\%ARCH%"
perl -v | findstr /c:"This is perl"
"F:\kodi-rt\tc\rt24d-cr\bin\clang-cl.exe" --version | findstr /c:"clang version"
if exist "%B%" rmdir /s /q "%B%"
mkdir "%B%"
cd /d "%B%" || exit /b 1
perl "%SRC%\Configure" %TARGET% --config=F:\kodi-rt\cross\openssl-%ARCH%.conf ^
  no-shared zlib --with-zlib-include=F:/kodi-rt/prefix/%ARCH%/include --with-zlib-lib=F:/kodi-rt/prefix/%ARCH%/lib/z.lib ^
  no-tests no-asm no-module --prefix=%PFX% --libdir=lib
if errorlevel 1 (echo CONFIGURE FAILED& exit /b 1)
perl configdata.pm -d | findstr /i /c:"CC " /c:"CFLAGS" /c:"LDFLAGS" /c:"defines" /c:"ex_libs" /c:"bn_ops"
echo === nmake %TIME%
nmake /nologo > F:\kodi-rt\logs\s3-%ARCH%-openssl-nmake.log 2>&1
if errorlevel 1 (echo NMAKE FAILED: see F:\kodi-rt\logs\s3-%ARCH%-openssl-nmake.log& exit /b 1)
rem install_sw copies ossl_static.pdb, which clang-cl never writes (it ignores /Fd: the debug info stays in the
rem objects). An empty placeholder lets install_sw finish (the ARM32 install was finished the same way, by hand);
rem it is removed from the prefix afterwards.
type nul > ossl_static.pdb
echo === nmake install_sw %TIME%
nmake /nologo install_sw > F:\kodi-rt\logs\s3-%ARCH%-openssl-install.log 2>&1
if errorlevel 1 (echo INSTALL FAILED: see F:\kodi-rt\logs\s3-%ARCH%-openssl-install.log& exit /b 1)
if exist "%PFX%\lib\ossl_static.pdb" del /q "%PFX%\lib\ossl_static.pdb"
dir /b "%PFX%\lib\libcrypto*.lib" "%PFX%\lib\libssl*.lib"
echo OPENSSL DONE %DATE% %TIME%
exit /b 0
