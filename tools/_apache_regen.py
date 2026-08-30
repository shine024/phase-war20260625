# -*- coding: utf-8 -*-
"""apache 双单位 idle+attack 重生成: 快照→视频→自检→重建"""
import glob
import os
import shutil
import subprocess
import sys
import time

JOBS = [('mod_apache', 'idle'), ('mod_apache', 'attack'),
        ('mod_apache_e', 'idle'), ('mod_apache_e', 'attack')]
DIRS = {
    'mod_apache': r'资料/单位分帧动画/mod_apache_阿帕奇直升机',
    'mod_apache_e': r'资料/单位分帧动画/mod_apache_e_阿帕奇精英',
}

for u, a in JOBS:
    d = DIRS[u]
    hist = os.path.join(d, a + '_v1')
    if not os.path.isdir(hist):
        os.makedirs(hist)
        for f in glob.glob(os.path.join(d, a, '*.png')) + glob.glob(os.path.join(d, a, '*.json')):
            shutil.copy2(f, hist)
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py', 'create', u, a],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[create %s/%s] rc=%d %s' % (u, a, r.returncode, tail[-1] if tail else ''))
    if r.returncode != 0:
        print((r.stderr or '')[-300:]); sys.exit(1)
    time.sleep(11)

for u, a in JOBS:
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py', 'poll', u, a],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[poll %s/%s] rc=%d %s' % (u, a, r.returncode, tail[-1] if tail else ''))
    if r.returncode != 0:
        print((r.stderr or '')[-300:]); sys.exit(1)

r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py',
                    'mod_apache_阿帕奇直升机', 'mod_apache_e_阿帕奇精英'],
                   capture_output=True, text=True, encoding='utf-8', errors='replace')
print(r.stdout)
if 'FAIL' in (r.stdout or ''):
    sys.exit(2)
for u, a in JOBS:
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py', 'build', u, a],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[build %s/%s] rc=%d %s' % (u, a, r.returncode, ' | '.join(tail[-2:])))
print('ALL DONE')
