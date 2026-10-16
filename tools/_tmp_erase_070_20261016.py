# -*- coding: utf-8 -*-
"""070 TR 拍 PIL 擦除(2026-10-16):车体炮自发点亮四掷不治,程序擦。

A 烟带 x0-212 y646-714      品红区→垂直列插值(firegrid-tracer-erase 法)
B 炮口光斑 x188-242 y658-708 亮像素→区域内暗中值
C 天线座光斑 x763-848 y552-632 亮像素→分带填充(上带品红/下带暗)
D 小塔白汽 x613-672 y488-560 品红区→垂直列插值

用法:python -I -u tools/_tmp_erase_070_20261016.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw",
                    "poses", "070·风暴核心_TR.png")

img = np.asarray(Image.open(PATH).convert("RGB")).astype(np.float64)
H, W = img.shape[:2]


def band_interp(x0, x1, y0, y1, pad=8):
    """品红区烟带擦除:每列用 band 上下缘外 pad px 垂直线性插值填充。"""
    top = img[max(0, y0 - pad):y0, x0:x1].mean(axis=0)      # (w,3) 上缘色
    bot = img[y1:min(H, y1 + pad), x0:x1].mean(axis=0)      # (w,3) 下缘色
    h = y1 - y0
    t = np.linspace(0.0, 1.0, h)[:, None, None]              # (h,1,1)
    img[y0:y1, x0:x1] = top[None, :, :] * (1 - t) + bot[None, :, :] * t


def bright_replace(x0, x1, y0, y1, th, fill=None):
    """区域内亮像素(亮度>th)替换为行内非亮像素中值(保结构:炮管行→炮管色,品红行→品红)。"""
    for y in range(y0, y1):
        row = img[y, x0:x1]
        lum = row @ np.array([0.299, 0.587, 0.114])
        m = lum > th
        if m.any() and (~m).any():
            row[m] = np.median(row[~m], axis=0)
        img[y, x0:x1] = row


# A 车体主炮烟带(品红区)
band_interp(0, 212, 646, 714)
# D 炮塔小塔口白汽(品红区)
band_interp(613, 672, 488, 560)
# B 炮口蓝白光斑:行内中值(保炮管形状)
bright_replace(185, 245, 655, 710, 78)
# C 天线座:上带(y<600)雾→品红角采样;下带光点→行内中值
corner = img[540:552, 745:760].reshape(-1, 3).mean(axis=0)  # 左上角纯品红采样
reg = img[552:600, 763:848]
lum = reg @ np.array([0.299, 0.587, 0.114])
reg[lum > 95] = corner
img[552:600, 763:848] = reg
bright_replace(763, 848, 600, 632, 78)

out = np.clip(img, 0, 255).astype(np.uint8)
Image.fromarray(out).save(PATH)
print("erased -> %s" % os.path.basename(PATH), flush=True)
