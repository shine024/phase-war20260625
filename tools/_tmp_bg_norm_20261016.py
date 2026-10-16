# -*- coding: utf-8 -*-
"""背景归一化(2026-10-16,056 四拍内框漂实证):i2i 背景色随机漂
(浅品红内框+暗品红外框,动画播出四格方块边)→ 主体外背景统一填四角标准品红。

算法:色距掩膜 dc>40 分离主体(烟 dc 大保留)→ 掩膜外=背景 → 背景整区填
四角 12px 均值色。淡烟(dc<40)会归入背景被抹——仅用于烟少的拍,烟重拍记账。

用法:python -I -u tools/_tmp_bg_norm_20261016.py 056,066
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

RAW = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "docs", "卡图API重生成_20261014", "raw")


def norm_beat(img):
    corners = np.concatenate([img[:12, :12].reshape(-1, 3), img[:12, -12:].reshape(-1, 3),
                              img[-12:, :12].reshape(-1, 3), img[-12:,-12:].reshape(-1, 3)])
    bg = corners.mean(axis=0)
    dc = np.sqrt(((img - bg[None, None, :]) ** 2).sum(-1))
    m = dc > 40  # 主体(含浓烟)
    # 膨胀 2px 保主体边缘 halo
    out = img.copy()
    out[~m] = bg
    return out, int((~m).sum())


for no in (sys.argv[1].split(",") if len(sys.argv) > 1 else ["056"]):
    for p in sorted(glob.glob(os.path.join(RAW, "poses", no + "*_*.png"))):
        img = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
        out, nbg = norm_beat(img)
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(p)
        print("%s 归一(背景 %d px)" % (os.path.basename(p), nbg), flush=True)
