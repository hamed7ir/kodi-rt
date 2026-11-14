/* kodi-rt: fficonfig.h for libffi 3.5.2 on Windows (ARM32, x86, x64), built by cross/cmake/libffi with clang-cl and
   the MSVC assemblers (armasm, ml, ml64), as libffi's msvcc.sh and CPython's PCbuild/prepare_libffi.bat do.
   Written by hand: libffi's configure needs a POSIX shell with msvcc.sh. Only the macros that the Windows sources
   (prep_cif.c, types.c, raw_api.c, java_raw_api.c, closures.c, tramp.c, arm/ffi.c, x86/ffi.c, x86/ffiw64.c and
   their assembly) look at are set. No static trampolines (FFI_EXEC_STATIC_TRAMP is Linux/Cygwin only), no CFI
   (MASM/armasm have none), long double == double. */

#define PACKAGE "libffi"
#define PACKAGE_NAME "libffi"
#define PACKAGE_TARNAME "libffi"
#define PACKAGE_VERSION "3.5.2"
#define PACKAGE_STRING "libffi 3.5.2"
#define VERSION "3.5.2"

#define STDC_HEADERS 1
#define HAVE_MEMCPY 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_ALLOCA 1

#define SIZEOF_DOUBLE 8
#define SIZEOF_LONG_DOUBLE 8
#if defined(_WIN64)
# define SIZEOF_SIZE_T 8
#else
# define SIZEOF_SIZE_T 4
#endif

/* 32-bit x86 COFF prefixes C names with an underscore */
#if defined(_M_IX86)
# define SYMBOL_UNDERSCORE 1
#endif

#define EH_FRAME_FLAGS "a"

#ifdef LIBFFI_ASM
# define FFI_HIDDEN(name)
#else
# define FFI_HIDDEN
#endif
