#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6：c96 attack 动作重做——先举枪端平(枪口水平指前)再开火(用户裁决)。

动作序列(12帧): 0=持枪基姿态(0°) → 1-3 渐举(+4/+8/+12°) → 4 端平瞄准 →
5 开火(水平火光+曳痕) → 6 开火衰减+后坐 → 7-8 端平 → 9-10 渐降 → 11 回基姿态。
枪口坐标随角度用黄点探针标定: 0°→(147,190), +12°→(90,218), 中间线性插值。
旋转绕脚点(256,471)，脚不动。
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = r"F:\godot fair duet\create\phase-war"
CANVAS = 512
FOOT = 471
ANG = 12.0
MUZ0 = (147, 190)   # 0° 枪口(标定)
MUZ12 = (90, 218)   # +12° 枪口(标定)
PIVOT = (256, FOOT)


def cut_subject(png):
    im = Image.open(png).convert("RGB")
    arr = np.asarray(im)
    mask = (arr.min(axis=2) < 235).astype(np.uint8) * 255
    a = Image.fromarray(mask).filter(ImageFilter.GaussianBlur(0.8))
    rgba = im.convert("RGBA")
    rgba.putalpha(a)
    sub = rgba.crop(a.getbbox())
    w, h = sub.size
    scale = min((CANVAS - 16) / w, (442) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    mir = sub.transpose(Image.FLIP_LEFT_RIGHT)  # 卡图朝右 → sheet 约定朝左
    L0 = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    L0.paste(mir, ((CANVAS - nw) // 2, FOOT - nh), mir)
    return L0


def muz_at(theta):
    t = theta / ANG
    return (MUZ0[0] + (MUZ12[0] - MUZ0[0]) * t, MUZ0[1] + (MUZ12[1] - MUZ0[1]) * t)


def flash_star(d, cx, cy, r):
    import math
    pts = []
    for i in range(10):
        ang = i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(ang), cy + rr * 0.72 * math.sin(ang)))
    d.polygon(pts, fill=(255, 170, 40, 230))
    d.polygon([(cx + r * 0.5 * math.cos(i * math.pi / 5), cy + r * 0.36 * math.sin(i * math.pi / 5))
               for i in range(10)], fill=(255, 255, 210, 255))


L0 = cut_subject(os.path.join(ROOT, "docs", "flow重生成_审查", "战斗卡_批4", "fut_inf_c96.png"))
ANGLES = [0, 4, 8, 12, 12, 12, 12, 12, 12, 8, 4, 0]
FIRE = {5, 6}
frames = []
for i, th in enumerate(ANGLES):
    f = L0.rotate(th, resample=Image.BICUBIC, center=PIVOT)
    rec = 3 if i in (5, 6) else 0  # 后坐: 朝左开火 → 后坐向右(+x)
    if rec:
        f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        tmp = L0.rotate(th, resample=Image.BICUBIC, center=PIVOT)
        f.paste(tmp, (rec, 0), tmp)
    mx, my = muz_at(th)
    mx += rec
    d = ImageDraw.Draw(f)
    if i in FIRE:
        flash_star(d, mx - 8, my, 22 if i == 5 else 14)
        L = 84 if i == 5 else 46
        d.polygon([(mx - 12, my - 4), (mx - 12, my + 4), (mx - 12 - L, my + 1.5), (mx - 12 - L, my - 1.5)],
                  fill=(120, 240, 220, 170 if i == 5 else 110))
        d.ellipse([mx + 26, my + 4, mx + 33, my + 11], fill=(255, 200, 90, 210))  # 抛壳
    frames.append(f)

OUT = os.path.join(ROOT, "assets", "effects", "unit_anims", "fut_inf_c96")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")
fs = CANVAS
sh = Image.new("RGBA", (fs * 12, fs), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sh.paste(f, (i * fs, 0))
    f.save(os.path.join(OUT, "f%02d.png" % i))
sh.save(os.path.join(OUT, "sheet_attack.png"))
sh.save(os.path.join(REV, "fut_inf_c96_attack_sheet.png"))
d = Image.open(os.path.join(OUT, "sheet_attack.png")).convert("RGBA")
d.resize((d.size[0] // 2, 256), Image.LANCZOS).save(os.path.join(OUT, "sheet_attack.png"))

meta_p = os.path.join(OUT, "meta.json")
import json
m = json.load(open(meta_p, encoding="utf-8")) if os.path.exists(meta_p) else {}
m.update({"anim": "attack", "frames": 12, "loop": "raise-level-fire-lower",
          "pose": "先举枪端平(+12°)再水平开火", "generated_at": "v6"})
json.dump(m, open(meta_p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("V6 c96 attack built & deployed")
