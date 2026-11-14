#include <windows.h>
int direct(volatile int *p) { __try { *p = 1; } __except (EXCEPTION_EXECUTE_HANDLER) { return 1; } return 0; }
