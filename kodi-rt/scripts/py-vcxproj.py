#!/usr/bin/env python3
# kodi-rt Python stage: read CPython's PCbuild/*.vcxproj files and print what a CMake build needs from them.
#   summary <proj>          item groups (with their Condition), ClCompile count per directory, items with metadata
#   sources <proj> [plat]   ClCompile paths relative to the CPython source root (forward slashes), one per line,
#                           skipping items whose own or group Condition rules out platform plat (default ARM)
#   defines <proj>          the PreprocessorDefinitions of the project's ClCompile ItemDefinitionGroup(s)
#   frozen                  the frozen modules of _freeze_module.vcxproj: "modname<TAB>path.py<TAB>header"
# Macros: $(PySourcePath) -> "" (root); other $(...) are kept so the caller sees them (e.g. $(zlibNgDir)).
import re, sys

def load(path):
    return open(path, encoding='utf-8-sig').read()

def cond_ok(cond, plat):
    if not cond:
        return True
    c = cond.replace(' ', '')
    m = re.search(r"'\$\(Platform\)'(==|!=)'([^']*)'", c)
    if m:
        eq = (m.group(2) == plat)
        return eq if m.group(1) == '==' else not eq
    return True   # conditions on other properties: keep, the caller decides

def norm(inc):
    inc = inc.replace('$(PySourcePath)', '')
    inc = inc.replace('\\', '/')
    while inc.startswith('../'):
        inc = inc[3:]
    return inc

def groups(s):
    for attrs, body in re.findall(r'<ItemGroup([^>]*)>(.*?)</ItemGroup>', s, re.S):
        m = re.search(r'Condition="([^"]*)"', attrs)
        yield (m.group(1) if m else ''), body

def clcompile(body):
    for m in re.finditer(r'<ClCompile Include="([^"]+)"([^>]*?)(/>|>(.*?)</ClCompile>)', body, re.S):
        inc, attrs, inner = m.group(1), m.group(2), m.group(4) or ''
        cm = re.search(r'Condition="([^"]*)"', attrs)
        yield inc, (cm.group(1) if cm else ''), inner

def main():
    cmd = sys.argv[1]
    if cmd == 'summary':
        s = load(sys.argv[2])
        for gcond, body in groups(s):
            items = list(clcompile(body))
            if not items:
                continue
            print(f'ItemGroup [{gcond or "no condition"}] {len(items)} items')
            dirs = {}
            for inc, icond, inner in items:
                d = norm(inc).rsplit('/', 1)[0]
                dirs[d] = dirs.get(d, 0) + 1
                if icond or inner.strip():
                    print('   item:', norm(inc), '| cond:', icond, '|', ' '.join(inner.split())[:160])
            for d, n in sorted(dirs.items(), key=lambda x: -x[1]):
                print(f'   {n:4d}  {d}')
    elif cmd == 'sources':
        s = load(sys.argv[2]); plat = sys.argv[3] if len(sys.argv) > 3 else 'ARM'
        for gcond, body in groups(s):
            if not cond_ok(gcond, plat):
                continue
            for inc, icond, inner in clcompile(body):
                if cond_ok(icond, plat):
                    print(norm(inc))
    elif cmd == 'defines':
        s = load(sys.argv[2])
        for m in re.finditer(r'<ItemDefinitionGroup([^>]*)>(.*?)</ItemDefinitionGroup>', s, re.S):
            for d in re.findall(r'<PreprocessorDefinitions>([^<]*)</PreprocessorDefinitions>', m.group(2)):
                print(f'[{m.group(1).strip()}] {d}')
    elif cmd == 'frozen':
        s = load(sys.argv[2])
        for m in re.finditer(r'<None Include="([^"]+\.py)">(.*?)</None>', s, re.S):
            inner = m.group(2)
            mod = re.search(r'<ModName>([^<]*)</ModName>', inner)
            out = re.search(r'<OutFile>([^<]*)</OutFile>', inner)
            print(f'{mod.group(1) if mod else "?"}\t{norm(m.group(1))}\t{norm(out.group(1)) if out else "?"}')
    else:
        raise SystemExit('unknown command')

main()
