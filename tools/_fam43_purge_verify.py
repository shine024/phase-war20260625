# -*- coding: utf-8 -*-
"""存盘锚定净化验收：每键重跑口袋检测——
· 渍（dist∈[100,150) 体内像素）必须 = 0
· 口袋芯（dist<100 体内像素）只统计不打扰（下游 scrub 透明化）
全绿打 ALL CLEAN，否则列残留键。"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fam43_card_anchors as F

import json
cfgs = json.load(open(os.path.join(F.ROOT, ".godot", "unit_review",
                                   "codeanim_configs", "_configs_fam43.json"), encoding="utf-8"))
bad = []
for k in cfgs:
    a = np.asarray(Image.open(os.path.join(F.OUT_DIR, "%s_anchor_raw.png" % k)).convert("RGB"))
    d = np.sqrt(((a.astype(int) - np.array(F.PINK)) ** 2).sum(axis=2))
    pinkish = d < 150
    lab, _ = ndimage.label(pinkish)
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    border.discard(0)
    pocket = pinkish & ~np.isin(lab, list(border))
    stain = int((pocket & (d >= 100)).sum())
    core = int((pocket & (d < 100)).sum())
    flag = "" if stain == 0 else " <-- 残渍"
    print("%-26s stain=%-6d core=%-6d%s" % (k, stain, core, flag))
    if stain:
        bad.append(k)
print("ALL CLEAN" if not bad else "RESIDUAL: %s" % bad)
