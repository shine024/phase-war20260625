#!/usr/bin/env python3
"""渲染格陵兰轮廓参考图（横放：宽端朝西、南尖角朝东），供《主地图图片需求》作附件。
白底 + 深色剪影 + 标注（西·家/起点、东·黑门尖端、5 条战线铺装区示意）。
输出 docs/地图重设计/generated/greenland/outline_reference.png
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEO = os.path.join(ROOT, "docs", "地图重设计", "generated", "greenland", "grl.geo.json")
OUT = os.path.join(ROOT, "docs", "地图重设计", "generated", "greenland", "outline_reference.png")

W, H = 1600, 900
SS = 2

d = json.load(open(GEO, encoding="utf-8"))
ring = d["features"][0]["geometry"]["coordinates"][0]
xc, yc = -42.75, 71.85
KLAT = 111.0
KLON = 111.0 * math.cos(math.radians(71.5))
sx = np.array([(yc - p[1]) * KLAT for p in ring])
sy = np.array([(xc - p[0]) * KLON for p in ring])
land_h = 560.0
scale = land_h / (sy.max() - sy.min())
x0 = (W - (sx.max() - sx.min()) * scale) / 2 - sx.min() * scale
y0 = (H - land_h) / 2 - sy.min() * scale
pts = [(x0 + x * scale, y0 + y * scale) for x, y in zip(sx, sy)]

img = Image.new("RGB", (W, H), (246, 244, 238))
sil = Image.new("L", (W * SS, H * SS), 0)
ImageDraw.Draw(sil).polygon([(x * SS, y * SS) for x, y in pts], fill=210)
sil = sil.resize((W, H), Image.LANCZOS)
img.paste(Image.new("RGB", (W, H), (96, 104, 112)), (0, 0), sil)
d2 = ImageDraw.Draw(img)
# 轮廓线
d2.line(pts + [pts[0]], fill=(40, 46, 52), width=3)

xs = [p[0] for p in pts]
yss = [p[1] for p in pts]
tip_x = max(xs)
tip_y = yss[xs.index(tip_x)]
west_x = min(xs)
land_l = x0 + sx.min() * scale
land_r = x0 + sx.max() * scale
land_t = y0 + sy.min() * scale
land_b = y0 + sy.max() * scale

try:
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 26)
    small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
except Exception:
    font = ImageFont.load_default()
    small = font

# 标注：西端家 / 东端黑门 / 战线铺装区
d2.ellipse([west_x + 40 - 12, H/2 - 60 - 12, west_x + 40 + 12, H/2 - 60 + 12], fill=(216, 130, 60))
d2.text((west_x + 62, H/2 - 78), "西端：余烬要塞（家·起点）", font=font, fill=(150, 80, 20))
d2.ellipse([tip_x - 60 - 12, tip_y - 12, tip_x - 60 + 12, tip_y + 12], fill=(20, 20, 24))
d2.ellipse([tip_x - 60 - 18, tip_y - 18, tip_x - 60 + 18, tip_y + 18], outline=(0, 180, 210), width=3)
d2.text((tip_x - 430, tip_y + 34), "东端尖角：黑色传送门（终点）", font=font, fill=(10, 60, 80))
d2.rectangle([land_l + 200, land_t + 210, land_r - 90, land_b - 90],
             outline=(120, 60, 60), width=2)
d2.text((land_l + 210, land_t + 218), "100 关 · 5 条时代战线铺装区（须为连贯可读陆地）",
        font=small, fill=(120, 60, 60))
d2.text((40, 30), "轮廓参考：格陵兰岛真实海岸线（旋转 90° 横放：宽端朝西、南尖角朝东）",
        font=font, fill=(60, 60, 66))
d2.text((40, H - 44), "地形参考：沿岸峡湾山脉环抱 + 内陆高地冰穹；海只留上下边缘",
        font=small, fill=(90, 90, 96))
img.save(OUT)
print("saved →", OUT)
