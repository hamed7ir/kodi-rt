struct E { int code; };
void f(int v) { if (v) throw E{v}; }
int g(int v) { try { f(v); } catch (E& e) { return e.code; } return 0; }
