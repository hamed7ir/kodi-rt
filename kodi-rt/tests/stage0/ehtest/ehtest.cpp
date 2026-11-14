// ehtest -- kodi-rt Stage 0: C++ exceptions (and SEH, integer division, float conversions) on ARM32 Windows with rt2.2.
//
// Built the way Kodi builds C++ on Windows (cmake/scripts/windows/CXXFlagOverrides.cmake at xbmc bffa625c):
// /EHsc /GR /W3 /Zi /utf-8, Release /Ox /Ob2 /Oi /Ot /Oy, C++20 -- with /MT instead of /MD and without /GL.
//
// stdout is deterministic: the ARM32 build must print exactly what the x86 builds print (byte for byte).
// stderr gets the build identity only. Exit code = number of failed checks.
// --selftest-fail makes check T01 expect a wrong value, so it must print FAIL and exit 1 (proves the harness can fail).
// --child-noexcept is used internally by T40 (a child copy of this program that must end in std::terminate).

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <atomic>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <functional>
#include <future>
#include <map>
#include <memory>
#include <new>
#include <optional>
#include <regex>
#include <stdexcept>
#include <string>
#include <thread>
#include <typeinfo>
#include <variant>
#include <vector>

#define NOINLINE __declspec(noinline)

// ---------------------------------------------------------------- harness
static int g_checks = 0, g_failed = 0;
static bool g_selftest_fail = false;

static void check(const char* id, bool ok, const char* fmt, ...)
{
  ++g_checks;
  if (!ok)
    ++g_failed;
  std::printf("%s %s ", id, ok ? "OK  " : "FAIL");
  va_list ap;
  va_start(ap, fmt);
  std::vprintf(fmt, ap);
  va_end(ap);
  std::printf("\n");
  std::fflush(stdout);
}

// ---------------------------------------------------------------- types
struct MyError
{
  int code;
  explicit MyError(int c) : code(c) {}
};
struct Base
{
  virtual ~Base() = default;
  virtual const char* name() const { return "Base"; }
};
struct Derived : Base
{
  const char* name() const override { return "Derived"; }
};
struct Other : Base
{
  const char* name() const override { return "Other"; }
};

static std::string g_trace;
struct Guard
{
  char tag;
  explicit Guard(char t) : tag(t) {}
  ~Guard() { g_trace += tag; }
};

static std::atomic<int> g_live{0};
struct Tracked
{
  int v;
  explicit Tracked(int x) : v(x) { ++g_live; }
  Tracked(const Tracked& o) : v(o.v) { ++g_live; }
  ~Tracked() { --g_live; }
};

struct Payload // 8-byte members: ARM32 faults (0x80000002) on a misaligned double/int64 access
{
  char c;
  double d;
  long long ll;
  int tail;
};

// ---------------------------------------------------------------- throwers (real frames)
NOINLINE static void thrower(int kind)
{
  Guard g('t');
  switch (kind)
  {
    case 0: throw MyError(7);
    case 1: throw 1234;
    case 2: throw Derived();
    case 3: throw std::runtime_error("runtime-error-text");
    case 4: throw "string-literal";
    case 5: throw std::string(100, 'x');
    case 6:
    {
      Payload p;
      p.c = 'p';
      p.d = 3.25;
      p.ll = 0x123456789ABCDEF0LL;
      p.tail = -5;
      throw p;
    }
    case 7: throw static_cast<unsigned char>(200);
    case 8: throw Tracked(3);
    default: break;
  }
}
NOINLINE static void mid2(int kind)
{
  Guard g('b');
  thrower(kind);
}
NOINLINE static void mid1(int kind)
{
  Guard g('a');
  mid2(kind);
}

NOINLINE static void f3(int v)
{
  Guard g('3');
  if (v >= 0)
    throw MyError(v);
}
NOINLINE static void f2(int v)
{
  Guard g('2');
  f3(v);
}
NOINLINE static void f1(int v)
{
  Guard g('1');
  f2(v);
}

