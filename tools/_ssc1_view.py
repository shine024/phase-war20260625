# -*- coding: utf-8 -*-
"""ssc1 attack 朝向 3/4 分诊: 帧间轮廓对比"""
import glob
import numpy as np
from PIL import Image

fs = sorted(glob.glob(r'资料/单位分帧动画/fut_arty_ssc1_SS-C-1 岸防导弹组/attack/f*.png'))
print('frames:', len(fs))
for f in fs:
    a = np.asarray(Image.open(f).convert('RGBA'))[:, :, 3] > 128
    H, W = a.shape
    left = a[:, :W // 2].sum()
    right = a[:, W // 2:].sum()
    # 左/右最远突出列(主体质心偏移方向)
    xs = np.nonzero(a.any(axis=0))[0]
    lo, hi = (xs[0], xs[-1]) if len(xs) else (0, 0)
    print('%s op=%.1f%% 左半=%6d 右半=%6d 主体x[%d,%d]' %
          (f.split('\\')[-1], a.mean() * 100, left, right, lo, hi))
