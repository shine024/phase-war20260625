# -*- coding: utf-8 -*-
"""fix3 批量重抠: 快照 f*.png -> bak_fix3/, 以新 matte 参数重建"""
import glob
import importlib.util
import os
import shutil
import sys

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)

BASE = r'资料/单位分帧动画'
LIST = [
    ('mod_mlrs', 'attack'), ('mod_abrams', 'attack'),
    ('ww2_arty_m81', 'idle'), ('ww2_arty_m81', 'attack'),
    ('mod_technical', 'idle'), ('mod_technical', 'attack'),
    ('mod_inf_technical', 'idle'), ('mod_inf_technical', 'attack'),
    ('mod_sup_m6', 'attack'), ('mod_inf_scout_drone', 'attack'),
    ('fut_air_regen_frame', 'idle'), ('fut_air_regen_frame', 'attack'),
    ('cold_fort_radar', 'idle'), ('ww2_arty_pak40', 'idle'),
    ('ww2_arty_pak40', 'attack'), ('fut_arty_ssc1', 'idle'),
    ('fut_arty_ssc1', 'attack'),
]


def dname(u):
    for d in os.listdir(BASE):
        if d == u or d.startswith(u + '_'):
            return d
    raise SystemExit('no dir ' + u)


for u, a in LIST:
    d = dname(u)
    adir = os.path.join(BASE, d, a)
    bak = os.path.join(adir, 'bak_fix3')
    os.makedirs(bak, exist_ok=True)
    for f in glob.glob(os.path.join(adir, 'f*.png')):
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
    print('== rebuild %s/%s' % (d, a), flush=True)
    gua.step_build(u, a)
print('ALL DONE')
