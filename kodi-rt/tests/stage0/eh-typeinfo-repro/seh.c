#include <windows.h>
void g(void);
int seh(void) { __try { g(); } __except (EXCEPTION_EXECUTE_HANDLER) { return 1; } return 0; }
