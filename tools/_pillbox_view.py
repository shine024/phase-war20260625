# -*- coding: utf-8 -*-
import glob
import numpy as np
from PIL import Image

for anim in ('idle', 'attack'):
    fs = sorted(glob.glob(r'资料/单位分帧动画/ww1_fort_pillbox_混凝土机枪碉堡/%s/f*.png' % anim))
    print('--- %s (%d 帧)' % (anim, len(fs)))
    for f in (fs[0], fs[len(fs) // 2]):
        arr = np.asarray(Image.open(f).convert('RGBA')).astype(np.int16)
        a = arr[:, :, 3]
        mn = arr[:, :, :3].min(axis=2)
        op = a > 128
        H, W = a.shape
        print(f.split('\\')[-1], 'opaque=%.1f%%' % (op.mean() * 100))
        for gy in range(14):
            row = ''
            for gx in range(28):
                y0, y1 = H * gy // 14, H * (gy + 1) // 14
                x0, x1 = W * gx // 28, W * (gx + 1) // 28
                blk = op[y0:y1, x0:x1]
                d = blk.mean()
                w = ((mn[y0:y1, x0:x1] >= 235) & blk).mean() if blk.any() else 0
                row += 'W' if (d > 0.3 and w > 0.5) else (' .:-=+*#%@'[min(9, int(d * 10))])
            print(row)