// ---------------------------------------------------------------- C++ exception tests
static void test_basic()
{
  int got = -1;
  std::string at_catch;
  g_trace.clear();
  try
  {
    Guard g('m');
    f1(42);
  }
  catch (const MyError& e)
  {
    got = e.code;
    at_catch = g_trace;
  }
  const int want = g_selftest_fail ? 43 : 42;
  check("T01", got == want, "throw 3 frames down, catch by type: code=%d", got);
  check("T02", at_catch == "321m", "destructors ran during unwinding, innermost first, before the handler: '%s'",
        at_catch.c_str());

  bool caught = false;
  g_trace.clear();
  try
  {
    mid1(1);
  }
  catch (...)
  {
    caught = true;
  }
  check("T03", caught && g_trace == "tba", "catch (...) of an int thrown 3 frames down; trace '%s'", g_trace.c_str());

  int iv = 0;
  try
  {
    mid1(1);
  }
  catch (int v)
  {
    iv = v;
  }
  check("T04", iv == 1234, "catch (int) by value: %d", iv);

  const char* nm = "none";
  try
  {
    mid1(2);
  }
  catch (const Base& b)
  {
    nm = b.name();
  }
  check("T05", std::strcmp(nm, "Derived") == 0, "catch derived by base reference, virtual call on it: %s", nm);

  std::string w;
  try
  {
    mid1(3);
  }
  catch (const std::exception& e)
  {
    w = e.what();
  }
  check("T06", w == "runtime-error-text", "std::runtime_error caught as std::exception&: what()='%s'", w.c_str());

  const char* lit = nullptr;
  try
  {
    mid1(4);
  }
  catch (const char* s)
  {
    lit = s;
  }
  check("T07", lit && std::strcmp(lit, "string-literal") == 0, "catch (const char*): '%s'", lit ? lit : "(null)");

  size_t len = 0;
  bool allx = false;
  try
  {
    mid1(5);
  }
  catch (const std::string& s)
  {
    len = s.size();
    allx = s.find_first_not_of('x') == std::string::npos;
  }
  check("T08", len == 100 && allx, "catch (const std::string&) of a heap string: size=%u allx=%d", (unsigned)len,
        (int)allx);

  bool pok = false, aligned = false;
  double pd = 0;
  long long pll = 0;
  int ptail = 0;
  try
  {
    mid1(6);
  }
  catch (const Payload& p)
  {
    pd = p.d;
    pll = p.ll;
    ptail = p.tail;
    // ARMv7 LDRD/VLDR need 4-byte alignment; MSVC x86 places the object only 4-byte aligned (measured), so 4 it is
    aligned = (reinterpret_cast<uintptr_t>(&p.d) % 4 == 0) && (reinterpret_cast<uintptr_t>(&p.ll) % 4 == 0);
    pok = p.c == 'p';
  }
  check("T09", pok && pd == 3.25 && pll == 0x123456789ABCDEF0LL && ptail == -5 && aligned,
        "struct with double+int64 payload: d=%.2f ll=%llx tail=%d aligned4=%s", pd, (unsigned long long)pll, ptail,
        aligned ? "yes" : "NO");

  int which = 0;
  try
  {
    mid1(7);
  }
  catch (int)
  {
    which = 1;
  }
  catch (unsigned char v)
  {
    which = (v == 200) ? 2 : 3;
  }
  check("T10", which == 2, "exact type match: unsigned char not caught by catch (int): handler %d", which);

  which = 0;
  try
  {
    mid1(2);
  }
  catch (const Derived&)
  {
    which = 1;
  }
  catch (const Base&)
  {
    which = 2;
  }
  check("T11", which == 1, "first matching handler wins (Derived before Base): handler %d", which);
}

static void test_rethrow()
{
  int code = 0;
  try
  {
    try
    {
      mid1(0);
    }
    catch (MyError& e)
    {
      e.code += 100;
      throw;
    }
  }
  catch (const MyError& e)
  {
    code = e.code;
  }
  check("T12", code == 107, "throw; rethrows the same object (modified in the inner handler): code=%d", code);

  code = 0;
  try
  {
    try
    {
      mid1(0);
    }
    catch (...)
    {
      throw;
    }
  }
  catch (const MyError& e)
  {
    code = e.code;
  }
  check("T13", code == 7, "rethrow from catch (...), caught by type outside: code=%d", code);

  std::string w;
  int live_after = -1;
  try
  {
    try
    {
      mid1(8);
    }
    catch (const Tracked&)
    {
      throw std::logic_error("replaced");
    }
  }
  catch (const std::logic_error& e)
  {
    w = e.what();
    live_after = g_live.load();
  }
  check("T14", w == "replaced" && live_after == 0,
        "new exception thrown from a handler replaces the first; first destroyed: what='%s' live=%d", w.c_str(),
        live_after);

  int inner = 0, outer = 0;
  try
  {
    mid1(0);
  }
  catch (const MyError& e)
  {
    try
    {
      throw 5;
    }
    catch (int x)
    {
      inner = x;
    }
    outer = e.code;
  }
  check("T15", inner == 5 && outer == 7, "try/catch nested inside a handler: inner=%d outer=%d", inner, outer);
}

