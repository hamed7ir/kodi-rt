# kodi-rt: the x86 Kodi build only (scripts/s9-configure.sh passes it as CMAKE_PROJECT_kodi_INCLUDE for ARCH=x86).
# clang does not define __cpp_impl_coroutine for 32-bit x86 with the Microsoft ABI (clang 23
# lib/Frontend/InitPreprocessor.cpp: "Support for coroutines on 32-bit x86 Microsoft platforms is incomplete, do not
# advertise it"; x64 and ARM32 get it). Without it MSVC's <coroutine> is empty, and C++/WinRT's winrt/base.h (which
# DeviceResources.h, WIN32Util.cpp and others include) falls back to <experimental/coroutine>, which refuses clang:
# measured, WinSystemWin32DX.cpp does not compile for x86. Kodi defines no coroutines (no co_await, co_return or
# co_yield in xbmc/), and C++/WinRT's headers only declare operator co_await overloads, so advertising the feature lets
# the headers compile while no coroutine code is ever generated.
add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:-D__cpp_impl_coroutine=201902L>")
message(STATUS "kodi-rt x86: C++ compiled with -D__cpp_impl_coroutine=201902L (C++/WinRT headers; no coroutines in Kodi)")
