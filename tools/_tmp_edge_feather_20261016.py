# -*- coding: utf-8 -*-
"""触边烟火羽化收边 v2(2026-10-16):烟火贴图缘禁裁剪,向品红底渐隐。

v1 两坑(已废):
- np.roll 膨胀在图界环绕 → 近界掩膜污到对侧
- lum>150 只掩亮核 → 实心焰核被压品红、半透明晕保留 = 品红硬边洞

v2 算法:色距掩膜(与角品红 bg 距>32,亮核+暗晕全掩)→ 膨胀 3px → 7px box blur 软边
→ alpha=soft * clip(dist/18)^1.5 向 bg 插值。本体(078 炮管/032 舰体)窗口外不动。

JOBS = 8 处目验定案(078 BR 撤:炮管本体在带内,残留 317=本体+淡雾记账)。
用法:python -I -u tools/_tmp_edge_feather_20261016.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSES = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw", "poses")

# (卡名, 拍, 缘, 缘向 y0, y1)
JOBS = [
    ("030·泰坦Mk.II", "TR", "L", 250, 760),
    ("032·重装母舰", "BL", "R", 820, 1024),
    ("053·特种部队", "TR", "L", 90, 780),
    ("053·特种部队", "BL", "L", 50, 1000),
    ("069·巨神机甲", "TL", "L", 260, 500),
    ("073·维克斯 .303 机枪阵地", "TR", "L", 200, 580),
    ("093·HEL-30 激光炮阵列", "TR", "L", 180, 1024),
    ("116·要塞核心", "TR", "L", 680, 1024),
]
BAND, FADE, DC_TH = 28, 18.0, 32.0


def dilate3(m):
    out = m.copy()
    for dy in (-3, -2, -1, 0, 1, 2, 3):
        for dx in (-3, -2, -1, 0, 1, 2, 3):
            if abs(dy) + abs(dx) > 4:  # 圆形核,防方块感
                continue
            sh = np.zeros_like(m)
            src_y = slice(max(0, -dy), m.shape[0] - max(0, dy))
            dst_y = slice(max(0, dy), m.shape[0] - max(0, -dy))
            src_x = slice(max(0, -dx), m.shape[1] - max(0, dx))
            dst_x = slice(max(0, dx), m.shape[1] - max(0, -dx))
            sh[dst_y, dst_x] = m[src_y, src_x]  # 切片位移,零填充不环绕
            out |= sh
    return out


def box_blur(f, k=7):
    """k×k 均值模糊(float 场,零填充)。"""
    pad = k // 2
    p = np.pad(f, pad, mode="constant")
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    H, W = f.shape
    s = c[k:k + H, k:k + W] - c[0:H, k:k + W] - c[k:k + H, 0:W] + c[0:H, 0:W]
    return s / (k * k)


for name, beat, side, wy0, wy1 in JOBS:
    p = os.path.join(POSES, "%s_%s.png" % (name, beat))
    img = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
    corners = np.concatenate([img[:12, :12].reshape(-1, 3), img[:12, -12:].reshape(-1, 3),
                              img[-12:, :12].reshape(-1, 3), img[-12:, -12:].reshape(-1, 3)])
    bg = corners.mean(axis=0)
    dc = np.sqrt(((img - bg[None, None, :]) ** 2).sum(-1))
    win = np.zeros(dc.shape, bool)
    win[wy0:wy1, :] = True
    m = (dc > DC_TH) & win
    if side == "L":
        m[:, BAND:] = False
    else:
        m[:, :-BAND] = False
    n0 = int(m.sum())
    if n0 == 0:
        print("%s_%s %s 无烟火像素,跳过" % (name, beat, side), flush=True)
        continue
    m = dilate3(m)
    soft = box_blur(m.astype(np.float64), 7)
    if side == "L":
        dist = np.arange(img.shape[1], dtype=np.float64)[None, :]
    else:
        dist = (img.shape[1] - 1 - np.arange(img.shape[1], dtype=np.float64))[None, :]
    alpha = soft * np.clip(dist / FADE, 0.0, 1.0) ** 1.5
    a3 = alpha[..., None]
    img = img * (1 - a3) + bg[None, None, :] * a3
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(p)
    print("%s_%s %s 缘收边 %d px(软边)" % (name, beat, side, n0), flush=True)
