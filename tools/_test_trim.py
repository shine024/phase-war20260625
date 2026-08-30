# -*- coding: utf-8 -*-
"""修剪阈值对比: (230,60) vs (200,50) —— 烟团应清除, 白机身应保住"""
import glob
import cv2
import numpy as np
from PIL import Image


def matte(arr, mn_floor, trim_mn, trim_sat):
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
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    e = cv2.Canny(gray, 50, 150)
    e = cv2.dilate(e, np.ones((5, 5), np.uint8))
    nonedge = (e == 0).astype(np.uint8)
    nn, labn = cv2.connectedComponents(nonedge)
    border_n = set()
    for edge in (labn[0, :], labn[-1, :], labn[:, 0], labn[:, -1]):
        border_n |= set(np.unique(edge).tolist())
    border_n.discard(0)
    sealed = np.ones((h, w), bool)
    for ni in range(1, nn):
        if ni in border_n:
            sealed &= ~(labn == ni)
    union = (keepc | sealed).astype(np.uint8)
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(union)
    if n3 > 1:
        big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))
        keep = lab3 == big
    else:
        keep = union.astype(bool)
    if keep.mean() > 0.45:
        n3, lab3, st3, _ = cv2.connectedComponentsWithStats(keepc.astype(np.uint8))
        if n3 > 1:
            big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))
            keep = lab3 == big
        else:
            keep = keepc
    nw = ((mn >= trim_mn) & (sat <= trim_sat)).astype(np.uint8)
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
    # 残留% = keep 内 mn>=240 的占比(与 check 口径一致)
    resid = float((keep & (mn >= 240)).sum()) / max(1, keep.sum()) * 100
    return keep.mean() * 100, resid


CASES = [
    (r'资料/单位分帧动画/ww1_mortar_迫击炮组/attack', 135, '烟团(应清除)'),
    (r'资料/单位分帧动画/ww1_rifle_步兵班步枪/attack', 135, '齐射白烟'),
    (r'资料/单位分帧动画/cold_m60_M60机枪班/attack', 135, '扫射烟'),
    (r'资料/单位分帧动画/ww2_pschreck_铁拳反坦克兵/attack', 135, '尾焰烟'),
    (r'资料/单位分帧动画/mod_apache_阿帕奇直升机/idle', 135, '旋翼灰盘'),
    (r'资料/单位分帧动画/cold_mig_MiG战机/idle', 95, '银白机身(应保住)'),
    (r'资料/单位分帧动画/mod_technical_武装皮卡/idle', 135, '白皮卡(应保住)'),
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/idle', 135, '白部件(应保住)'),
    (r'资料/单位分帧动画/mod_marine_海军陆战队班/idle', 135, '白军服(应保住)'),
]

for d, floor, note in CASES:
    fs = sorted(glob.glob(d + '/raw/r*.png'))
    if not fs:
        continue
    arr = np.asarray(Image.open(fs[len(fs) * 2 // 3]).convert('RGB'))
    k230, r230 = matte(arr, floor, 230, 60)
    k200, r200 = matte(arr, floor, 200, 50)
    print('%-40s %-16s  trim230: keep=%5.2f%% 残留=%5.2f%%   trim200: keep=%5.2f%% 残留=%5.2f%%'
          % (d.split('/')[-2][:20] + '/' + d.split('/')[-1], note, k230, r230, k200, r200))
