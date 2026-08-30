#!/usr/bin/env python3
"""临时标定脚本：用合成图（已知真值海陆）校准 check_main_map.py 的分类器阈值。"""
import json
import math
import sys

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = "docs/地图重设计/generated/greenland_20260828_flow"
GEO = "docs/地图重设计/generated/greenland/grl.geo.json"
W, H = 2560, 1440
KM_LAT = 111.0
KM_LON = 111.0 * math.cos(math.radians(71.5))

d = json.load(open(GEO, encoding="utf-8"))
ring = d["features"][0]["geometry"]["coordinates"][0]
xc, yc = -42.75, 71.85
sx = np.array([(yc - p[1]) * KM_LAT for p in ring])
sy = np.array([(xc - p[0]) * KM_LON for p in ring])
land_h = 640.0 * (W / 1312.0)
scale = land_h / (sy.max() - sy.min())
x0 = (W - (sx.max() - sx.min()) * scale) / 2 - sx.min() * scale
y0 = (H - land_h) / 2 - sy.min() * scale
from PIL import ImageDraw
mim = Image.new("L", (W, H), 0)
ImageDraw.Draw(mim).polygon([(x0 + x * scale, y0 + y * scale) for x, y in zip(sx, sy)], fill=255)
ref_land = np.asarray(mim) > 127
ref_sea = ~ref_land

im = Image.open(f"{ROOT}/greenland_tex2_main.png").convert("RGB")
arr = np.asarray(im, np.float32)
hsv = np.asarray(im.convert("HSV"), np.float32)
Hh, S, V = hsv[..., 0] * 360 / 255.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0

print("=== 海分类器参数扫描（目标：与真值海 IoU 最高）===")
best = None
for hue_lo, hue_hi in [(170, 265), (180, 260), (185, 255), (190, 250)]:
    for s_min in (0.18, 0.25, 0.30):
        for v_max in (0.55, 0.70, 0.85):
            sea = (Hh >= hue_lo) & (Hh <= hue_hi) & (S > s_min) & (V < v_max)
            iou = (sea & ref_sea).sum() / max(1, (sea | ref_sea).sum())
            tag = f"hue[{hue_lo},{hue_hi}] S>{s_min} V<{v_max}"
            if best is None or iou > best[0]:
                best = (iou, tag)
            if iou > 0.55:
                print(f"  IoU={iou:.3f}  {tag}")
print(f"  BEST: IoU={best[0]:.3f}  {best[1]}")

print("=== 青色 mask 主导色分析 ===")
cyan = (Hh >= 160) & (Hh <= 205) & (S > 0.30) & (V > 0.40)
print(f"  旧阈值 cyan 占比: {cyan.mean()*100:.1f}%")
ys, xs = np.nonzero(cyan)
if len(xs):
    samp = np.random.default_rng(7).choice(len(xs), min(5000, len(xs)), replace=False)
    cols = arr[ys[samp], xs[samp]].mean(axis=0)
    print(f"  旧 cyan mask 平均色 RGB = ({cols[0]:.0f},{cols[1]:.0f},{cols[2]:.0f})  hue均值={Hh[ys[samp], xs[samp]].mean():.0f}")
for lo, hi, smin, vmin in [(175, 200, 0.35, 0.45), (178, 198, 0.40, 0.50), (172, 202, 0.45, 0.45)]:
    c2 = (Hh >= lo) & (Hh <= hi) & (S > smin) & (V > vmin)
    print(f"  hue[{lo},{hi}] S>{smin} V>{vmin}: {c2.mean()*100:.2f}%")

print("=== 色度（chroma）指标 ===")
chroma = (arr.max(axis=2) - arr.min(axis=2)) / 255.0
print(f"  chroma mean={chroma.mean():.3f}  p99={np.percentile(chroma,99):.3f}")

print("=== 陆上暗蓝灰阴影量（旧分类器的假海来源）===")
sea_old = (Hh >= 170) & (Hh <= 265) & (S > 0.18) & (V < 0.85)
false_sea = sea_old & ref_land
print(f"  假海占旧 sea 的 {false_sea.sum()/max(1,sea_old.sum())*100:.0f}%（在陆地上）")
