#include <stddef.h>
int sz_wchar = (int)sizeof(wchar_t);
#ifdef __ARM_SIZEOF_WCHAR_T
int acle_wchar = __ARM_SIZEOF_WCHAR_T;
_Static_assert(sizeof(wchar_t) == __ARM_SIZEOF_WCHAR_T, "__ARM_SIZEOF_WCHAR_T disagrees with sizeof(wchar_t)");
#endif
