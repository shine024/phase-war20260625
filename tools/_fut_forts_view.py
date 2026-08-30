# -*- coding: utf-8 -*-
"""fut 两堡 GATE-FAIL ASCII 诊断: ion attack + shield attack"""
import glob
import numpy as np
from PIL import Image

CASES = [
    (r'资料/单位分帧动画/fut_fort_ion_离子炮台', 'attack'),
    (r'资料/单位分帧动画/fut_fort_shield_能量护盾发生器', 'attack'),
]
for base, anim in CASES:
    fs = sorted(glob.glob(base + '/' + anim + '/f*.png'))
    print('=====', base.split('\\')[-1], anim, 'frames:', len(fs))
    for f in (fs[0], fs[len(fs) // 2], fs[-1]):
        a = np.asarray(Image.open(f).convert('RGBA'))[:, :, 3] > 128
        H, W = a.shape
        print('---', f.split('\\')[-1], 'opaque=%.1f%%' % (a.mean() * 100))
        for gy in range(11):
            row = ''
            for gx in range(26):
                y0, y1 = H * gy // 11, H * (gy + 1) // 11
                x0, x1 = W * gx // 26, W * (gx + 1) // 26
                row += ' .:-=+*#%@'[min(9, int(a[y0:y1, x0:x1].mean() * 10))]
            print(row)
