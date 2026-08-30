# -*- coding: utf-8 -*-
"""metis 卡图朝向检查: 左右半区不透明像素质心对比"""
import numpy as np
from PIL import Image

for p in [r'assets/card_icons/enemy/cold_inf_metis.png',
          r'资料/单位分帧动画/_ref/cold_inf_metis_white.jpg']:
    im = Image.open(p).convert('RGBA')
    a = np.asarray(im)[:, :, 3] > 128
    H, W = a.shape
    ys, xs = np.nonzero(a)
    if len(xs) == 0:
        print(p, 'EMPTY')
        continue
    # 主体的左/右半质心+宽度分布
    left = a[:, :W // 2].sum()
    right = a[:, W // 2:].sum()
    print('%s  左半像素=%d 右半像素=%d (右占比 %.2f)' % (p.split('/')[-1].split('\\')[-1], left, right, right / (left + right)))
    # ASCII 16x16
    arr = np.asarray(im).astype(np.int16)
    mn = arr[:, :, :3].min(axis=2)
    for gy in range(12):
        row = ''
        for gx in range(24):
            y0, y1 = H * gy // 12, H * (gy + 1) // 12
            x0, x1 = W * gx // 24, W * (gx + 1) // 24
            row += ' .:-=+*#%@'[min(9, int(a[y0:y1, x0:x1].mean() * 10))]
        print(row)
