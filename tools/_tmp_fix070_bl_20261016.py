# -*- coding: utf-8 -*-
"""070 BL 拍 PIL 合成 + TR 拍天线残雾补擦(2026-10-16)。

BL:recoil 拍生成四掷全灭(车体/水晶自发点亮,炮口出光弹拖尾)→ 程序合成:
    BL = TL 派生,水晶区亮度 x0.80(规范 3.0:水晶 recoil = 电光熄灭晶体微暗一瞬)。
    TL 自带炮口烟团在 recoil 时序合理(击发后烟正浓)。
TR:C 区补擦天线残雾(上段 y440-600 漏擦),行内中值 th=100(雾很白,天线杆保留)。

用法:python -I -u tools/_tmp_fix070_bl_20261016.py
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSES = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw", "poses")
NAME = "070·风暴核心"

LUMW = np.array([0.299, 0.587, 0.114])


def inline_median_replace(img, x0, x1, y0, y1, th):
    """区域内亮像素替换为行内非亮像素中值(保结构)。"""
    for y in range(y0, y1):
        row = img[y, x0:x1]
        lum = row @ LUMW
        m = lum > th
        if m.any() and (~m).any():
            row[m] = np.median(row[~m], axis=0)
        img[y, x0:x1] = row


# ---- TR 补擦:天线残雾上段 ----
tr_p = os.path.join(POSES, NAME + "_TR.png")
tr = np.asarray(Image.open(tr_p).convert("RGB")).astype(np.float64)
inline_median_replace(tr, 690, 870, 440, 600, 100)
Image.fromarray(np.clip(tr, 0, 255).astype(np.uint8)).save(tr_p)
print("TR 补擦天线雾 -> %s" % os.path.basename(tr_p), flush=True)

# ---- BL 合成:TL 派生水晶微暗 ----
tl_p = os.path.join(POSES, NAME + "_TL.png")
bl = np.asarray(Image.open(tl_p).convert("RGB")).astype(np.float64)
H, W = bl.shape[:2]
lum = bl @ LUMW
yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
# 蒙版:水晶区(x280-740, y40-600)内亮像素(lum>95 渐变),边缘 40px 羽化
mx = np.clip((xx - 280) / 40.0, 0, 1) * np.clip((740 - xx) / 40.0, 0, 1)
my = np.clip((yy - 40) / 40.0, 0, 1) * np.clip((600 - yy) / 40.0, 0, 1)
ml = np.clip((lum - 95.0) / 30.0, 0, 1)
mask = np.clip(mx * my * ml, 0, 1)
bl = bl * (1.0 - 0.20 * mask[..., None])  # 亮度 x0.80
bl_p = os.path.join(POSES, NAME + "_BL.png")
Image.fromarray(np.clip(bl, 0, 255).astype(np.uint8)).save(bl_p)
print("BL 合成(水晶 x0.80) -> %s" % os.path.basename(bl_p), flush=True)
