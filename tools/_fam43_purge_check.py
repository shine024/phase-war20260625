# -*- coding: utf-8 -*-
"""净化前后对照（自查用）：对净化量大的键重算 pre-purge 锚定，渲染 pocket 差异区
前后 2 联图（原样 vs 净化后），拼一张总表供目验「净化=修渗漏 还是 误伤卡面」。"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fam43_card_anchors as F

ROOT = F.ROOT
OUT = os.path.join(ROOT, ".godot", "unit_review", "fam43_anchor_from_card")

# 净化量 >1500px 的键（从提取日志）
KEYS = ["ww1_arty_m81", "ww2_arty_m81", "cold_sup_zsu23", "ww1_inf_cavalry",
        "ww2_inf_bazooka", "cold_arm_t55", "mod_sup_m6", "ww2_inf_hellcat",
        "ww1_boss_av7", "ww1_arm_rolls", "ww1_fort_pillbox", "mod_arm_m1a2sep"]

dump = F.__dict__  # noqa
cards = F.key_to_card(__import__("json").load(open(F.DUMP, encoding="utf-8")))
cards.update(F.marked_icons())

TILE = 300
cols = 4
rows = (len(KEYS) + 1) // 2
page = Image.new("RGB", (cols * TILE, rows * (TILE + 16)), (18, 18, 22))
d0 = ImageDraw.Draw(page)

for i, k in enumerate(KEYS):
    arr0 = F.extract(cards[k])               # pre-purge
    arr1 = np.asarray(Image.open(os.path.join(OUT, "%s_anchor_raw.png" % k)).convert("RGB")).copy()
    diff = (np.abs(arr0.astype(int) - arr1.astype(int)).sum(axis=2) > 30)
    ys, xs = np.where(diff)
    if len(xs):
        cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
    else:
        cx, cy = 512, 512
    r = 130
    box = (max(0, cx - r), max(0, cy - r), min(1024, cx + r), min(1024, cy + r))
    for j, a in enumerate((arr0, arr1)):
        crop = Image.fromarray(a[box[0]:box[2], box[1]:box[3]] if False else
                               a[box[1]:box[3], box[0]:box[2]])
        tile = crop.resize((TILE, TILE), Image.NEAREST)
        px = (i % 2) * 2 + j
        py = i // 2
        page.paste(tile, (px * TILE, py * (TILE + 16)))
        d0.text((px * TILE + 4, py * (TILE + 16) + TILE + 1),
                "%s %s" % (k, "前" if j == 0 else "后"), fill=(255, 220, 120))

p = os.path.join(OUT, "_purge_check.png")
page.save(p)
print("wrote", p, len(KEYS), "keys")