static void test_lifetime()
{
  int val = 0;
  bool inside = false;
  try
  {
    mid1(8);
  }
  catch (const Tracked& t)
  {
    val = t.v;
    inside = g_live.load() >= 1;
  }
  check("T16", val == 3 && inside && g_live.load() == 0,
        "exception object alive in the handler, destroyed after it: v=%d live=%d", val, g_live.load());

  val = 0;
  try
  {
    mid1(8);
  }
  catch (Tracked t)
  {
    val = t.v;
  }
  check("T17", val == 3 && g_live.load() == 0, "catch by value (copy) then both destroyed: v=%d live=%d", val,
        g_live.load());

  std::exception_ptr p;
  try
  {
    mid1(8);
  }
  catch (...)
  {
    p = std::current_exception();
  }
  const int held = g_live.load();
  int got = 0;
  try
  {
    std::rethrow_exception(p);
  }
  catch (const Tracked& t)
  {
    got = t.v;
  }
  p = nullptr;
  check("T18", got == 3 && held >= 1 && g_live.load() == 0,
        "std::exception_ptr keeps the object alive, rethrow_exception works, then released: got=%d held=%s live=%d",
        got, held >= 1 ? ">=1" : "0", g_live.load());

  struct UncaughtProbe
  {
    int* out;
    ~UncaughtProbe() { *out = std::uncaught_exceptions(); }
  };
  int during = -1, normal = -1;
  try
  {
    UncaughtProbe u{&during};
    throw 1;
  }
  catch (int)
  {
  }
  {
    UncaughtProbe u{&normal};
  }
  check("T19", during == 1 && normal == 0, "std::uncaught_exceptions() in a destructor: unwinding=%d normal=%d",
        during, normal);

  {
    struct Thrower
    {
      Thrower() { throw MyError(55); }
    };
    struct Holder
    {
      Guard a{'A'};
      Thrower b;
      Guard c{'C'};
    };
    g_trace.clear();
    int c2 = 0;
    try
    {
      Holder h;
      (void)h;
    }
    catch (const MyError& e)
    {
      c2 = e.code;
    }
    check("T20", c2 == 55 && g_trace == "A",
          "constructor throws: built members destroyed, later ones never built: trace='%s'", g_trace.c_str());
  }
}

static int g_elem_ctor = 0, g_elem_dtor = 0, g_arr_new = 0, g_arr_del = 0;
struct Elem
{
  Elem()
  {
    if (g_elem_ctor == 3)
      throw MyError(3);
    ++g_elem_ctor;
  }
  ~Elem() { ++g_elem_dtor; }
  static void* operator new[](size_t n)
  {
    ++g_arr_new;
    return ::operator new(n);
  }
  static void operator delete[](void* p)
  {
    ++g_arr_del;
    ::operator delete(p);
  }
};

static int g_deep_dtors = 0;
struct DeepGuard
{
  ~DeepGuard() { ++g_deep_dtors; }
};
NOINLINE static int deep(int n)
{
  DeepGuard g;
  volatile char pad[64];
  pad[0] = static_cast<char>(n);
  if (n == 0)
    throw MyError(0);
  return deep(n - 1) + pad[0];
}

struct Runner
{
  virtual ~Runner() = default;
  virtual int run(const std::function<int(int)>& f, int x) { return f(x) + 1; }
};
struct Runner2 : Runner
{
  int run(const std::function<int(int)>& f, int x) override { return Runner::run(f, x) + 1; }
};
NOINLINE static int via_pointer(int x)
{
  if (x > 0)
    throw MyError(x);
  return x;
}

