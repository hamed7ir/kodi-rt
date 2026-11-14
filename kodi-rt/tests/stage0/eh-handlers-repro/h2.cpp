void f(int k);
int g(int k) {
  try { f(k); }
  catch (int) { return 1; }
  catch (unsigned char v) { return v; }
  return 0;
}
