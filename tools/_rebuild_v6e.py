# -*- coding: utf-8 -*-
"""v6e 全量重建: 先快照 _v1 历史, 再重建(排除 mgnest 保底 + 5 个重生成中单位)"""
import glob
import os
import shutil
import subprocess
import sys

ANIM = r'资料/单位分帧动画'
SKIP_UNITS_KEY = {'ww1_mgnest'}

units = sorted(d for d in os.listdir(ANIM)
               if os.path.isdir(os.path.join(ANIM, d)) and not d.startswith('_'))
todo = []
for u in units:
    key = '_'.join(u.split('_')[:2]) if not u.startswith(('mod_apache_', 'mod_')) else u.rsplit('_', 1)[0]
    # 目录名 = <unit_key>_<中文名>; unit_key 本身含下划线, 用前缀匹配跳过表
    if any(u.startswith(k + '_') for k in SKIP_UNITS_KEY):
        continue
    for a in ('idle', 'attack'):
        ad = os.path.join(ANIM, u, a)
        if os.path.exists(os.path.join(ad, 'raw')) and glob.glob(os.path.join(ad, 'raw', 'r*.png')):
            todo.append((u, a))

print('rebuild %d sets' % len(todo))
for u, a in todo:
    ad = os.path.join(ANIM, u, a)
    hist = os.path.join(ANIM, u, a + '_v1')
    if not os.path.isdir(hist):
        os.makedirs(hist)
        for f in glob.glob(os.path.join(ad, '*.png')) + glob.glob(os.path.join(ad, '*.json')):
            shutil.copy2(f, hist)
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py', 'build',
                        u.rsplit('_', 1)[0], a],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[%s/%s] rc=%d | %s' % (u, a, r.returncode, ' | '.join(tail[-2:]) if tail else ''))
    if r.returncode != 0:
        print((r.stderr or '')[-300:])
print('DONE')
