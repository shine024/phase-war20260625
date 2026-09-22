import os, re, json
from collections import Counter

SEPS = (chr(92), '/')
def norm(p):
    for s in SEPS:
        p = p.replace(s, '/')
    return p

# 1) 清点 assets/ui 全部 PNG
inv = []
for root, _, files in os.walk('assets/ui'):
    for f in files:
        if f.endswith('.png'):
            inv.append(norm(os.path.join(root, f)))
subdir = lambda p: os.path.dirname(p).replace('assets/ui/', '') or '<root>'
by_dir = Counter(subdir(p) for p in inv)
print('清点:', len(inv), '张；分布:', dict(by_dir))
inv_set = set(inv)

# 2) 收集运行期引用源文本（.gd/.tscn/.tres），工具脚本单独归类
rt_paths, tool_paths = [], []
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ('.git', '.godot', '.hermes', 'node_modules')]
    for f in files:
        p = norm(os.path.join(root, f))
        if f.endswith(('.gd', '.tscn', '.tres')):
            (tool_paths if '/tools/' in p else rt_paths).append(p)
        elif f.endswith('.py'):
            tool_paths.append(p)

lit_re = re.compile(r'(?:res://)?assets/ui/[\w\-/.]+?\.(?:png|svg)')
def collect(paths):
    s = set()
    for p in paths:
        try:
            txt = open(p, encoding='utf-8', errors='ignore').read()
        except Exception:
            continue
        s |= {m.group(0).replace('res://', '') for m in lit_re.finditer(txt)}
    return s
lit_rt = collect(rt_paths)
lit_all = lit_rt | collect(tool_paths)

dangling_png = sorted(p for p in lit_rt if p not in inv_set and p.endswith('.png'))
dangling_svg = sorted(p for p in lit_rt if p not in inv_set and p.endswith('.svg'))
print('运行期字面引用 png:', sum(1 for p in lit_rt if p.endswith('.png')), '| svg:', sum(1 for p in lit_rt if p.endswith('.svg')))
print('悬空 png 引用:', dangling_png)
print('悬空 svg 引用:', dangling_svg)

def template_covered(p):
    d, f = os.path.dirname(p), os.path.basename(p)
    if d in ('assets/ui/instruments', 'assets/ui/instruments/_thumb128'):
        return True
    if d == 'assets/ui/stars' and re.match(r'star_\d+\.png', f):
        return True
    if d == 'assets/ui/factions' and re.match(r'\w+_128\.png', f):
        return True
    if d == 'assets/ui/truck_base' and re.match(r'truck_tier\d+\.png', f):
        return True
    return False

rt_blob = '\n'.join(open(p, encoding='utf-8', errors='ignore').read() for p in rt_paths)
icons_covered, icons_orphan = [], []
for p in inv:
    d = subdir(p)
    if d.startswith('icons') and p.endswith('.png'):
        stem = os.path.splitext(os.path.basename(p))[0]
        svg_twin = ('assets/ui/%s/%s.svg' % (d, stem)) in lit_rt
        if stem in rt_blob or svg_twin or p in lit_rt:
            icons_covered.append((p, 'svg孪生回退' if svg_twin and stem not in rt_blob else 'stem'))
        else:
            icons_orphan.append(p)

orphans = set(icons_orphan)
for p in inv:
    base = os.path.basename(p)
    if p in lit_rt or base in {os.path.basename(x) for x in lit_rt}:
        continue
    if template_covered(p):
        continue
    if subdir(p).startswith('icons') and p not in icons_orphan:
        continue
    orphans.add(p)
orphans = sorted(orphans)

payload = {
    'date': '2026-09-22',
    'inventory_total': len(inv),
    'by_dir': dict(by_dir),
    'literal_rt_png_count': sum(1 for p in lit_rt if p.endswith('.png')),
    'dangling_png_refs': dangling_png,
    'dangling_svg_refs': dangling_svg,
    'orphan_candidates': orphans,
    'icons_covered': icons_covered,
    'method': '字面路径 + 模板目录(instruments 2 目录/factions/stars/truck_base tier) + icons stem 与 svg 孪生回退；字符串拼接与动态合成存在盲区，孤儿为候选需人工复核',
}
json.dump(payload, open('tests/evidence/art_audit_2026-09-22/task41_ui_asset_refs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('孤儿候选:', len(orphans))
for o in orphans:
    print('  ', o)
print('TASK41_OK')
