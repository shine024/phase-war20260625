#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""garand attack 视频帧 + 程序化枪口火光混合合成（c96 v5 先例）。

视频抽帧保设计一致性；开火语义（火光/后坐）程序化叠加，保证 attack 可读。
产物：覆盖工作目录 f-frames + sheet_attack.png（512 master），并出审查条带。
"""
import glob
import math
import os
import sys

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = glob.glob(os.path.join(ROOT, "资料", "单位分帧动画", "040_ww2_arm_garand_para_*", "attack"))[0]
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")

MUZZLE = {0: (98, 128), 1: (108, 125), 2: (99, 136), 3: (103, 136), 4: (108, 126),
          5: (102, 131), 6: (102, 136), 7: (107, 129), 8: (99, 132), 9: (105, 135),
          10: (100, 135), 11: (104, 135)}
BIG = (2, 3, 8, 9)
GLOW = (4, 10)
RECOIL = 3


def flash_star(draw, cx, cy, r):
    pts_c = []
    for i in range(10):
        ang = i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        pts_c.append((cx + rr * math.cos(ang), cy + rr * 0.72 * math.sin(ang)))
    draw.polygon(pts_c, fill=(255, 170, 40, 220))
    draw.polygon([(cx + r * 0.5 * math.cos(i * math.pi / 5), cy + r * 0.36 * math.sin(i * math.pi / 5))
                  for i in range(10)], fill=(255, 255, 220, 255))


frames = []
for i in range(12):
    f = Image.open(os.path.join(d, "f%02d.png" % i)).convert("RGBA")
    mx, my = MUZZLE[i]
    if i in BIG:
        shifted = Image.new("RGBA", f.size, (0, 0, 0, 0))
        shifted.paste(f, (RECOIL, 0), f)  # 后坐：整体右移 3px
        f = shifted
    dr = ImageDraw.Draw(f)
    if i in BIG:
        flash_star(dr, mx - 6, my, 26)
        dr.ellipse([mx - 58, my - 5, mx - 10, my + 5], fill=(255, 200, 80, 190))
        dr.ellipse([mx + 40, my + 6, mx + 47, my + 13], fill=(230, 160, 60, 220))  # 抛壳
    elif i in GLOW:
        dr.ellipse([mx - 40, my - 8, mx - 6, my + 8], fill=(255, 180, 70, 120))
    frames.append(f)

sh = Image.new("RGBA", (512 * 12, 512), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sh.paste(f, (i * 512, 0))
    f.save(os.path.join(d, "f%02d.png" % i))
sh.save(os.path.join(d, "sheet_attack.png"))
sh.resize((3072, 256), Image.Resampling.LANCZOS).save(
    os.path.join(REV, "ww2_arm_garand_para_attack_sheet_v6_strip.png"))
print("attack 混合合成完成：火光帧", BIG, "余焰帧", GLOW)
