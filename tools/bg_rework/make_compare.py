# -*- coding: utf-8 -*-
"""通用前后对比拼图：全图缩略 + 关键区放大。用法: python make_compare.py before after out [zones]"""
import sys
from PIL import Image

before, after, out = sys.argv[1], sys.argv[2], sys.argv[3]
zones = [(0, 490, 266, 720, 2), (300, 450, 690, 680, 2), (660, 500, 1060, 720, 2), (1014, 500, 1280, 720, 2)]

b = Image.open(before).convert("RGB")
a = Image.open(after).convert("RGB")
rows = [[b.resize((640, 360)), a.resize((640, 360))]]
for zx0, zy0, zx1, zy1, sc in zones:
    pair = []
    for img in (b, a):
        c = img.crop((zx0, zy0, zx1, zy1))
        c = c.resize((c.width * sc, c.height * sc), Image.LANCZOS)
        pair.append(c)
    rows.append(pair)
pad = 6
dims = [(max(i.height for i in r), sum(i.width for i in r) + pad * (len(r) + 1)) for r in rows]
sheet = Image.new("RGB", (max(w for _, w in dims) + pad * 2, sum(h for h, _ in dims) + pad * (len(rows) + 1)), (24, 24, 28))
y = pad
for r, (hh, _) in zip(rows, dims):
    x = pad
    for i in r:
        sheet.paste(i, (x, y)); x += i.width + pad
    y += hh + pad
sheet.save(out)
print("saved:", out)
