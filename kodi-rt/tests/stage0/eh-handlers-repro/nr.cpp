[[noreturn]] void die(int);
int f(int x) { if (x > 7) die(x); return x * 3; }
void g(int x) { die(x + 1); }
