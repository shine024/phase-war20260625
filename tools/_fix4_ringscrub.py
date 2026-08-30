# -*- coding: utf-8 -*-
"""环线擦除(Hough): 擦掉外沿80px环带内的轴向长直线(视频自画框线), 只擦 alpha<248 的环像素
植入 build(可选 per-unit no_ring_scrub 跳过) + 独立全量应用
"""
import glob
import importlib.util
import os
import sys

import cv2
import numpy as np
from PIL import Image

BAND = 80
MINLEN = 110
CORRIDOR = 9


def ring_scrub(arr):
    """arr: HxWx4 uint8 -> bool: 是否有改动"""
    a = arr[..., 3]
    mask = (a >= 64).astype(np.uint8)
    lines = cv2.HoughLinesP(mask, 1, np.pi / 180, threshold=120,
                            minLineLength=MINLEN, maxLineGap=8)
    if lines is None:
        return False
    h, w = a.shape
    touched = False
    out = arr.copy()
    for ln in lines.reshape(-1, 4):
        x1, y1, x2, y2 = [int(v) for v in ln]
        horiz = abs(y1 - y2) <= 3
        vert = abs(x1 - x2) <= 3
        if not (horiz or vert):
            continue
        # 环带约束: 线整体位于外沿 BAND px 内(横线看y, 竖线看x)
        if horiz and not (min(y1, y2) < BAND or max(y1, y2) > h - BAND):
            continue
        if vert and not (min(x1, x2) < BAND or max(x1, x2) > w - BAND):
            continue
        # 只擦半透明(环经羽化是半透, 实体身体是255)
        gate = arr[..., 3] < 248
        yy = np.zeros((h, w), bool)
        xx = np.zeros((h, w), bool)
        if horiz:
            y0 = min(y1, y2)
            yy[max(0, y0 - CORRIDOR // 2):y0 + CORRIDOR // 2 + 1, :] = True
            xx[:, max(0, min(x1, x2) - 4):min(w, max(x1, x2) + 5)] = True
        else:
            x0 = min(x1, x2)
            xx[:, max(0, x0 - CORRIDOR // 2):x0 + CORRIDOR // 2 + 1] = True
            yy[max(0, min(y1, y2) - 4):min(h, max(y1, y2) + 5), :] = True
        zone = yy & xx & gate & (a >= 8)
        if zone.any():
            out[zone, 3] = 0
            touched = True
    if touched:
        arr[...] = out
    return touched


def main():
    BASE = r'资料/单位分帧动画'
    n = tot = 0
    for d in sorted(glob.glob(os.path.join(BASE, '*'))):
        if not os.path.isdir(d) or os.path.basename(d).startswith('_'):
            continue
        for anim in ('idle', 'attack'):
            for f in glob.glob(os.path.join(d, anim, 'f*.png')):
                arr = np.asarray(Image.open(f).convert('RGBA')).copy()
                tot += 1
                if ring_scrub(arr):
                    Image.fromarray(arr).save(f)
                    n += 1
    print('ring-scrubbed %d / %d frames' % (n, tot))


if __name__ == '__main__':
    main()
