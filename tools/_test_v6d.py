# -*- coding: utf-8 -*-
"""v6c vs v6d 对比: keep% + ASCII 剪影 (问题单位首帧)"""
import glob
import cv2
import numpy as np
from PIL import Image


def matte(arr, mn_floor=135, v6d=True):
    rgbv = arr.astype(np.int16)
    mn = rgbv.min(axis=2)
    sat = rgbv.max(axis=2) - rgbv.min(axis=2)
    h, w = mn.shape
    ok = ((mn >= mn_floor) & (sat <= 75)).astype(np.uint8)
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
    killed = np.isin(lab, list(kill)) if kill else np.zeros((h, w), bool)
    keepc = ~killed
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(keepc.astype(np.uint8))
    if n3 > 1:
        big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))
        keep = lab3 == big
    else:
        keep = keepc
    if v6d:
        inv = (~keep).astype(np.uint8)
        nh, labh = cv2.connectedComponents(inv)
        borderh = set()
        for edge in (labh[0, :], labh[-1, :], labh[:, 0], labh[:, -1]):
            borderh |= set(np.unique(edge).tolist())
        borderh.discard(0)
        holes = 0
        for hi in range(1, nh):
            if hi not in borderh:
                keep |= (labh == hi)
                holes += 1
        nw = ((mn >= 230) & (sat <= 60)).astype(np.uint8)
        nn, labn = cv2.connectedComponents(nw)
        reach = set()
        for edge in (labn[0, :], labn[-1, :], labn[:, 0], labn[:, -1]):
            reach |= set(np.unique(edge).tolist())
        reach.discard(0)
        trimmed = 0
        if reach:
            rm = np.isin(labn, list(reach))
            trimmed = int((keep & rm).sum())
            keep &= ~rm
    row_solid = (keep.sum(axis=1) >= 3)
    if row_solid.any():
        keep[int(np.where(row_solid)[0].max()) + 4:, :] = False
    if v6d:
        return keep, holes, trimmed
    return keep, 0, 0


def ascii_map(m):
    ys, xs = np.where(m)
    if not len(ys):
        return '(empty!)'
    H, W = m.shape
    lines = []
    for gy in range(14):
        row = ''
        for gx in range(28):
            y0 = H * gy // 14; y1 = H * (gy + 1) // 14
            x0 = W * gx // 28; x1 = W * (gx + 1) // 28
            d = m[y0:y1, x0:x1].mean()
            row += ' .:-=+*#%@'[min(9, int(d * 10))]
        lines.append(row)
    return '\n'.join(lines)


CASES = [
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/idle', 135, True),
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/attack', 135, True),
    (r'资料/单位分帧动画/cold_mig_MiG战机/idle', 95, True),
    (r'资料/单位分帧动画/mod_marine_海军陆战队班/idle', 135, True),
    (r'资料/单位分帧动画/mod_technical_武装皮卡/idle', 135, True),
    (r'资料/单位分帧动画/mod_mlrs_MLRS火箭炮/attack', 135, True),
]

for d, floor, show in CASES:
    fs = sorted(glob.glob(d + '/raw/r*.png'))
    if not fs:
        print(d, 'NO RAW'); continue
    arr = np.asarray(Image.open(fs[len(fs) // 3]).convert('RGB'))
    kc, _, _ = matte(arr, floor, v6d=False)
    kd, holes, trimmed = matte(arr, floor, v6d=True)
    print('%-52s floor=%d  v6c keep=%5.2f%%  v6d keep=%5.2f%%  回填洞=%d  白修剪=%dpx'
          % (d.split('/')[-2] + '/' + d.split('/')[-1], floor, kc.mean() * 100, kd.mean() * 100, holes, trimmed))
    if show:
        print(ascii_map(kd))
        print()