static void test_frames()
{
  int code = 0;
  try
  {
    Elem* e = new Elem[6];
    delete[] e;
  }
  catch (const MyError& er)
  {
    code = er.code;
  }
  check("T21", code == 3 && g_elem_ctor == 3 && g_elem_dtor == 3 && g_arr_new == 1 && g_arr_del == 1,
        "new T[6] whose 4th constructor throws: ctor=%d dtor=%d new[]=%d delete[]=%d", g_elem_ctor, g_elem_dtor,
        g_arr_new, g_arr_del);

  code = -1;
  try
  {
    deep(200);
  }
  catch (const MyError& e)
  {
    code = e.code;
  }
  check("T22", code == 0 && g_deep_dtors == 201, "throw from 200 recursive frames: destructors=%d", g_deep_dtors);

  code = 0;
  std::unique_ptr<Runner> r(new Runner2);
  std::function<int(int)> fn = [](int x) -> int {
    Guard g('L');
    if (x > 0)
      throw MyError(x);
    return x;
  };
  g_trace.clear();
  try
  {
    r->run(fn, 77);
  }
  catch (const MyError& e)
  {
    code = e.code;
  }
  check("T23", code == 77 && g_trace == "L", "through a lambda in std::function called by a virtual method: code=%d",
        code);

  code = 0;
  int (*volatile fp)(int) = &via_pointer;
  try
  {
    fp(5);
  }
  catch (const MyError& e)
  {
    code = e.code;
  }
  check("T24", code == 5, "through a call via a function pointer: code=%d", code);

  int live_in = -1;
  try
  {
    std::unique_ptr<Tracked> u(new Tracked(1));
    std::shared_ptr<Tracked> s = std::make_shared<Tracked>(2);
    live_in = g_live.load();
    f1(9);
  }
  catch (const MyError&)
  {
  }
  check("T25", live_in == 2 && g_live.load() == 0, "unique_ptr and shared_ptr released during unwinding: live=%d",
        g_live.load());
}

static void* volatile g_escape = nullptr; // keeps the optimizer from removing a new/delete pair (C++14 allows it)

template <class F>
static std::string catch_what(F f, const char* want_type, bool& typed)
{
  typed = false;
  try
  {
    f();
  }
  catch (const std::exception& e)
  {
    const std::string tn = want_type;
    if (tn == "invalid_argument")
      typed = dynamic_cast<const std::invalid_argument*>(&e) != nullptr;
    else if (tn == "out_of_range")
      typed = dynamic_cast<const std::out_of_range*>(&e) != nullptr;
    else if (tn == "bad_alloc")
      typed = dynamic_cast<const std::bad_alloc*>(&e) != nullptr;
    else if (tn == "bad_array_new_length")
      typed = dynamic_cast<const std::bad_array_new_length*>(&e) != nullptr;
    else if (tn == "bad_cast")
      typed = dynamic_cast<const std::bad_cast*>(&e) != nullptr;
    else if (tn == "bad_typeid")
      typed = dynamic_cast<const std::bad_typeid*>(&e) != nullptr;
    else if (tn == "bad_function_call")
      typed = dynamic_cast<const std::bad_function_call*>(&e) != nullptr;
    else if (tn == "bad_optional_access")
      typed = dynamic_cast<const std::bad_optional_access*>(&e) != nullptr;
    else if (tn == "bad_variant_access")
      typed = dynamic_cast<const std::bad_variant_access*>(&e) != nullptr;
    else if (tn == "regex_error")
      typed = dynamic_cast<const std::regex_error*>(&e) != nullptr;
    else if (tn == "logic_error")
      typed = dynamic_cast<const std::logic_error*>(&e) != nullptr;
    return e.what();
  }
  catch (...)
  {
    return "(not a std::exception)";
  }
  return "(nothing thrown)";
}

