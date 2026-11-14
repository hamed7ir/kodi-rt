#!/usr/bin/env python3
# kodi-rt Python stage: edits to a copy of SWIG 4.5.0 (build/py/src/swig-4.5.0, made by scripts/py-swig.sh).
# SWIG's CMake build regenerates its parser with bison (>= 3.5), which this host does not have. The release tarball
# ships the parser that bison generated for it (Source/CParse/parser.c/.h, what the autotools build compiles), so the
# CMake build copies those instead.
# Usage: python -I scripts/py-swig-edits.py <copy of the SWIG source>
import os, sys

root = sys.argv[1]

def edit(rel, old, new):
    p = os.path.join(root, rel)
    s = open(p, encoding='utf-8', newline='').read()
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{rel}: expected 1 match, found {n}:\n{old}')
    open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
    print(f'edited {rel}')

edit('CMakeLists.txt', 'find_package (BISON 3.5 REQUIRED)\n',
     '# kodi-rt: no bison on this host; the release\'s generated parser is used below\n')
edit('CMakeLists.txt',
     'BISON_TARGET (swig_parser\n'
     '    ${SWIG_SOURCE_DIR}/CParse/parser.y\n'
     '    ${PROJECT_BINARY_DIR}/Source/CParse/parser.c\n'
     ')\n',
     'configure_file (${SWIG_SOURCE_DIR}/CParse/parser.c ${PROJECT_BINARY_DIR}/Source/CParse/parser.c COPYONLY)\n'
     'configure_file (${SWIG_SOURCE_DIR}/CParse/parser.h ${PROJECT_BINARY_DIR}/Source/CParse/parser.h COPYONLY)\n')
