void f(int k);
int g3(int k) {
  try { f(k); }
  catch (int) { return 1; }
  catch (short) { return 2; }
  catch (unsigned char v) { return v; }
  return 0;
}
