# -*- coding: utf-8 -*-
import glob
import numpy as np
from PIL import Image

fs = sorted(glob.glob(r'资料/单位分帧动画/mod_apache_阿帕奇直升机/idle/f*.png'))
for idx in (0, 3):
    arr = np.asarray(Image.open(fs[idx]).convert('RGBA')).astype(np.int16)
    a = arr[:, :, 3]
    mn = arr[:, :, :3].min(axis=2)
    op = a > 128
    H, W = a.shape
    print('--- f%02d opaque=%.2f%%' % (idx, op.mean() * 100))
    for gy in range(16):
        row = ''
        for gx in range(32):
            y0 = H * gy // 16; y1 = H * (gy + 1) // 16
            x0 = W * gx // 32; x1 = W * (gx + 1) // 32
            blk = op[y0:y1, x0:x1]
            d = blk.mean()
            w = ((mn[y0:y1, x0:x1] >= 235) & blk).mean() if blk.any() else 0
            row += 'W' if (d > 0.3 and w > 0.5) else (' .:-=+*#%@'[min(9, int(d * 10))])
        print(row)
