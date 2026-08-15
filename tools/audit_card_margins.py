# -*- coding: utf-8 -*-
"""扫描存量卡图边距：按 88% 留白约定，找出内容贴边的图。
判定：内容包围盒任一边距 canvas 边 < 10px（即占比 ≥96%）= 贴边；<20px = 观察名单。"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy")

tight = []   # <10px margin
watch = []   # 10-20px margin

for f in sorted(os.listdir(ENEMY)):
    if not f.endswith(".png"):
        continue
    im = Image.open(os.path.join(ENEMY, f)).convert("RGBA")
    w, h = im.size
    if (w, h) != (512, 512):
        tight.append((f, f"非512方形:{w}x{h}"))
        continue
    bbox = im.getbbox()
    if bbox is None:
        tight.append((f, "全透明"))
        continue
    x0, y0, x1, y1 = bbox
    margins = [x0, y0, w - x1, h - y1]
    m = min(margins)
    entry = (f, m, margins)
    if m < 10:
        tight.append(entry)
    elif m < 20:
        watch.append(entry)

print(f"贴边（边距<10px，含非方形/异常）: {len(tight)} 张")
for e in tight:
    print("  ", e)
print(f"\n观察名单（10-20px）: {len(watch)} 张")
for e in watch[:20]:
    print("  ", e)
