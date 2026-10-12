# -*- coding: utf-8 -*-
"""美术资产程序化预扫描（目检的辅助靶点，不是结论）：
- MAGENTA  品红残渍 (r-g>40)&(b-g>10) 透明键残留
- EDGE     精灵类资产实色像素贴画布边（截断嫌疑）
- BLANK    >99.5% 透明 / 全图纯一色
- DIM      尺寸偏离组内众数（信息项）
- SUBJECT  unit_anims anim.json 缺 subject 块（部署门=资产过期）
输出: .godot/art_audit_20261011/scan_report.json + stdout 摘要
"""
import os, sys, glob, json
import numpy as np
from PIL import Image
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, '.godot', 'art_audit_20261011')

# 边缘检查只针对"应当透明背景"的精灵类；全幅画类（卡图/背景/立绘/漫画）不查
SPRITE_GROUPS = {
    'anims_idle': 'assets/effects/unit_anims/*/sheet_idle.png',
    'anims_attack': 'assets/effects/unit_anims/*/sheet_attack.png',
    'fx_weapons': 'assets/effects/projectiles/weapons_realistic/*.png',
    'fx_other': None,  # 手工展开
    'runes': 'assets/runes/{common,rare,epic,legendary}/*.png',
    'ui_icons': 'assets/ui/icons/*.png',
    'ui_instruments': 'assets/ui/instruments/*.png',
    'ui_misc': 'assets/ui/{factions,ranks,stars,truck_base}/*.png',
    'map_icons': 'assets/map/*.png',
}
FULLBLEED_GROUPS = {
    'cards_player': 'assets/card_icons/player/*.png',
    'cards_enemy': 'assets/card_icons/enemy/*.png',
    'backgrounds': 'assets/backgrounds/*.png',
    'masters': 'assets/enemies/phase_masters/*.png',
    'intro': 'assets/intro/**/*.png',
    'cards_frames': 'assets/cards/**/*.png',
    'resources': 'assets/resources/*.png',
    'battle': 'assets/battle/*.png',
    'phase_field': 'assets/phase_field/*.png',
    'ui_instruments_thumbs': 'assets/ui/instruments/_thumb128/*.png',
}

def expand(patterns):
    out = []
    for p in patterns:
        out += [q for q in glob.glob(os.path.join(ROOT, p), recursive=True) if '_backup' not in q and 'bak_' not in q]
    return sorted(set(out))

def scan_one(path, edge_check):
    im = Image.open(path)
    im.load()
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    a = np.asarray(im, dtype=np.int16)
    R, G, B, A = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    op = A >= 128
    n_op = int(op.sum())
    flags = {}
    if n_op:
        mag = ((R - G > 40) & (B - G > 10) & op)
        frac = float(mag.sum()) / n_op
        if frac > 0.0005:
            flags['MAGENTA'] = round(frac, 5)
    else:
        flags['BLANK_TRANSPARENT'] = 1.0
    # 全图单色
    if n_op and op.all():
        px = a[..., :3].reshape(-1, 3)
        if len(np.unique(px, axis=0)) <= 1:
            flags['UNIFORM_SOLID'] = 1
    if edge_check and n_op:
        solid_border = 0
        solid_border += int((A[0, :] >= 128).sum()) + int((A[-1, :] >= 128).sum())
        solid_border += int((A[:, 0] >= 128).sum()) + int((A[:, -1] >= 128).sum())
        if solid_border > 8:
            flags['EDGE'] = solid_border
    return im.size, flags

def main():
    report = defaultdict(dict)
    dim_counter = defaultdict(Counter)
    # 精灵类
    fxo = ['assets/effects/particle_textures/*.png', 'assets/effects/explosion_frames/*.png',
           'assets/effects/nuclear/*.png', 'assets/effects/spell_burst/*.png',
           'assets/effects/ultimate_projectiles/*.png', 'assets/effects/dot/*.png',
           'assets/effects/aura/*.png', 'assets/effects/projectiles/omega_platform/*.png']
    jobs = []
    for g, pat in SPRITE_GROUPS.items():
        if g == 'fx_other':
            jobs.append((g, expand(fxo), True))
        else:
            jobs.append((g, expand([pat]), True))
    for g, pat in FULLBLEED_GROUPS.items():
        jobs.append((g, expand([pat]), False))

    for g, paths, edge in jobs:
        for i, p in enumerate(paths):
            rel = os.path.relpath(p, ROOT)
            try:
                size, flags = scan_one(p, edge)
            except Exception as e:
                report[g][rel] = {'CORRUPT': str(e)[:80]}
                continue
            dim_counter[g][size] += 1
            if flags:
                report[g][rel] = flags
            if (i + 1) % 300 == 0:
                print(f'  ...{g} {i + 1}/{len(paths)}', flush=True)

    # unit_anims subject 块部署门
    missing_subject = []
    for d in sorted(glob.glob(os.path.join(ROOT, 'assets/effects/unit_anims/*/'))):
        j = os.path.join(d, 'anim.json')
        name = os.path.basename(d.rstrip('/\\'))
        if not os.path.exists(j):
            missing_subject.append(name)
            continue
        try:
            with open(j, encoding='utf-8') as f:
                data = json.load(f)
            if not isinstance(data, dict) or 'subject' not in data:
                missing_subject.append(name)
        except Exception:
            missing_subject.append(name)
    report['SUBJECT_missing_animjson_or_block'] = {k: 1 for k in missing_subject}

    with open(os.path.join(OUT, 'scan_report.json'), 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=1)

    print('\n===== SUMMARY =====')
    total_flagged = 0
    for g in sorted(report):
        n = len(report[g])
        total_flagged += n
        print(f'{g}: {n} flagged')
        for rel, flags in list(report[g].items())[:400]:
            print(f'   {rel}  {flags}')
    print(f'TOTAL flagged: {total_flagged}')
    print('===== DIM modal sizes =====')
    for g, c in dim_counter.items():
        print(g, c.most_common(4))

if __name__ == '__main__':
    main()
