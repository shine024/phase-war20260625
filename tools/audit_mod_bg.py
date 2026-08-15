# -*- coding: utf-8 -*-
"""按边缘不透明率分类改造图标：真透明底 vs 烘焙底（方形不透明）。"""
import os
from PIL import Image

D = r"assets/ui/icons/mod_icons"

transparent = []
opaque_sq = []
partial = []

for f in sorted(os.listdir(D)):
    if not f.endswith(".png"):
        continue
    im = Image.open(os.path.join(D, f)).convert("RGBA")
    w, h = im.size
    px = im.load()
    # 边缘一圈（外框 4px）的不透明像素占比
    edge_total = 0
    edge_opaque = 0
    for x in range(w):
        for y in list(range(4)) + list(range(h - 4, h)):
            edge_total += 1
            if px[x, y][3] > 32:
                edge_opaque += 1
    for y in range(h):
        for x in list(range(4)) + list(range(w - 4, w)):
            edge_total += 1
            if px[x, y][3] > 32:
                edge_opaque += 1
    ratio = edge_opaque / float(edge_total)
    name = f.replace("mod_", "").replace(".png", "")
    if ratio < 0.02:
        transparent.append(name)
    elif ratio > 0.90:
        opaque_sq.append((name, round(ratio, 2)))
    else:
        partial.append((name, round(ratio, 2)))

print(f"真透明底: {len(transparent)}")
print(f"方形不透明（烘焙底）: {len(opaque_sq)}")
for e in opaque_sq:
    print("  OPAQUE", e)
print(f"部分贴边: {len(partial)}")
for e in partial:
    print("  PARTIAL", e)
