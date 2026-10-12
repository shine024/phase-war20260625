# -*- coding: utf-8 -*-
"""美术资产目检拼版生成器：把全项目 png 分组拼成带标签的 contact sheet，供视觉模型逐批检查。
输出: .godot/art_audit_20261011/sheets/<group>/sheet_NN.png
"""
import os, sys, glob, math
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, '.godot', 'art_audit_20261011', 'sheets')
FONT_PATH = os.path.join(ROOT, 'assets', 'fonts', 'NotoSansSC-Regular.ttf')

def font(sz):
    return ImageFont.truetype(FONT_PATH, sz)

def checker(w, h, sq=8):
    im = Image.new('RGB', (w, h), (128, 128, 128))
    d = ImageDraw.Draw(im)
    for y in range(0, h, sq):
        for x in range(0, w, sq):
            if (x // sq + y // sq) % 2 == 0:
                d.rectangle([x, y, x + sq - 1, y + sq - 1], fill=(160, 160, 160))
    return im

def load_rgba(p):
    im = Image.open(p)
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    return im

def fit(img, cw, ch, max_up=1.6):
    s = min(cw / img.width, ch / img.height, max_up)
    return img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)

def truncate(s, n):
    return s if len(s) <= n else s[:n - 1] + '…'

# ---------------- grid mode ----------------
def grid_sheets(name, paths, cell, cols, rows_per_sheet, fnt, fnt_small):
    cellh = cell if isinstance(cell, int) else cell[1]
    cellw = cell if isinstance(cell, int) else cell[0]
    lab = 24
    per = cols * rows_per_sheet
    nsheets = math.ceil(len(paths) / per)
    made = []
    for si in range(nsheets):
        chunk = paths[si * per:(si + 1) * per]
        W = cols * cellw + 8 * (cols + 1)
        H = rows_per_sheet * (cellh + lab) + 8 * (rows_per_sheet + 1) + 30
        sheet = Image.new('RGB', (W, H), (24, 24, 24))
        d = ImageDraw.Draw(sheet)
        d.text((8, 4), f'{name}  #{si + 1}/{nsheets}  ({len(chunk)}/{len(paths)})', fill=(255, 210, 80), font=fnt)
        for i, p in enumerate(chunk):
            r, c = divmod(i, cols)
            x0 = 8 + c * (cellw + 8)
            y0 = 30 + r * (cellh + lab + 8)
            cellbg = checker(cellw, cellh)
            sheet.paste(cellbg, (x0, y0))
            try:
                im = load_rgba(p)
                fitted = fit(im, cellw, cellh)
                sheet.paste(fitted, (x0 + (cellw - fitted.width) // 2, y0 + (cellh - fitted.height) // 2), fitted)
                fname = os.path.basename(p)
                label = truncate(fname, int(cellw / 9)) + f'  {im.width}x{im.height}'
            except Exception as e:
                d.rectangle([x0, y0, x0 + cellw, y0 + cellh], outline=(255, 0, 0), width=3)
                label = f'ERR {os.path.basename(p)}: {e}'
            d.text((x0 + 2, y0 + cellh + 2), label, fill=(230, 230, 230), font=fnt_small)
        out = os.path.join(OUT, name, f'sheet_{si + 1:02d}.png')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sheet.save(out)
        made.append(out)
        print(f'[{name}] {out} ({W}x{H})')
    return made

# ---------------- animrow mode ----------------
def anim_sheets(dirs, fnt, fnt_small, img_w=780, label_w=220, per_sheet=12):
    nsheets = math.ceil(len(dirs) / per_sheet)
    made = []
    for si in range(nsheets):
        chunk = dirs[si * per_sheet:(si + 1) * per_sheet]
        rows = []
        for dd in chunk:
            strips = []
            for kind in ('sheet_idle.png', 'sheet_attack.png'):
                p = os.path.join(dd, kind)
                if os.path.exists(p):
                    strips.append((kind, p))
                else:
                    strips.append((kind, None))
            rows.append((os.path.basename(dd), strips))
        H = 30 + sum(8 + max((fit(load_rgba(p), img_w, 10000).height if p else 14) for _, p in r[1]) for r in rows)
        H = 30 + sum(10 + 16 + max([(fit(load_rgba(p), img_w, 10000).height if p else 12) for _, p in r[1]]) for r in rows)
        W = label_w + img_w + 30
        sheet = Image.new('RGB', (W, H), (24, 24, 24))
        d = ImageDraw.Draw(sheet)
        d.text((8, 4), f'{os.path.basename(os.path.dirname(chunk[0]))}..{os.path.basename(chunk[-1])}  #{si + 1}/{nsheets}', fill=(255, 210, 80), font=fnt)
        y = 30
        for dname, strips in rows:
            d.text((6, y + 2), truncate(dname, 26), fill=(120, 200, 255), font=fnt)
            maxh = 12
            x = label_w
            for kind, p in strips:
                if p:
                    im = load_rgba(p)
                    fitted = fit(im, img_w // 2 - 5, 10000)
                    bg = checker(fitted.width, fitted.height)
                    sheet.paste(bg, (x, y + 16))
                    sheet.paste(fitted, (x, y + 16), fitted)
                    maxh = max(maxh, fitted.height)
                    d.text((x, y + 2), kind.replace('sheet_', '').replace('.png', ''), fill=(180, 180, 180), font=fnt_small)
                else:
                    d.text((x, y + 16), 'MISSING', fill=(255, 80, 80), font=fnt_small)
                x += img_w // 2 + 5
            y += 10 + 16 + maxh + 10 - 16 + 6
        out = os.path.join(OUT, 'anims', f'sheet_{si + 1:02d}.png')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sheet.save(out)
        made.append(out)
        print(f'[anims] {out} ({W}x{H})')
    return made

def main():
    fnt = font(20)
    fnt_small = font(15)
    ua = sorted(glob.glob(os.path.join(ROOT, 'assets/effects/unit_anims/*/')))
    ua = [d for d in ua if os.path.exists(os.path.join(d, 'sheet_idle.png'))]
    made = {'anims': anim_sheets(ua, fnt, fnt_small)}

    groups = {
        'cards_player': (sorted(glob.glob(os.path.join(ROOT, 'assets/card_icons/player/*.png'))), 300, 4, 6),
        'cards_enemy': (sorted(glob.glob(os.path.join(ROOT, 'assets/card_icons/enemy/*.png'))), 300, 4, 6),
        'backgrounds': (sorted(glob.glob(os.path.join(ROOT, 'assets/backgrounds/*.png'))), (460, 259), 3, 4),
        'masters': (sorted(glob.glob(os.path.join(ROOT, 'assets/enemies/phase_masters/*.png'))), 300, 4, 4),
        'ui_icons': (sorted(glob.glob(os.path.join(ROOT, 'assets/ui/icons/*.png'))), 100, 10, 12),
        'ui_instruments_big': (sorted(glob.glob(os.path.join(ROOT, 'assets/ui/instruments/*.png'))), 240, 4, 5),
        'ui_misc': (sorted(glob.glob(os.path.join(ROOT, 'assets/ui/instruments/_thumb128/*.png')) +
                           glob.glob(os.path.join(ROOT, 'assets/ui/factions/*.png')) +
                           glob.glob(os.path.join(ROOT, 'assets/ui/ranks/*.png')) +
                           glob.glob(os.path.join(ROOT, 'assets/ui/stars/*.png')) +
                           glob.glob(os.path.join(ROOT, 'assets/ui/truck_base/*.png'))), 110, 8, 8),
        'runes': (sorted(glob.glob(os.path.join(ROOT, 'assets/runes/common/*.png')) +
                         glob.glob(os.path.join(ROOT, 'assets/runes/rare/*.png')) +
                         glob.glob(os.path.join(ROOT, 'assets/runes/epic/*.png')) +
                         glob.glob(os.path.join(ROOT, 'assets/runes/legendary/*.png'))), 190, 5, 5),
        'fx_weapons': (sorted(glob.glob(os.path.join(ROOT, 'assets/effects/projectiles/weapons_realistic/*.png'))), 260, 5, 4),
        'fx_other': (sorted(glob.glob(os.path.join(ROOT, 'assets/effects/particle_textures/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/explosion_frames/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/nuclear/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/spell_burst/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/ultimate_projectiles/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/dot/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/aura/*.png')) +
                            glob.glob(os.path.join(ROOT, 'assets/effects/projectiles/omega_platform/*.png'))), 260, 5, 4),
        'misc': (sorted(glob.glob(os.path.join(ROOT, 'assets/map/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/intro/**/*.png'), recursive=False) +
                        glob.glob(os.path.join(ROOT, 'assets/intro/comic/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/cards/backgrounds/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/cards/frames/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/resources/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/icons/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/battle/*.png')) +
                        glob.glob(os.path.join(ROOT, 'assets/phase_field/*.png'))), 280, 4, 4),
    }
    for name, (paths, cell, cols, rows) in groups.items():
        made[name] = grid_sheets(name, paths, cell, cols, rows, fnt, fnt_small)

    with open(os.path.join(OUT, 'index.txt'), 'w', encoding='utf-8') as f:
        for g, lst in made.items():
            f.write(f'{g}: {len(lst)} sheets\n')
            for p in lst:
                f.write(f'  {p}\n')
    print('DONE', sum(len(v) for v in made.values()), 'sheets')

if __name__ == '__main__':
    main()
