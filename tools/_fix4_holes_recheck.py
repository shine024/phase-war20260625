# -*- coding: utf-8 -*-
"""holes 复审: 每动画取帧内最大被包围透明占比, 报 TOP12"""
import glob
import os

import cv2
import numpy as np
from PIL import Image

BASE = r'资料/单位分帧动画'
res = {}
for d in sorted(os.listdir(BASE)):
    dp = os.path.join(BASE, d)
    if not os.path.isdir(dp) or d.startswith('_'):
        continue
    for anim in ('idle', 'attack'):
        worst = 0.0
        for f in glob.glob(os.path.join(dp, anim, 'f*.png')):
            arr = np.asarray(Image.open(f).convert('RGBA'))
            a = arr[..., 3] >= 128
            trans = (~a).astype(np.uint8)
            nf, labf = cv2.connectedComponents(trans)
            border = set()
            for e in (labf[0, :], labf[-1, :], labf[:, 0], labf[:, -1]):
                border |= set(np.unique(e).tolist())
            border.discard(0)
            hole = np.isin(labf, [i for i in range(1, nf) if i not in border]).mean()
            worst = max(worst, 100 * hole)
        if worst > 0:
            res['%s/%s' % (d, anim)] = worst
for k, v in sorted(res.items(), key=lambda x: -x[1])[:12]:
    print('%6.1f%% maxholes  %s' % (v, k))
