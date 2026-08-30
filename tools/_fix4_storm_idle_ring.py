# -*- coding: utf-8 -*-
"""storm idle 定向环擦除: Hough 找到的环线走廊全擦(不限 alpha), 仅限外沿 band, 脚线已核实安全"""
import glob
import os

import cv2
import numpy as np
from PIL import Image

ADIR = r'资料/单位分帧动画/ww1_storm_暴风突击队/idle'
BAND = 80
n = 0
for f in sorted(glob.glob(os.path.join(ADIR, 'f*.png'))):
    arr = np.asarray(Image.open(f).convert('RGBA')).copy()
    a = arr[..., 3]
    mask = (a >= 64).astype(np.uint8)
    lines = cv2.HoughLinesP(mask, 1, np.pi / 180, threshold=120,
                            minLineLength=110, maxLineGap=8)
    if lines is None:
        continue
    h, w = a.shape
    touched = False
    for ln in lines.reshape(-1, 4):
        x1, y1, x2, y2 = [int(v) for v in ln]
        horiz = abs(y1 - y2) <= 3
        vert = abs(x1 - x2) <= 3
        if not (horiz or vert):
            continue
        if horiz and not (min(y1, y2) < BAND or max(y1, y2) > h - BAND):
            continue
        if vert and not (min(x1, x2) < BAND or max(x1, x2) > w - BAND):
            continue
        if horiz:
            y0 = min(y1, y2)
            arr[max(0, y0 - 4):y0 + 5, max(0, min(x1, x2) - 4):min(w, max(x1, x2) + 5), 3] = 0
        else:
            x0 = min(x1, x2)
            arr[max(0, min(y1, y2) - 4):min(h, max(y1, y2) + 5), max(0, x0 - 4):x0 + 5, 3] = 0
        touched = True
    if touched:
        Image.fromarray(arr).save(f)
        n += 1
print('storm idle scrubbed frames:', n)
