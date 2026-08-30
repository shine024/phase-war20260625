# -*- coding: utf-8 -*-
"""审计: 战场敌人的真实种类数与卡图消耗"""
import glob
import io
import os
import re

# 1) 敌方卡图文件数
fe = [f for f in glob.glob('assets/card_icons/enemy/*.png')
      if not f.endswith('.import') and 'thumb' not in f]
print('enemy/ 卡图文件数:', len(fe))

# 2) 关卡->敌人: level_information 怎么引用敌人
t = io.open('data/level_information.gd', encoding='utf-8').read()
print('--- level_information 敌人引用字段采样')
for pat in [r'"enemies"', r'enemy_ids', r'"enemy"', r'archetype']:
    ms = re.findall(pat, t)
    print('  %-14s x%d' % (pat, len(ms)))

# 3) manifest: 敌人清单结构
t2 = io.open('data/enemy_unit_manifest.gd', encoding='utf-8').read()
print('--- enemy_unit_manifest 头 60 行含 id 的行')
n = 0
for ln in t2.splitlines():
    if re.search(r'"[a-z0-9_]+"', ln) and n < 15:
        print('  ', ln.strip()[:100])
        n += 1

# 4) enemy_unit 运行时怎么取卡图: icon 字段消费
t3 = io.open('data/enemy_archetypes_ww.gd', encoding='utf-8').read()
m = re.search(r'"id":\s*"ww1_inf_rifle".{0,400}', t3, re.S)
if m:
    print('--- ww1_inf_rifle 条目:')
    print(m.group(0)[:400])
