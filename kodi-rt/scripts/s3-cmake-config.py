# kodi-rt Stage 3: write a CMake config package for a static library that its own build system doesn't export
# (meson/autotools/hand-built ones), under the package and target names Kodi's Find modules look for
# (ModuleHelpers.cmake SEARCH_EXISTING_PACKAGES: find_package(<module_lc> CONFIG) in <prefix>/lib/cmake).
# Usage: python -I scripts/s3-cmake-config.py --prefix F:/kodi-rt/prefix/arm32 --package fribidi --target fribidi::fribidi
#          --version 1.0.17 --lib lib/fribidi.lib --include include/fribidi [--define FRIBIDI_LIB_STATIC ...]
#          [--link other.lib ...]
# Paths after --lib/--include are relative to the prefix; the files are written relocatable (relative to themselves).
import argparse, os

ap = argparse.ArgumentParser()
ap.add_argument('--prefix', required=True)
ap.add_argument('--package', required=True)
ap.add_argument('--target', required=True)
ap.add_argument('--version', required=True)
ap.add_argument('--lib', required=True)
ap.add_argument('--include', action='append', default=[])
ap.add_argument('--define', action='append', default=[])
ap.add_argument('--link', action='append', default=[])
a = ap.parse_args()

pfx = a.prefix.replace('\\', '/')
for rel in [a.lib] + a.include:
    if not os.path.exists(os.path.join(pfx, rel)):
        raise SystemExit(f'missing in the prefix: {rel}')
d = os.path.join(pfx, 'lib', 'cmake', a.package)
os.makedirs(d, exist_ok=True)
inc = ';'.join('${_IMPORT_PREFIX}/' + i for i in a.include)
cfg = f'''# kodi-rt: CMake config for {a.package} {a.version} (static, Windows ARM32), written by scripts/s3-cmake-config.py
get_filename_component(_IMPORT_PREFIX "${{CMAKE_CURRENT_LIST_DIR}}/../../.." ABSOLUTE)
if(NOT TARGET {a.target})
  add_library({a.target} STATIC IMPORTED)
  set_target_properties({a.target} PROPERTIES
    IMPORTED_LOCATION "${{_IMPORT_PREFIX}}/{a.lib}"
    INTERFACE_INCLUDE_DIRECTORIES "{inc}"'''
if a.define:
    cfg += f'\n    INTERFACE_COMPILE_DEFINITIONS "{";".join(a.define)}"'
if a.link:
    cfg += f'\n    INTERFACE_LINK_LIBRARIES "{";".join(a.link)}"'
cfg += f'''
  )
endif()
set({a.package}_FOUND TRUE)
set({a.package}_VERSION {a.version})
unset(_IMPORT_PREFIX)
'''
ver = f'''# kodi-rt: version file for {a.package} {a.version}
set(PACKAGE_VERSION "{a.version}")
if(PACKAGE_FIND_VERSION VERSION_GREATER PACKAGE_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
'''
open(os.path.join(d, f'{a.package}-config.cmake'), 'w', newline='\n').write(cfg)
open(os.path.join(d, f'{a.package}-config-version.cmake'), 'w', newline='\n').write(ver)
print(f'wrote {d}/{a.package}-config.cmake ({a.target}, {a.version})')
