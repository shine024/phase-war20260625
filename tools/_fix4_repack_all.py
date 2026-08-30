# -*- coding: utf-8 -*-
"""全量 repack: 所有单位 idle+attack 雪碧图按当前 f*.png 重打"""
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location('rp', 'tools/repack_unit_sheet.py')
rp = importlib.util.module_from_spec(spec)
sys.modules['rp'] = rp
spec.loader.exec_module(rp)

BASE = r'资料/单位分帧动画'
n = 0
for d in sorted(os.listdir(BASE)):
    dp = os.path.join(BASE, d)
    if not os.path.isdir(dp) or d.startswith('_'):
        continue
    for anim in ('idle', 'attack'):
        if os.path.isdir(os.path.join(dp, anim)):
            rp.repack(d, anim)
            n += 1
print('repacked %d sheets' % n)
