# -*- coding: utf-8 -*-
"""fut_mech idle 帧评估: 选最优帧替换卡图"""
import glob
import numpy as np
from PIL import Image

fs = sorted(glob.glob(r'资料/单位分帧动画/034_fut_mech_机甲精英/idle/f*.png'))
ref = Image.open(r'资料/单位分帧动画/_ref/fut_mech_white.jpg').convert('L').resize((64, 64))
rp = np.asarray(ref).astype(float)
rm = (rp < 245).astype(float)
for f in fs:
    im = Image.open(f).convert('RGBA')
    m = np.asarray(im.resize((64, 64)).getchannel('A')) >= 128
    mi = m.astype(float)
    iou = (mi * rm).sum() / max(((mi + rm) > 0).sum(), 1)
    print('%s opaque=%.1f%% iou=%.3f' % (f.split(chr(92))[-1], 100 * (np.asarray(im.getchannel('A')) >= 200).mean(), iou))
