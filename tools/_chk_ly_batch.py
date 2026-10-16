# -*- coding: utf-8 -*-
"""批产物总览网格(5 列),340² 缩图+编号标注。"""
import glob
import os

from PIL import Image, ImageDraw

fs = sorted(glob.glob('.godot/unit_review/lingyao/*.png'), key=os.path.getmtime)
COLS, S = 5, 340
rows = (len(fs) + COLS - 1) // COLS
c = Image.new('RGB', (COLS * S, rows * S), (40, 40, 48))
d = ImageDraw.Draw(c)
for i, p in enumerate(fs):
    im = Image.open(p).convert('RGB').resize((S, S))
    c.paste(im, ((i % COLS) * S, (i // COLS) * S))
    d.text(((i % COLS) * S + 6, (i // COLS) * S + 6),
           os.path.basename(p).encode('ascii', 'replace').decode()[:28], fill=(255, 255, 0))
c.save('tools/_chk_ly_batch.png')
print(len(fs), 'tiles')
