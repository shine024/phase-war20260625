# -*- coding: utf-8 -*-
"""抠图方向诊断: matte 修复名单的 keep%/残渣率/卡图对照"""
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
LIST = [
    ('mod_mlrs', 'attack'), ('mod_abrams', 'attack'),
    ('ww2_arty_m81', 'idle'), ('ww2_arty_m81', 'attack'),
    ('mod_technical', 'idle'), ('mod_technical', 'attack'),
    ('mod_inf_technical', 'idle'), ('mod_inf_technical', 'attack'),
    ('mod_sup_m6', 'attack'), ('mod_inf_scout_drone', 'attack'),
    ('fut_air_regen_frame', 'idle'), ('fut_air_regen_frame', 'attack'),
    ('cold_fort_radar', 'idle'), ('ww2_arty_pak40', 'idle'),
    ('ww2_arty_pak40', 'attack'),
    ('fut_arty_ssc1', 'idle'), ('fut_arty_ssc1', 'attack'),
]


def dname(u):
    for d in os.listdir(BASE):
        if d == u or d.startswith(u + '_'):
            return d
    return None


def card_key(u):
    return UNITS.get(u, {}).get('art') or UNITS.get(u, {}).get('card') or ''


def opaque_stats(paths, step=4):
    tot = res = 0
    n = 0
    for f in paths:
        im = Image.open(f).convert('RGBA')
        px = im.load()
        w, h = im.size
        for y in range(0, h, step):
            for x in range(0, w, step):
                r, g, b, a = px[x, y]
                if a <= 16:
                    continue
                tot += 1
                mn, mx = min(r, g, b), max(r, g, b)
                if mn >= 235 and (mx - mn) <= 20:
                    res += 1
        n += 1
        per = ((w + step - 1) // step) * ((h + step - 1) // step)
    if not n:
        return 0.0, 0.0
    return 100.0 * tot / (per * n), 100.0 * res / max(tot, 1)


print('%-16s %-7s %7s %7s %7s  %s' % ('unit', 'anim', 'keep%', 'resid%', 'card%', 'dir'))
for u, a in LIST:
    d = dname(u)
    adir = os.path.join(BASE, d, a) if d else ''
    import glob
    frames = sorted(glob.glob(os.path.join(adir, 'f*.png'))) if adir else []
    keep, resid = opaque_stats(frames)
    # 卡图对照
    ck = card_key(u)
    card_p = None
    for cand in [ck, 'assets/cards/enemy/%s.png' % u]:
        if cand and os.path.exists(cand):
            card_p = [cand]
            break
    if card_p is None:
        hits = glob.glob('assets/cards/**/%s*.png' % u.split('_')[-1], recursive=True)
        card_p = hits[:1]
    ckeep, _ = opaque_stats(card_p) if card_p else (0.0, 0.0)
    tag = ''
    if resid > 4.0:
        tag = '抠少(残渣)'
    elif ckeep > 0 and keep < ckeep * 0.62:
        tag = '抠多(吃主体)'
    elif keep < 4.0:
        tag = '过小?'
    print('%-16s %-7s %7.1f %7.1f %7.1f  %s' % (u, a, keep, resid, ckeep, tag))