static void test_stl()
{
  bool t = false;
  std::string w;
  volatile int sink = 0;

  // the precise handler types first (the handoff's item), then what() through the hierarchy
  bool exact = false;
  try
  {
    sink = std::stoi("x");
  }
  catch (const std::invalid_argument&)
  {
    exact = true;
  }
  check("T26", exact, "std::stoi(\"x\") from the static C++ library caught as std::invalid_argument");

  w = catch_what([&] { sink = std::stoi("x"); }, "invalid_argument", t);
  check("T27", t, "std::stoi(\"x\"): what()='%s'", w.c_str());
  w = catch_what([&] { sink = std::stoi("99999999999"); }, "out_of_range", t);
  check("T28", t, "std::stoi(\"99999999999\"): out_of_range, what()='%s'", w.c_str());
  w = catch_what([&] { sink = static_cast<int>(std::stod("abc")); }, "invalid_argument", t);
  check("T29", t, "std::stod(\"abc\"): invalid_argument, what()='%s'", w.c_str());
  w = catch_what([&] { std::vector<int> v(3); sink = v.at(10); }, "out_of_range", t);
  check("T30", t, "vector::at(10): out_of_range, what()='%s'", w.c_str());
  w = catch_what([&] { std::string s("abc"); sink = static_cast<int>(s.substr(5).size()); }, "out_of_range", t);
  check("T31", t, "string::substr(5): out_of_range, what()='%s'", w.c_str());
  w = catch_what([&] { std::map<int, int> m; sink = m.at(1); }, "out_of_range", t);
  check("T32", t, "map::at: out_of_range, what()='%s'", w.c_str());
  w = catch_what(
      [&] {
        volatile size_t n = static_cast<size_t>(0xFFFFF000u);
        char* p = new char[n];
        g_escape = p;
        delete[] p;
      },
      "bad_alloc", t);
  check("T33", t, "new char[0xFFFFF000]: bad_alloc, what()='%s'", w.c_str());
  // clang-cl passes SIZE_MAX to operator new (bad_alloc), MSVC throws bad_array_new_length (derived from bad_alloc):
  // check the base only and print no what(), so both compilers give the same line.
  w = catch_what(
      [&] {
        volatile int n = -1;
        int* p = new int[n];
        g_escape = p;
        delete[] p;
      },
      "bad_alloc", t);
  check("T34", t, "new int[-1] throws a std::bad_alloc (or derived)");
  w = catch_what(
      [&] {
        Other o;
        Base& b = o;
        Derived& d = dynamic_cast<Derived&>(b);
        sink = static_cast<int>(std::strlen(d.name()));
      },
      "bad_cast", t);
  check("T35", t, "dynamic_cast to a wrong reference type: bad_cast, what()='%s'", w.c_str());
  w = catch_what(
      [&] {
        Base* volatile p = nullptr;
        sink = static_cast<int>(std::strlen(typeid(*p).name()));
      },
      "bad_typeid", t);
  check("T36", t, "typeid(*nullptr): bad_typeid, what()='%s'", w.c_str());
  w = catch_what(
      [&] {
        std::function<int()> empty;
        sink = empty();
      },
      "bad_function_call", t);
  check("T37", t, "calling an empty std::function: bad_function_call, what()='%s'", w.c_str());
  w = catch_what(
      [&] {
        std::optional<int> o;
        sink = o.value();
      },
      "bad_optional_access", t);
  check("T38", t, "empty optional::value(): bad_optional_access, what()='%s'", w.c_str());
  w = catch_what(
      [&] {
        std::variant<int, float> v = 1.5f;
        sink = std::get<int>(v);
      },
      "bad_variant_access", t);
  check("T39", t, "std::get on the wrong variant alternative: bad_variant_access, what()='%s'", w.c_str());
}

static void test_regex()
{
  volatile int sink = 0;
  bool rx = false;
  int rcode = -1;
  try
  {
    std::regex re("(");
    sink = static_cast<int>(re.mark_count());
  }
  catch (const std::regex_error& e)
  {
    rx = true;
    rcode = static_cast<int>(e.code());
  }
  check("T41", rx && rcode == static_cast<int>(std::regex_constants::error_paren),
        "std::regex(\"(\"): regex_error, code=%d (error_paren=%d)", rcode,
        static_cast<int>(std::regex_constants::error_paren));
  bool rmatch = std::regex_match(std::string("kodi-23.0"), std::regex("([a-z]+)-([0-9]+)\\.([0-9]+)"));
  check("T42", rmatch, "std::regex_match works (no exception on a valid pattern)");
}

static void test_threads()
{
  std::string w;
  try
  {
    auto fut = std::async(std::launch::async, []() -> int {
      Guard g('X');
      throw std::logic_error("async-thrown");
    });
    (void)fut.get();
  }
  catch (const std::logic_error& e)
  {
    w = e.what();
  }
  check("T43", w == "async-thrown", "exception thrown in a std::async thread, rethrown by future::get(): '%s'",
        w.c_str());

  std::atomic<long> sum{0};
  std::atomic<int> caught{0};
  std::vector<std::thread> ts;
  for (int k = 0; k < 4; ++k)
    ts.emplace_back([k, &sum, &caught] {
      for (int i = 0; i < 2000; ++i)
      {
        try
        {
          if ((i & 1) == 0)
            throw Tracked(k * 10000 + i);
          else
            throw MyError(i);
        }
        catch (const Tracked& t)
        {
          sum += t.v;
          ++caught;
        }
        catch (const MyError& e)
        {
          sum += e.code;
          ++caught;
        }
      }
    });
  for (auto& th : ts)
    th.join();
  // sum over k of [ sum_{even i} (k*10000+i) + sum_{odd i} i ] = 4 * (0+1+...+1999) + 1000 * 10000 * (0+1+2+3)
  const long want = 4L * (1999L * 2000L / 2) + 1000L * 10000L * 6L;
  check("T44", caught.load() == 8000 && sum.load() == want && g_live.load() == 0,
        "4 threads x 2000 throw/catch each at once: caught=%d sum=%ld (want %ld) live=%d", caught.load(), sum.load(),
        want, g_live.load());
}

