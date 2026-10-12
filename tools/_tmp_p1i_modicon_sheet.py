# -*- coding: utf-8 -*-
"""P1-I staging 28 张拼 contact sheet 目验（staging↔原档并排）。"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, '.godot', 'unit_review', 'img25_staging', 'mod_icons')
DST = os.path.join(ROOT, 'assets', 'ui', 'icons', 'mod_icons')
OUT = os.path.join(ROOT, '.godot', 'art_audit_20261011', '_modicon_p1i_review.png')
NAMES = __import__('_tmp_p1i_modicons_deploy', fromlist=['NAMES']).NAMES

CELL, CW, CH = 150, 320, 180
cols = 4
rows = (len(NAMES) + cols - 1) // cols
sheet = Image.new('RGBA', (cols * CW, rows * CH), (60, 60, 60, 255))
d = ImageDraw.Draw(sheet)
for i, n in enumerate(NAMES):
    x, y = (i % cols) * CW + 5, (i // cols) * CH + 22
    new = Image.open(os.path.join(SRC, n + '.png')).convert('RGBA')
    new.thumbnail((CELL, CELL))
    sheet.alpha_composite(new, (x, y))
    old = Image.open(os.path.join(DST, n + '.png')).convert('RGBA')
    old.thumbnail((CELL, CELL))
    sheet.alpha_composite(old, (x + CELL + 8, y))
    d.text((x, y - 16), n[:26], fill=(255, 255, 0, 255))
sheet.save(OUT)
print('saved', OUT, sheet.size)
