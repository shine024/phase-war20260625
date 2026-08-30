# -*- coding: utf-8 -*-
"""重建 ww1_storm 两动画(带清边), 再全量对既有 f*.png 幂等清边"""
import glob
import importlib.util
import os
import sys

import numpy as np
from PIL import Image

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
for a in ('idle', 'attack'):
    print('== rebuild ww1_storm/' + a, flush=True)
    gua.step_build('ww1_storm', a)

BASE = r'资料/单位分帧动画'
n = 0
for d in sorted(glob.glob(os.path.join(BASE, '*'))):
    if not os.path.isdir(d) or os.path.basename(d).startswith('_'):
        continue
    for anim in ('idle', 'attack'):
        for f in glob.glob(os.path.join(d, anim, 'f*.png')):
            arr = np.asarray(Image.open(f).convert('RGBA')).copy()
            b = arr[:6, :, 3].max() + arr[-6:, :, 3].max() + arr[:, :6, 3].max() + arr[:, -6:, 3].max()
            if b > 0:
                arr[:6, :, :] = 0
                arr[-6:, :, :] = 0
                arr[:, :6, :] = 0
                arr[:, -6:, :] = 0
                Image.fromarray(arr).save(f)
                n += 1
print('border-cleared %d frames' % n)

import cv2
worst = ('', 0)
for f in sorted(glob.glob(os.path.join(BASE, 'ww1_storm_暴风突击队', 'attack', 'f*.png'))):
    arr = np.asarray(Image.open(f).convert('RGBA'))
    a = arr[..., 3] >= 128
    trans = (~a).astype(np.uint8)
    nf, labf = cv2.connectedComponents(trans)
    border = set()
    for e in (labf[0, :], labf[-1, :], labf[:, 0], labf[:, -1]):
        border |= set(np.unique(e).tolist())
    border.discard(0)
    hole = np.isin(labf, [i for i in range(1, nf) if i not in border])
    if 100 * hole.mean() > worst[1]:
        worst = (f.split('\\')[-1], 100 * hole.mean())
print('storm attack worst holes now: %s %.1f%%' % worst)