// ---------------------------------------------------------------- noexcept -> std::terminate (in a child process)
NOINLINE static void throws_inside_noexcept() noexcept
{
  volatile int k = 1;
  if (k)
    throw MyError(1);
}

static int run_child_noexcept()
{
  wchar_t self[MAX_PATH];
  if (!GetModuleFileNameW(nullptr, self, MAX_PATH))
    return -1;
  std::wstring cmd = L"\"";
  cmd += self;
  cmd += L"\" --child-noexcept";
  std::vector<wchar_t> buf(cmd.begin(), cmd.end());
  buf.push_back(0);
  STARTUPINFOW si{};
  si.cb = sizeof si;
  PROCESS_INFORMATION pi{};
  if (!CreateProcessW(self, buf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &pi))
    return -2;
  WaitForSingleObject(pi.hProcess, 60000);
  DWORD code = 0;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return static_cast<int>(code);
}

// ---------------------------------------------------------------- integer division (the old r12 bug's victim)
template <class T>
NOINLINE static T div_(T a, T b)
{
  return a / b;
}
template <class T>
NOINLINE static T rem_(T a, T b)
{
  return a % b;
}
template <class T>
static bool div_ok(T a, T b, T q, T r)
{
  if (static_cast<T>(q * b + r) != a)
    return false;
  if constexpr (static_cast<T>(-1) < static_cast<T>(0))
  {
    if (r != 0 && ((r < 0) != (a < 0)))
      return false; // the remainder has the sign of the dividend
    const T ar = r < 0 ? static_cast<T>(-r) : r;
    const T ab = b < 0 ? static_cast<T>(-b) : b;
    return ar < ab;
  }
  else
  {
    return r < b;
  }
}

static void test_division()
{
  static const int32_t a32[] = {7, -7, 7, -7, INT32_MIN + 1, 1000000007, -1000000007, 13, -13, 0x7fffffff, -65537, 0};
  static const int32_t b32[] = {2, 2, -2, -2, 3, 97, 97, -1, -1, 65536, 256, -5};
  std::string line;
  bool all = true;
  char tmp[96];
  for (size_t i = 0; i < sizeof a32 / sizeof a32[0]; ++i)
  {
    volatile int32_t a = a32[i], b = b32[i];
    const int32_t q = div_<int32_t>(a, b), r = rem_<int32_t>(a, b);
    all = all && div_ok<int32_t>(a, b, q, r);
    std::snprintf(tmp, sizeof tmp, "%s%d/%d=%d,%d", i ? " " : "", (int)a, (int)b, (int)q, (int)r);
    line += tmp;
  }
  check("T45", all, "int32 / and %%: %s", line.c_str());

  static const uint32_t ua[] = {0xFFFFFFFFu, 0x80000000u, 1000000007u, 7u, 0u};
  static const uint32_t ub[] = {3u, 7u, 0x10000u, 0xFFFFFFFFu, 9u};
  line.clear();
  all = true;
  for (size_t i = 0; i < sizeof ua / sizeof ua[0]; ++i)
  {
    volatile uint32_t a = ua[i], b = ub[i];
    const uint32_t q = div_<uint32_t>(a, b), r = rem_<uint32_t>(a, b);
    all = all && div_ok<uint32_t>(a, b, q, r);
    std::snprintf(tmp, sizeof tmp, "%s%u/%u=%u,%u", i ? " " : "", (unsigned)a, (unsigned)b, (unsigned)q,
                  (unsigned)r);
    line += tmp;
  }
  check("T46", all, "uint32 / and %%: %s", line.c_str());

  static const int64_t a64[] = {-9000000000000000007LL, 9000000000000000007LL, -7, 7, -4294967297LL,
                                0x7FFFFFFFFFFFFFFFLL};
  static const int64_t b64[] = {1000003, -1000003, 2, -2, 65536, -4294967296LL};
  line.clear();
  all = true;
  for (size_t i = 0; i < sizeof a64 / sizeof a64[0]; ++i)
  {
    volatile int64_t a = a64[i], b = b64[i];
    const int64_t q = div_<int64_t>(a, b), r = rem_<int64_t>(a, b);
    all = all && div_ok<int64_t>(a, b, q, r);
    std::snprintf(tmp, sizeof tmp, "%s%lld/%lld=%lld,%lld", i ? " " : "", (long long)a, (long long)b, (long long)q,
                  (long long)r);
    line += tmp;
  }
  check("T47", all, "int64 / and %%: %s", line.c_str());

  static const uint64_t ua64[] = {0xFFFFFFFFFFFFFFFFull, 0x8000000000000000ull, 1000000000000000007ull};
  static const uint64_t ub64[] = {3ull, 0xFFFFFFFFull, 1000000007ull};
  line.clear();
  all = true;
  for (size_t i = 0; i < sizeof ua64 / sizeof ua64[0]; ++i)
  {
    volatile uint64_t a = ua64[i], b = ub64[i];
    const uint64_t q = div_<uint64_t>(a, b), r = rem_<uint64_t>(a, b);
    all = all && div_ok<uint64_t>(a, b, q, r);
    std::snprintf(tmp, sizeof tmp, "%s%llu/%llu=%llu,%llu", i ? " " : "", (unsigned long long)a,
                  (unsigned long long)b, (unsigned long long)q, (unsigned long long)r);
    line += tmp;
  }
  check("T48", all, "uint64 / and %%: %s", line.c_str());

  // many negative remainders through one call site, as a hash-table index would use them
  long long acc = 0;
  bool neg_ok = true;
  for (int i = -50000; i < 50000; i += 7)
  {
    volatile int a = i * 2654435761u;
    volatile int b = 1021;
    const int r = rem_<int>(a, b);
    neg_ok = neg_ok && div_ok<int>(a, b, div_<int>(a, b), r);
    acc += r;
  }
  check("T49", neg_ok, "14286 signed remainders keep the dividend's sign: sum=%lld", acc);
}

