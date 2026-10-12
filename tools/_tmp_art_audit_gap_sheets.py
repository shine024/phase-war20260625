# -*- coding: utf-8 -*-
"""补齐覆盖缺口的三组拼版：mod_icons 全量、卡图根目录散卡+battle贴花、boss散帧目录。"""
import os, math, glob
from PIL import Image, ImageDraw, ImageFont

OUT = '.godot/art_audit_20261011/sheets'
F = ImageFont.truetype('assets/fonts/NotoSansSC-Regular.ttf', 15)

def checker(w, h, sq=8):
    im = Image.new('RGB', (w, h), (120, 120, 120))
    d = ImageDraw.Draw(im)
    for y in range(0, h, sq):
        for x in range(0, w, sq):
            if (x // sq + y // sq) % 2 == 0:
                d.rectangle([x, y, min(x + sq - 1, w - 1), min(y + sq - 1, h - 1)], fill=(150, 150, 150))
    return im

def grid(name, paths, cell, cols, fnt):
    per = cols * math.ceil(2100 / (cell + 26))
    nsheets = math.ceil(len(paths) / per)
    for si in range(nsheets):
        chunk = paths[si * per:(si + 1) * per]
        rows = math.ceil(len(chunk) / cols)
        W = cols * cell + 8 * (cols + 1)
        H = rows * (cell + 26) + 8 * (rows + 1) + 30
        sh = Image.new('RGB', (W, H), (24, 24, 24)); dr = ImageDraw.Draw(sh)
        dr.text((8, 4), f'{name} #{si+1}/{nsheets}', fill=(255, 210, 80), font=fnt)
        for i, p in enumerate(chunk):
            r, c = divmod(i, cols)
            x0 = 8 + c * (cell + 8); y0 = 30 + r * (cell + 26 + 8)
            sh.paste(checker(cell, cell), (x0, y0))
            try:
                im = Image.open(p).convert('RGBA')
                s = min(cell / im.width, cell / im.height, 1.6)
                im2 = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
                sh.paste(im2, (x0 + (cell - im2.width) // 2, y0 + (cell - im2.height) // 2), im2)
                lab = os.path.basename(p)
                if len(lab) > 24: lab = lab[:23] + '…'
                dr.text((x0 + 2, y0 + cell + 2), lab, fill=(230, 230, 230), font=fnt)
            except Exception as e:
                dr.text((x0 + 2, y0 + cell + 2), f'ERR {e}'[:30], fill=(255, 80, 80), font=fnt)
        out = f'{OUT}/{name}/sheet_{si+1:02d}.png'
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sh.save(out); print(out, sh.size)

fnt = F
mod = sorted(glob.glob('assets/ui/icons/mod_icons/*.png')) + sorted(glob.glob('assets/ui/icons/mod_icons_pilot_stage/*.png')) + sorted(glob.glob('assets/ui/icons/unit_decals/*.png'))
grid('mod_icons', mod, 190, 5, fnt)
root = sorted(glob.glob('assets/card_icons/*.png')) + sorted(glob.glob('assets/battle/decals/*.png'))
grid('cards_root_decals', root, 260, 4, fnt)

# 散帧目录：每目录一行
loose = {}
for p in sorted(glob.glob('assets/effects/unit_anims/*/*.png')):
    b = os.path.basename(p)
    if b.startswith('sheet_') or 'backup' in b: continue
    loose.setdefault(os.path.basename(os.path.dirname(p.replace('\\', '/'))), []).append(p)
cell = 96
cols = max(len(v) for v in loose.values())
W = 200 + cols * (cell + 4) + 8
H = 30 + len(loose) * (cell + 22) + 10
sh = Image.new('RGB', (W, H), (24, 24, 24)); dr = ImageDraw.Draw(sh)
dr.text((6, 6), f'loose frames ({sum(len(v) for v in loose.values())} files / {len(loose)} dirs)', fill=(255, 210, 80), font=fnt)
y = 30
for d, files in loose.items():
    dr.text((6, y + cell // 2 - 8), d[:24], fill=(120, 200, 255), font=fnt)
    x = 200
    for p in files:
        im = Image.open(p).convert('RGBA')
        s = cell / max(im.width, im.height)
        im2 = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
        sh.paste(checker(cell, cell), (x, y))
        sh.paste(im2, (x + (cell - im2.width) // 2, y + (cell - im2.height) // 2), im2)
        x += cell + 4
    y += cell + 22
out = f'{OUT}/loose_frames/sheet_01.png'
os.makedirs(os.path.dirname(out), exist_ok=True)
sh.save(out); print(out, sh.size)
