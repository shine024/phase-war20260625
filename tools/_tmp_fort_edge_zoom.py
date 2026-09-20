# -*- coding: utf-8 -*-
"""对贴边开火帧做边缘放大：确认火光是否被帧边界硬切（直切线）"""
import os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT = os.path.join(ROOT, ".godot", "audit_sheets")

# (dir, frame, edge)  edge: L=左缘放大条, T=顶缘放大条
SUSPECTS = [
    ("ww1_fort_artillery", 2, "L"),
    ("ww1_fort_pillbox", 4, "L"),
    ("fut_fort_ion", 4, "L"),
    ("mod_fort_citadel", 5, "L"),
    ("mod_fort_phalanx", 6, "L"),
    ("cold_fort_missile", 9, "T"),
    ("cold_fort_missile", 10, "T"),
    ("ww2_fort_bunker", 6, "L"),
]

FS = 256
ROWS = []
for d, idx, edge in SUSPECTS:
    im = Image.open(os.path.join(ANIM, d, "sheet_attack.png")).convert("RGBA")
    fr = im.crop((idx * FS, 0, (idx + 1) * FS, im.height))
    if edge == "L":
        strip = fr.crop((0, 0, 72, im.height))          # 左 72px 全高
    else:
        strip = fr.crop((0, 0, FS, 72))                 # 顶 72px 全宽
    a = np.asarray(strip)[:, :, 3]
    # 最外 2px 列/行的不透明像素数 = 被切证据
    edge_opaque = int((a[:2].__gt__(40)).sum() if edge == "T" else (a[:, :2] > 40).sum())
    ROWS.append((d, idx, edge, strip, edge_opaque))

CELLW = 460
rowh = 300
cv = Image.new("RGB", (CELLW, rowh * len(ROWS)), (24, 26, 30))
dr = ImageDraw.Draw(cv)
for r, (d, idx, edge, strip, op) in enumerate(ROWS):
    y = r * rowh
    z = strip.resize((strip.width * 2, strip.height * 2), Image.NEAREST)
    z.thumbnail((CELLW - 140, rowh - 30))
    bg = Image.new("RGBA", (z.width, z.height), (60, 62, 68, 255))
    bg.paste(z, (0, 0), z)
    cv.paste(bg.convert("RGB"), (130, y + 24))
    dr.text((6, y + 6), f"{d}#{idx} edge:{edge}", fill=(255, 210, 80))
    dr.text((6, y + 22 + rowh // 2), f"边缘2px\n不透明\n像素={op}", fill=(255, 90, 60) if op > 0 else (160, 160, 160))

op = os.path.join(OUT, "fort_edge_zoom.png")
cv.save(op)
print("made", op)
