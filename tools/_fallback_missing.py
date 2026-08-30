# -*- coding: utf-8 -*-
"""三遍兜底: 二遍后仍缺动画的单位 -> anim_fallback_from_card(卡图呼吸+火光)
fallback 会写 idle+attack 两套, 先把已合格的兄弟动画快照保护"""
import glob
import io
import json
import os
import shutil
import subprocess
import sys

CFG = json.load(io.open('tools/unit_animations_extra.json', encoding='utf-8'))
BASE = r'资料/单位分帧动画'


def run(*a):
    return subprocess.run([sys.executable] + list(a), capture_output=True,
                          text=True, encoding='utf-8', errors='replace')


for key, v in CFG.items():
    d = os.path.join(BASE, '%s_%s' % (key, v['name']))
    lack = []
    for anim in ('idle', 'attack'):
        ad = os.path.join(d, anim)
        fs = glob.glob(os.path.join(ad, 'f*.png')) if os.path.isdir(ad) else []
        if len(fs) < 6:
            lack.append(anim)
    if not lack:
        continue
    print('== fallback', key, v['name'], '缺', lack)
    # 保护合格兄弟
    good = [a for a in ('idle', 'attack') if a not in lack]
    for a in good:
        src = os.path.join(d, a)
        snap = os.path.join(d, a + '_keep')
        if os.path.isdir(src) and not os.path.isdir(snap):
            shutil.copytree(src, snap)
    foot = '0.80' if v.get('air') else '0.92'
    r = run('tools/anim_fallback_from_card.py', key, v['art'], foot)
    print('  rc=%d' % r.returncode, (r.stdout or '')[-200:], (r.stderr or '')[-200:])
    # 恢复合格兄弟
    for a in good:
        src = os.path.join(d, a)
        snap = os.path.join(d, a + '_keep')
        if os.path.isdir(snap):
            if os.path.isdir(src):
                shutil.rmtree(src)
            shutil.move(snap, src)
    # 验证
    for a in lack:
        fs = glob.glob(os.path.join(d, a, 'f*.png'))
        print('  %s -> %d 帧' % (a, len(fs)))
print('fallback pass done')
