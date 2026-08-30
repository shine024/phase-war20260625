# -*- coding: utf-8 -*-
"""v6e 原型: 边缘密封泛洪 (轮廓线挡住白底) ∪ v6c 色彩法 → 最大连通块"""
import glob
import cv2
import numpy as np
from PIL import Image


def matte_v6e(arr, mn_floor=135, canny_lo=50, canny_hi=150, dil=5):
    rgbv = arr.astype(np.int16)
    mn = rgbv.min(axis=2)
    sat = rgbv.max(axis=2) - rgbv.min(axis=2)
    h, w = mn.shape
    # --- v6c 色彩路径 ---
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
    # --- 边缘密封路径 ---
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    e = cv2.Canny(gray, canny_lo, canny_hi)
    e = cv2.dilate(e, np.ones((dil, dil), np.uint8))
    nonedge = (e == 0).astype(np.uint8)
    nn, labn = cv2.connectedComponents(nonedge)
    border = set()
    for edge in (labn[0, :], labn[-1, :], labn[:, 0], labn[:, -1]):
        border |= set(np.unique(edge).tolist())
    border.discard(0)
    sealed = np.ones((h, w), bool)
    for i in range(1, nn):
        if i in border:
            sealed &= ~(labn == i)
    # --- 并集 → 最大连通块 ---
    union = (keepc | sealed).astype(np.uint8)
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(union)
    if n3 > 1:
        big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))
        keep = lab3 == big
    else:
        keep = union.astype(bool)
    # 近白边界可达修剪(v6d-2)
    nw = ((mn >= 230) & (sat <= 60)).astype(np.uint8)
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
    return keep, keepc


def ascii_map(m):
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
    (r'资料/单位分帧动画/cold_mig_MiG战机/idle', 95),
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/idle', 135),
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/attack', 135),
    (r'资料/单位分帧动画/mod_marine_海军陆战队班/idle', 135),
    (r'资料/单位分帧动画/mod_technical_武装皮卡/idle', 135),
    (r'资料/单位分帧动画/mod_mlrs_MLRS火箭炮/attack', 135),
    (r'资料/单位分帧动画/ww1_storm_暴风兵小队/attack', 135),
    (r'资料/单位分帧动画/ww2_tiger_虎式坦克/idle', 135),
    (r'资料/单位分帧动画/mod_apache_阿帕奇/idle', 135),
]

for d, floor in CASES:
    fs = sorted(glob.glob(d + '/raw/r*.png'))
    if not fs:
        print(d, 'NO RAW'); continue
    arr = np.asarray(Image.open(fs[len(fs) // 3]).convert('RGB'))
    k, kc = matte_v6e(arr, floor)
    name = d.replace('资料/单位分帧动画/', '')
    print('%-42s v6c=%5.2f%%  v6e=%5.2f%%' % (name, kc.mean() * 100, k.mean() * 100))
    print(ascii_map(k))
    print()
