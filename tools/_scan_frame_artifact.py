# -*- coding: utf-8 -*-
# 临时扫描：卡图"烤进矩形框"残渣检测（v27.9 暴风突击队框 bug 同款）
# 特征：不透明 bbox 四边存在 >92% 长度的直线不透明带
from PIL import Image
import glob

SUSPECTS = []
for d in ['assets/card_icons/enemy', 'assets/card_icons/player']:
    for p in sorted(glob.glob(d + '/vis_*.png')):
        im = Image.open(p).convert('RGBA')
        W, H = im.size
        a = im.getchannel('A')
        px = a.load()
        bbox = a.getbbox()
        if bbox is None:
            continue
        x0, y0, x1, y1 = bbox
        bw, bh = x1 - x0, y1 - y0
        if bw < 50 or bh < 50:
            continue

        def row_frac(yy):
            return sum(1 for xx in range(x0, x1) if px[xx, yy] > 32) / bw

        def col_frac(xx):
            return sum(1 for yy in range(y0, y1) if px[xx, yy] > 32) / bh

        top = max(row_frac(y0 + i) for i in range(3) if y0 + i < y1)
        bot = max(row_frac(y1 - 1 - i) for i in range(3) if y1 - 1 - i > y0)
        lef = max(col_frac(x0 + i) for i in range(3) if x0 + i < x1)
        rig = max(col_frac(x1 - 1 - i) for i in range(3) if x1 - 1 - i > x0)
        if top > 0.92 and bot > 0.92 and lef > 0.92 and rig > 0.92:
            SUSPECTS.append((p, (x0, y0, x1, y1)))

print('suspects:', len(SUSPECTS))
for s in SUSPECTS:
    print(' ', s)
