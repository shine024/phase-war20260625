# -*- coding: utf-8 -*-
"""110 碉堡四拍 PIL 程序合成(2026-10-16)。

生成线四掷 16 拍 100% 自发造枪("碉堡+射击孔"视觉概念先验,词面/否定句/参考内容全压不住),
程序合成绕开:TL/BR=卡图本体直贴,TR=左射击孔相机闪光(径向光球 screen 混合),
BL=孔内暗橙余光(冷却拍)。零造枪保证,符合"无枪卡攻击点贴圆形火光绝不造枪"拍板。

产物:poses/110·混凝土机枪碉堡_{TL,TR,BL,BR}.png + 110·混凝土机枪碉堡_开火4格.png(2048²)
用法:python -I -u tools/_tmp_pillbox_composite_20261016.py
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw")

card_path = glob.glob(os.path.join(RAW, "110·混凝土机枪碉堡.png"))[0]
img = np.asarray(Image.open(card_path).convert("RGB")).astype(np.float64)
H, W = img.shape[:2]


def screen_mix(base, glow_rgb):
    """逐通道 screen 混合:glow_rgb 与 base 同形状 (H,W,3),值域 0-1。"""
    return 255.0 - (255.0 - base) * np.clip(1.0 - glow_rgb, 0.0, 1.0)


def radial(cx, cy, r_core, r_halo):
    """径向距离场:core=白核强度,halo=外晕强度(H,W)。"""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    core = np.clip(1.0 - d / r_core, 0.0, 1.0)
    halo = np.clip(1.0 - d / r_halo, 0.0, 1.0) ** 1.8
    return core, halo


# ---- 攻击点坐标(卡图 1024²,左侧射击孔黑缝实测 x155-250 y565-660)----
CX, CY = 198.0, 602.0
R_CORE, R_HALO = 55.0, 132.0

# ---- TR firing:孔上相机闪光 ----
core, halo = radial(CX, CY, R_CORE, R_HALO)
flash = (core[..., None] * 1.15 + halo[..., None] * np.array([1.0, 0.82, 0.45]))
tr = screen_mix(img, flash)

# ---- BL cooling:孔内暗橙余光(矩形收准+亮度 gate:只亮暗黑孔像素,墙/品红不碰)----
X0, X1, Y0, Y1 = 152, 252, 562, 662
yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
dx = np.minimum(xx - X0, X1 - xx)
dy = np.minimum(yy - Y0, Y1 - yy)
edge = np.clip(np.minimum(dx, dy) / 6.0 + 1.0, 0.0, 1.0)  # 矩形内 1,向外 6px 渐落到 0
lum = img @ np.array([0.299, 0.587, 0.114])  # 亮度场:孔内暗黑 <50,品红底 ~83,墙面中高
gate = np.clip((62.0 - lum) / 25.0, 0.0, 1.0)  # 暗像素全亮,>62 全灭,25px 过渡
mask = np.clip(edge * gate, 0.0, 1.0)
bl = screen_mix(img, mask[..., None] * np.array([1.0, 0.60, 0.28]) * 0.38)

# ---- TL/BR:卡图本体直贴 ----
poses = {"TL": img, "TR": tr, "BL": bl, "BR": img}
for k, arr in poses.items():
    out = os.path.join(RAW, "poses", "110·混凝土机枪碉堡_%s.png" % k)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(out)
    print("  pose %s -> %s" % (k, os.path.basename(out)), flush=True)

# ---- 拼 2048² 四联 ----
grid = Image.new("RGB", (2048, 2048))
for i, k in enumerate(["TL", "TR", "BL", "BR"]):
    grid.paste(Image.fromarray(np.clip(poses[k], 0, 255).astype(np.uint8)),
               ((i % 2) * 1024, (i // 2) * 1024))
grid_path = os.path.join(RAW, "110·混凝土机枪碉堡_开火4格.png")
grid.save(grid_path)
print("拼合 -> %s" % os.path.basename(grid_path), flush=True)
