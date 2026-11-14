void side(int);
int after_catchret(int v) {
  int r = 0;
  try {
    try { throw v; }
    catch (int e) { r = e; }
    side(r);
    throw r + 1;
  } catch (int x) { r = x * 10; }
  return r;
}
