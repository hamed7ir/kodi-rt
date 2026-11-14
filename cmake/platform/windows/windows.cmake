# kodi-rt: Detours is optional: its only user, the D3D driver hook in WinSystemWin32DX.cpp, is compiled out without it
set(PLATFORM_REQUIRED_DEPS Effects11)
list(APPEND PLATFORM_OPTIONAL_DEPS Detours)
set(PLATFORM_REQUIRED_TOOLS EffectsCompiler Msys)

list(APPEND PLATFORM_OPTIONAL_PACKAGES LibAACS LibBDPlus)

set(APP_RENDER_SYSTEM dx11)
list(APPEND PLATFORM_DEFINES -DNTDDI_VERSION=NTDDI_WINBLUE -D_WIN32_WINNT=_WIN32_WINNT_WINBLUE)

set(${CORE_SYSTEM_NAME}_SEARCH_CONFIG NO_DEFAULT_PATH CACHE STRING "")

# Builds libbluray jar files to enable bluray menu support
set(ENABLE_BLURAY_JAR ON)
