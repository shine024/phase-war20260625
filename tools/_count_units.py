# -*- coding: utf-8 -*-
import glob
import io
import re

src = io.open('tools/generate_unit_animations.py', encoding='utf-8').read()
m = re.search(r'UNITS\s*=\s*\{(.*?)\n\}', src, re.S)
keys = re.findall(r'"([a-z0-9_]+)":\s*\{', m.group(1))
print('UNITS in pipeline:', len(keys))

total = {}
for f in sorted(glob.glob('data/enemy_archetypes*.gd')):
    t = io.open(f, encoding='utf-8').read()
    ids = set(re.findall(r'"id":\s*"([a-z0-9_]+)"', t))
    ids |= set(re.findall(r'^\t"([a-z0-9_]+)":\s*\{', t, re.M))
    total[f.replace('\\', '/').split('/')[-1]] = ids
    print(' ', f.replace('\\', '/').split('/')[-1], len(ids))

union = set().union(*total.values()) if total else set()
print('archetype union:', len(union))
anim = set(keys)
print('animated ∩ archetypes:', len(anim & union))
print('archetypes NOT animated:', sorted(union - anim))
