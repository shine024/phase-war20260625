# -*- coding: utf-8 -*-
"""ww1_storm 补 matte 覆盖并重建两动画"""
import importlib.util
import sys

SRC = 'tools/generate_unit_animations.py'
txt = open(SRC, encoding='utf-8').read()
ref = '"ref": "ww1_storm_white.jpg",'
assert txt.count(ref) == 1
if '"nw_trim": False' not in txt.split(ref, 1)[1][:200]:
    txt = txt.replace(ref, ref + '\n        "matte_edge": True,\n        "nw_trim": False,', 1)
    open(SRC, 'w', encoding='utf-8').write(txt)
    print('patched ww1_storm flags')

spec = importlib.util.spec_from_file_location('gua', SRC)
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
for a in ('idle', 'attack'):
    print('== rebuild ww1_storm/' + a, flush=True)
    gua.step_build('ww1_storm', a)
print('DONE')
