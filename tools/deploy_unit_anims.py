# -*- coding: utf-8 -*-
"""部署单位分帧动画(v2 雪碧图版): 源 f*.png(512²) → 缩小256² 拼单张横条 sheet
产物: assets/effects/unit_anims/<key>/sheet_{idle,attack}.png + anim.json(帧数/fps)
兼容: 老的 idle_f*.png/attack_f*.png 逐帧副本会被清理
"""
import glob
import json
import os
import re
import sys

from PIL import Image

SRC = r'资料/单位分帧动画'
DST = r'assets/effects/unit_anims'
FRAME = 256
FPS = 8

keys = []
import importlib.util
spec = importlib.util.spec_from_file_location('gua', 'tools/generate_unit_animations.py')
gua = importlib.util.module_from_spec(spec)
sys.modules['gua'] = gua
spec.loader.exec_module(gua)
keys.extend(gua.UNITS.keys())
extra = json.load(open('tools/unit_animations_extra.json', encoding='utf-8'))
keys.extend(k for k in extra.keys() if k not in keys)
keys.sort(key=len, reverse=True)
print('known keys:', len(keys))

os.makedirs(DST, exist_ok=True)
n_units = n_sheets = n_png = 0
for d in sorted(os.listdir(SRC)):
    dp = os.path.join(SRC, d)
    if not os.path.isdir(dp) or d.startswith('_'):
        continue
    if d.startswith('enemy_master') or d.startswith('boss_'):
        continue
    key = next((k for k in keys if d == k or d.startswith(k + '_')), None)
    if key is None:
        # fix5: 目录带 NNN_ 序号前缀, 剥离后再匹配
        stripped = re.sub(r'^\d{3}_', '', d)
        key = next((k for k in keys if stripped == k or stripped.startswith(k + '_')), None)
    if key is None:
        print('!! no key match for', d)
        continue
    out_dir = os.path.join(DST, key)
    os.makedirs(out_dir, exist_ok=True)
    counts = {}
    for anim in ('idle', 'attack'):
        frames = sorted(glob.glob(os.path.join(dp, anim, 'f*.png')))
        if len(frames) < 4:
            print('!! skip %s/%s only %d frames' % (d, anim, len(frames)))
            continue
        sheet = Image.new('RGBA', (FRAME * len(frames), FRAME), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            im = Image.open(f).convert('RGBA')
            if im.size != (FRAME, FRAME):
                im = im.resize((FRAME, FRAME), Image.LANCZOS)
            sheet.paste(im, (i * FRAME, 0))
        sheet.save(os.path.join(out_dir, 'sheet_%s.png' % anim))
        counts[anim] = len(frames)
        n_sheets += 1
    # 清理 v1 逐帧副本
    for old in glob.glob(os.path.join(out_dir, 'idle_f*.png')) + glob.glob(os.path.join(out_dir, 'attack_f*.png')):
        os.remove(old)
        n_png += 1
    json.dump({'fps': FPS, 'frame_size': FRAME, 'counts': counts},
              open(os.path.join(out_dir, 'anim.json'), 'w', encoding='utf-8'))
    n_units += 1
print('deployed units: %d  sheets: %d  removed v1 pngs: %d' % (n_units, n_sheets, n_png))
