/* kodi-rt: fstrcmp 0.7.D001 lib/config.h for MSVC-style compilers (clang-cl, Windows ARM32), in place of the one
 * configure generates from lib/config.h.in. Every #undef of config.h.in is answered here: the headers and functions
 * the Microsoft CRT (MSVC 14.44, UCRT headers of SDK 10.0.26100.0) has are defined, the POSIX-only ones are not. */
#ifndef LIB_CONFIG_H
#define LIB_CONFIG_H

/* #undef CONF_SHELL */
#define HAVE_ASSERT_H 1
#define HAVE_CTYPE_H 1
#define HAVE_FCNTL_H 1
/* #undef HAVE_GETOPT_H */
#define HAVE_INTTYPES_H 1
#define HAVE_MEMORY_H 1
/* #undef HAVE_PWD_H */
#define HAVE_SNPRINTF 1
#define HAVE_STDDEF_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRERROR 1
/* #undef HAVE_STRINGS_H */
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
/* #undef HAVE_SYS_TIME_H */
#define HAVE_SYS_TYPES_H 1
/* #undef HAVE_UNISTD_H */
#define HAVE_VSNPRINTF 1
#define HAVE_WCHAR_H 1
/* configure.ac is AC_INIT(install-sh), with no package name or version: configure leaves these empty too */
#define PACKAGE_BUGREPORT ""
#define PACKAGE_NAME ""
#define PACKAGE_STRING ""
#define PACKAGE_TARNAME ""
#define PACKAGE_URL ""
#define PACKAGE_VERSION ""
#define STDC_HEADERS 1
/* #undef _MINIX */
/* #undef _POSIX_1_SOURCE */
/* #undef _POSIX_SOURCE */
/* #undef const */
/* #undef size_t */

/* lib/diffseq.h uses ssize_t, which POSIX gets from <sys/types.h> and the Microsoft CRT doesn't have.
 * (This config.h is private to the fstrcmp build; it isn't installed.) */
#include <stddef.h>
typedef ptrdiff_t ssize_t;

#include <lib/config.messy.h>

#endif /* LIB_CONFIG_H */
