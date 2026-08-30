# -*- coding: utf-8 -*-
"""半调打印: 卡图 vs f00/中间帧/末帧 —— 肉眼定位吃主体/残渣
用法: python tools/_view_frames.py <unit> <anim>
"""
import glob
import importlib.util
import json
import os
import sys

from PIL import Image

spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
UNITS = dict(gua.UNITS)
extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
UNITS.update(extra)

BASE = r'资料/单位分帧动画'
CH = ' .:-=+*#%@'
W, H = 46, 22


def find_card(u):
    for pat in ['assets/cards/enemy/%s.png' % u, 'assets/cards/**/%s.png' % u]:
        hits = glob.glob(pat, recursive=True)
        if hits:
            return hits[0]
    nm = UNITS.get(u, {}).get('name', '')
    if nm:
        for pat in ['assets/cards/**/*%s*.png' % nm[:4]]:
            hits = glob.glob(pat, recursive=True)
            if hits:
                return hits[0]
    return None


def render(path):
    im = Image.open(path).convert('RGBA')
    im = im.resize((W, H))
    px = im.load()
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            r, g, b, a = px[x, y]
            row.append('#' if a >= 200 else ('+' if a >= 80 else ' '))
        rows.append(''.join(row))
    return rows


def main():
    u, a = sys.argv[1], sys.argv[2]
    import re
    d = next((x for x in os.listdir(BASE)
              if re.sub(r'^\d{3}_', '', x) == u or re.sub(r'^\d{3}_', '', x).startswith(u + '_')), None)
    frames = sorted(glob.glob(os.path.join(BASE, d, a, 'f*.png')))
    card = find_card(u)
    picks_idx = [0, len(frames) // 2, len(frames) - 1]
    picks = ([card] if card else []) + [frames[i] for i in picks_idx]
    grids = [render(p) for p in picks]
    heads = (['CARD'] if card else []) + ['F%02d' % i for i in picks_idx]
    print('== %s / %s  (%s)' % (u, a, d))
    print(''.join(s.ljust(W) for s in heads))
    for y in range(H):
        print(''.join(g[y] for g in grids))


if __name__ == '__main__':
    main()
