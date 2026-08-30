# -*- coding: utf-8 -*-
"""dump 重生成名单的现有 prompt"""
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
UNITS = gua.UNITS  # 已合并 json
extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))

REG = [
    ('ww1_arty_m81', 'attack'), ('cold_sup_zsu23', 'attack'),
    ('cold_fort_missile', 'attack'), ('ww1_sup_vickers', 'idle'),
    ('ww2_arty_hummel', 'attack'), ('mod_sup_growler', 'idle'),
    ('mod_sup_growler', 'attack'), ('fut_inf_x9', 'attack'),
    ('fut_inf_c96', 'attack'), ('ww2_inf_bazooka', 'idle'),
    ('fut_mech', 'idle'),
]
for u, a in REG:
    src = UNITS[u]
    where = 'json' if u in extra else 'py'
    p = src['anims'][a]['prompt']
    print('##### %s / %s  [%s]  seconds=%s' % (u, a, where, src['anims'][a].get('seconds')))
    print(p[:600])
    print()
