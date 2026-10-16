#!/usr/bin/env python3
"""攻击帧来源判别探针（v6.71 盘点用，一次性）。

判别逻辑：sheet_attack f0 与 sheet_idle f0 灰度差像素集 D 的「包围盒填充率」。
- 程序合成（车体零漂移+特效外化）：D 集中在焰烟小块 → 填充率低
- img2img 直出（形变/变方向）：D 弥散全车身 → 填充率高
统计全 271 目录，输出分类名单。阈值经验值，边界样本人工复核。
"""
import json
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
T_DIFF = 14          # 灰度差阈值
FRAME = 256

def probe(d):
    p_att = os.path.join(ANIM, d, "sheet_attack.png")
    p_idle = os.path.join(ANIM, d, "sheet_idle.png")
    if not (os.path.exists(p_att) and os.path.exists(p_idle)):
        return None
    a = Image.open(p_att).convert("L")
    i = Image.open(p_idle).convert("L")
    fs = FRAME
    a = a.crop((0, 0, min(fs, a.width), min(fs, a.height))).resize((128, 128))
    i = i.crop((0, 0, min(fs, i.width), min(fs, i.height))).resize((128, 128))
    pa, pi = a.load(), i.load()
    xs, ys, n = [], [], 0
    for y in range(128):
        for x in range(128):
            if abs(pa[x, y] - pi[x, y]) > T_DIFF:
                xs.append(x); ys.append(y); n += 1
    if n < 30:
        return {"d": d, "n": n, "fill": 0.0, "cat": "near_identical"}
    bw = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1)
    fill = n / float(bw)
    cat = "comp_like" if fill < 0.22 else ("ambiguous" if fill < 0.40 else "gen_like")
    return {"d": d, "n": n, "fill": round(fill, 3), "cat": cat}

cats = {"comp_like": [], "ambiguous": [], "gen_like": [], "near_identical": [], "missing": []}
for d in sorted(os.listdir(ANIM)):
    if not os.path.isdir(os.path.join(ANIM, d)):
        continue
    r = probe(d)
    if r is None:
        cats["missing"].append(d)
    else:
        cats[r["cat"]].append((d, r["fill"]))

for k in ("comp_like", "gen_like", "ambiguous", "near_identical", "missing"):
    lst = cats[k]
    print("%s: %d" % (k, len(lst)))
print()
print("gen_like（直出形变嫌疑，优先程序合成重做）:")
for d, f in sorted(cats["gen_like"], key=lambda t: -t[1]):
    print("  %-32s fill=%.2f" % (d, f))
print()
print("ambiguous（边界，需目验）:")
for d, f in sorted(cats["ambiguous"], key=lambda t: -t[1]):
    print("  %-32s fill=%.2f" % (d, f))