// ---------------------------------------------------------------- float <-> integer conversions (CRT helpers on ARM)
static void test_conversions()
{
  volatile double dn = -2.7, dp = 2.7, du = 3000000000.0, d64 = -9.0e15, du64 = 1.8e19, dbig = 1.5e18;
  volatile long long i64a = -9007199254740993LL, i64b = 0x7FFFFFFFFFFFFFFFLL;
  volatile unsigned long long u64a = 0xFFFFFFFFFFFFFFFFull, u64b = 9007199254740993ull;
  volatile float fneg = -123456.789f;
  char b[400];
  std::snprintf(b, sizeof b,
                "(int)-2.7=%d (int)2.7=%d (unsigned)3e9=%u (ll)-9e15=%lld (ull)1.8e19=%llu (ll)1.5e18=%lld "
                "(double)-(2^53+1)=%.17g (double)INT64_MAX=%.17g (double)UINT64_MAX=%.17g (double)(2^53+1)u=%.17g "
                "(ll)-123456.789f=%lld (float)ll=%.9g",
                (int)dn, (int)dp, (unsigned)du, (long long)d64, (unsigned long long)du64, (long long)dbig,
                (double)i64a, (double)i64b, (double)u64a, (double)u64b, (long long)fneg, (double)(float)i64a);
  const bool ok = (int)dn == -2 && (int)dp == 2 && (unsigned)du == 3000000000u && (long long)d64 == -9000000000000000LL &&
                  (unsigned long long)du64 == 18000000000000000000ull && (long long)fneg == -123456 &&
                  (double)i64a == -9007199254740992.0;
  check("T50", ok, "float<->int conversions: %s", b);

  volatile double third = 1.0, three = 3.0, two = 2.0;
  std::snprintf(b, sizeof b, "1/3=%.17g sqrt2=%.17g 0.1+0.2=%.17g %.3f %s %s", third / three, std::sqrt(two),
                0.1 + 0.2, -0.0005, std::to_string(-123456789012345LL).c_str(), std::to_string(1.5).c_str());
  check("T51", true, "IEEE basics and CRT formatting: %s", b);

  char c = static_cast<char>(0xF0);
  check("T52", static_cast<int>(c) == -16 && sizeof(long double) == 8 && sizeof(wchar_t) == 2 && sizeof(void*) == 4 &&
                   alignof(double) == 8 && alignof(long long) == 8,
        "ABI: char signed=%d sizeof(long double)=%u sizeof(wchar_t)=%u sizeof(void*)=%u alignof(double)=%u "
        "alignof(long long)=%u",
        static_cast<int>(c) < 0 ? 1 : 0, (unsigned)sizeof(long double), (unsigned)sizeof(wchar_t),
        (unsigned)sizeof(void*), (unsigned)alignof(double), (unsigned)alignof(long long));
}

