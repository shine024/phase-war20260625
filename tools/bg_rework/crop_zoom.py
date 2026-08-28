# -*- coding: utf-8 -*-
"""裁出指定区域放大 2x 存盘，供视觉模型细看。用法: python crop_zoom.py <img> x0 y0 x1 y1 out.png"""
import sys
from PIL import Image

src, x0, y0, x1, y1, out = sys.argv[1], *map(int, sys.argv[2:7]), sys.argv[7]
im = Image.open(src).convert("RGB")
c = im.crop((x0, y0, x1, y1))
c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS)
c.save(out)
print("saved", out, c.size)
