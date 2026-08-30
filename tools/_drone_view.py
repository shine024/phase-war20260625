# -*- coding: utf-8 -*-
"""scout_drone attack 帧朝向 ASCII 诊断"""
import glob
import numpy as np
from PIL import Image

fs = sorted(glob.glob(r'资料/单位分帧动画/mod_inf_scout_drone_侦察无人机/attack/f*.png'))
print('frames:', len(fs))
for f in (fs[0], fs[4], fs[8], fs[-1]):
    arr = np.asarray(Image.open(f).convert('RGBA')).astype(np.int16)
    a = arr[:, :, 3] > 128
    H, W = a.shape
    print('---', f.split('\\')[-1], 'opaque=%.1f%%' % (a.mean() * 100))
    for gy in range(12):
        row = ''
        for gx in range(26):
            y0, y1 = H * gy // 12, H * (gy + 1) // 12
            x0, x1 = W * gx // 26, W * (gx + 1) // 26
            row += ' .:-=+*#%@'[min(9, int(a[y0:y1, x0:x1].mean() * 10))]
        print(row)
