# -*- coding: utf-8 -*-
"""v6g: v6e + 烟团白核检验(白核区域需含/邻 v6c 深色部件才保留)"""
import glob
import cv2
import numpy as np
from PIL import Image

K3 = np.ones((3, 3), np.uint8)


def matte(arr, mn_floor):
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
    # ---- v6g: 烟团白核检验 ----
    sealed_u = sealed.astype(np.uint8)
    ns, labs, sts, _ = cv2.connectedComponentsWithStats(sealed_u)
    n_smoke = 0
    for i in range(1, ns):
        x, y, bw2, bh2, area = sts[i]
        if area < 1500:
            continue
        R = (labs == i)
        core = R & (mn >= 240) & (sat <= 75)
        if core.sum() < 1500:
            continue  # 无大纯白核 → 不是烟
        if float((R & keepc).sum()) >= 150:
            continue  # 内含 v6c 深色部件 → 真主体
        ring = cv2.dilate(R.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool) & ~R
        if ring.sum() > 0 and float((ring & keepc).sum()) / ring.sum() >= 0.15:
            continue  # 邻环有 v6c 部件 → 真主体
        sealed &= ~R  # 烟团
        n_smoke += 1
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
    row_solid = (keep.sum(axis=1) >= 3)
    if row_solid.any():
        keep[int(np.where(row_solid)[0].max()) + 4:, :] = False
    resid = float((keep & (mn >= 240)).sum()) / max(1, keep.sum()) * 100
    return keep.mean() * 100, resid, n_smoke


CASES = [
    (r'资料/单位分帧动画/ww1_mortar_迫击炮组/attack', 135, '烟团应清除'),
    (r'资料/单位分帧动画/ww1_rifle_步兵班步枪/attack', 135, '齐射白烟'),
    (r'资料/单位分帧动画/cold_m60_M60机枪班/attack', 135, '扫射烟'),
    (r'资料/单位分帧动画/ww2_pschreck_铁拳反坦克兵/attack', 135, '尾焰烟'),
    (r'资料/单位分帧动画/mod_apache_阿帕奇直升机/idle', 135, '旋翼灰盘'),
    (r'资料/单位分帧动画/cold_mig_MiG战机/idle', 95, '银白机身保'),
    (r'资料/单位分帧动画/mod_technical_武装皮卡/idle', 135, '白皮卡保'),
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/idle', 135, '白部件保'),
    (r'资料/单位分帧动画/mod_abrams_艾布拉姆斯坦克/attack', 135, '白部件保'),
    (r'资料/单位分帧动画/mod_marine_海军陆战队班/idle', 135, '白军服保'),
    (r'资料/单位分帧动画/ww2_tiger_虎式坦克/idle', 135, '对照正常'),
]

for d, floor, note in CASES:
    fs = sorted(glob.glob(d + '/raw/r*.png'))
    if not fs:
        continue
    arr = np.asarray(Image.open(fs[len(fs) * 2 // 3]).convert('RGB'))
    k, resid, ns = matte(arr, floor)
    print('%-42s %-12s keep=%5.2f%% 残留=%5.2f%% 杀烟团=%d'
          % (d.split('/')[-2][:22] + '/' + d.split('/')[-1], note, k, resid, ns))
