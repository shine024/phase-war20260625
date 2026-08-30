# -*- coding: utf-8 -*-
"""apache 旋翼残影: 近白修剪阈值(nw_floor)扫描"""
import glob
import cv2
import numpy as np
from PIL import Image


def matte(arr, nw_floor):
    rgbv = arr.astype(np.int16)
    mn = rgbv.min(axis=2)
    sat = rgbv.max(axis=2) - rgbv.min(axis=2)
    ok = ((mn >= 135) & (sat <= 75)).astype(np.uint8)
    num, lab = cv2.connectedComponents(ok)
    kill = set()
    for edge in (lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]):
        kill |= set(np.unique(edge).tolist())
    kill.discard(0)
    pw = ((mn >= 240) & (sat <= 75)).astype(np.uint8)
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats(pw)
    for i in range(1, n2):
        x, y, bw2, bh2, area = st2[i]
        if max(bw2, bh2) >= 40:
            kill.add(int(lab[int(y + bh2 // 2), int(x + bw2 // 2)]))
    kill.discard(0)
    killed = np.isin(lab, list(kill)) if kill else np.zeros(mn.shape, bool)
    keepc = ~killed
    union = keepc.astype(np.uint8)
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(union)
    big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))
    keep = lab3 == big
    nw = ((mn >= nw_floor) & (sat <= 60)).astype(np.uint8)
    nn2, labn2 = cv2.connectedComponents(nw)
    reach = set()
    for edge in (labn2[0, :], labn2[-1, :], labn2[:, 0], labn2[:, -1]):
        reach |= set(np.unique(edge).tolist())
    reach.discard(0)
    if reach:
        keep &= ~np.isin(labn2, list(reach))
    row_solid = (keep.sum(axis=1) >= 3)
    if row_solid.any():
        keep[int(np.where(row_solid)[0].max()) + 4:, :] = False
    resid = float((keep & (mn >= 240)).sum()) / max(1, keep.sum()) * 100
    return keep, resid


def ascii_map(m, mn):
    H, W = m.shape
    lines = []
    for gy in range(14):
        row = ''
        for gx in range(28):
            y0 = H * gy // 14; y1 = H * (gy + 1) // 14
            x0 = W * gx // 28; x1 = W * (gx + 1) // 28
            blk = m[y0:y1, x0:x1]
            d = blk.mean()
            w = ((mn[y0:y1, x0:x1] >= 235) & blk).mean() if blk.any() else 0
            row += 'W' if (d > 0.3 and w > 0.5) else ' .:-=+*#%@'[min(9, int(d * 10))]
        lines.append(row)
    return '\n'.join(lines)


for d, fi in [(r'资料/单位分帧动画/mod_apache_阿帕奇直升机/idle', 12),
              (r'资料/单位分帧动画/mod_apache_e_阿帕奇精英/idle', 12)]:
    fs = sorted(glob.glob(d + '/raw/r*.png'))
    arr = np.asarray(Image.open(fs[fi]).convert('RGB'))
    rgbm = arr.astype(np.int16).min(axis=2)
    print('==', d.split('/')[-2])
    for fl in (230, 210, 195):
        k, resid = matte(arr, fl)
        print('-- nw_floor=%d keep=%.2f%% 白残留=%.2f%%' % (fl, k.mean() * 100, resid))
        print(ascii_map(k, rgbm))