// ---------------------------------------------------------------- SEH (Kodi: ThreadImplWin.cpp's thread-name exception)
NOINLINE static int seh_thread_name()
{
  struct
  {
    DWORD dwType;
    LPCSTR szName;
    DWORD dwThreadID;
    DWORD dwFlags;
  } info = {0x1000, "ehtest", static_cast<DWORD>(-1), 0};
  int handled = 0;
  __try
  {
    RaiseException(0x406D1388, 0, sizeof(info) / sizeof(ULONG_PTR), reinterpret_cast<ULONG_PTR*>(&info));
  }
  __except (EXCEPTION_EXECUTE_HANDLER)
  {
    handled = 1;
  }
  return handled;
}
// clang (any target, no /EHa) catches SEH only for faults inside calls it cannot prove nounwind; a fault written
// directly in the __try body is not caught (measured on x86: the process died). So the faults are in callees reached
// through volatile function pointers. MSVC catches both forms.
NOINLINE static void store_null()
{
  *static_cast<volatile int*>(nullptr) = 1;
}
NOINLINE static int divide(int a, int b)
{
  return a / b;
}
static void (*volatile g_store_null)() = &store_null;
static int (*volatile g_divide)(int, int) = &divide;

NOINLINE static DWORD seh_av()
{
  DWORD code = 0;
  __try
  {
    g_store_null();
  }
  __except (EXCEPTION_EXECUTE_HANDLER)
  {
    code = GetExceptionCode();
  }
  return code;
}
NOINLINE static DWORD seh_div0()
{
  DWORD code = 0;
  volatile int z = 0, one = 1;
  __try
  {
    one = g_divide(one, z);
  }
  __except (EXCEPTION_EXECUTE_HANDLER)
  {
    code = GetExceptionCode();
  }
  return code;
}

// ---------------------------------------------------------------- code reachable only through a catchret (rt2.x 0030)
// The inner try body always throws, so the code after the inner catch is reached only through that catch's
// catchret. It must run in the parent frame, with the parent's EH state: its throw goes to the OUTER handler.
static int g_side = 0;
NOINLINE static void side(int r)
{
  g_side = r;
}
NOINLINE static int after_catchret(int v)
{
  int r = 0;
  try
  {
    try
    {
      throw MyError(v);
    }
    catch (const MyError& e)
    {
      r = e.code;
    }
    side(r);
    throw r + 1;
  }
  catch (int x)
  {
    r = x * 10;
  }
  return r;
}

static void test_catchret()
{
  const int r = after_catchret(4);
  check("T56", r == 50 && g_side == 4,
        "code after a catch, reached only through its catchret, runs in the parent and throws to the outer handler: "
        "r=%d side=%d",
        r, g_side);
}

static void test_seh()
{
  check("T53", seh_thread_name() == 1, "SEH __try/__except catches RaiseException(0x406D1388) (Kodi's thread naming)");
  const DWORD av = seh_av();
  check("T54", av == 0xC0000005, "SEH catches an access violation: code=0x%08lX", (unsigned long)av);
  const DWORD dz = seh_div0();
  check("T55", dz == 0xC0000094, "SEH catches integer divide by zero: code=0x%08lX", (unsigned long)dz);
}

int main(int argc, char** argv)
{
  for (int i = 1; i < argc; ++i)
  {
    if (!std::strcmp(argv[i], "--selftest-fail"))
      g_selftest_fail = true;
    if (!std::strcmp(argv[i], "--child-noexcept"))
    {
      std::set_terminate([] { std::_Exit(77); });
      throws_inside_noexcept();
      return 1; // not reached when noexcept is enforced
    }
  }
  std::setvbuf(stdout, nullptr, _IONBF, 0);
  std::fprintf(stderr, "[info] ehtest: %s, %s, _MSC_VER=%d\n",
#if defined(_M_ARM)
               "ARM32",
#elif defined(_M_IX86)
               "x86",
#elif defined(_M_X64)
               "x64",
#else
               "?",
#endif
#if defined(__clang__)
               "clang " __clang_version__,
#else
               "MSVC cl",
#endif
               _MSC_VER);

  test_basic();
  test_rethrow();
  test_lifetime();
  test_frames();
  test_stl();
  const int child = run_child_noexcept();
  check("T40", child == 77, "exception escaping a noexcept function calls std::terminate (child exit code %d)", child);
  test_regex();
  test_threads();
  test_division();
  test_conversions();
  test_seh();
  test_catchret();

  std::printf("SUMMARY checks=%d failed=%d\n", g_checks, g_failed);
  return g_failed;
}
