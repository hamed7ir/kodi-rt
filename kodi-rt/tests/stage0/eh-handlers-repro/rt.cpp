struct E { int code; };
void f();
int g() {
  int code = 0;
  try {
    try { f(); }
    catch (E& e) { e.code += 100; throw; }
  } catch (const E& e) { code = e.code; }
  return code;
}
