# -*- coding: utf-8 -*-
import glob
import os
import shutil
import subprocess
import sys

d = r'资料/单位分帧动画/fut_mech_机甲精英'
# 现有 idle 帧(含上一版重生成) 存为 idle_v2
hist = os.path.join(d, 'idle_v2')
if not os.path.isdir(hist):
    os.makedirs(hist)
    for f in glob.glob(os.path.join(d, 'idle', '*.png')) + glob.glob(os.path.join(d, 'idle', '*.json')):
        shutil.copy2(f, hist)

for cmd in (['create', 'fut_mech', 'idle'], ['poll', 'fut_mech', 'idle'], ['build', 'fut_mech', 'idle']):
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py'] + cmd,
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[%s] rc=%d %s' % (cmd[0], r.returncode, ' | '.join(tail[-2:])))
    if r.returncode != 0:
        print((r.stderr or '')[-300:])
        sys.exit(1)

r = subprocess.run([sys.executable, 'tools/anim_video_selfcheck.py', 'fut_mech_机甲精英'],
                   capture_output=True, text=True, encoding='utf-8', errors='replace')
print(r.stdout)
