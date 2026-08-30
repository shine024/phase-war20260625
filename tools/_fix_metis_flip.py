# -*- coding: utf-8 -*-
"""metis 朝向修复 v2: 翻转 source.mp4 源头 -> 标准 build 重抽帧+雪碧图 -> 自检
原 mp4 备份为 source_preflip.mp4; 已翻转的旧 f*.png 保留在 raw/preflip_20260830/
"""
import os
import subprocess
import sys

FFMPEG = r'D:\360安全浏览器下载\铁血联盟3\Godot\ffmpeg-8.0-essentials_build\ffmpeg-8.0-essentials_build\bin\ffmpeg.exe'
BASE = r'资料/单位分帧动画/cold_inf_metis_9K111 法特导弹组'

for anim in ('idle', 'attack'):
    mp4 = os.path.join(BASE, anim, 'source.mp4')
    bak = os.path.join(BASE, anim, 'source_preflip.mp4')
    if not os.path.exists(bak):
        os.replace(mp4, bak)
        subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-i', bak,
                        '-vf', 'hflip', mp4], check=True)
        print(anim, 'mp4 flipped')
    elif not os.path.exists(mp4):
        subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-i', bak,
                        '-vf', 'hflip', mp4], check=True)
        print(anim, 'mp4 restored+flipped from bak')
    else:
        print(anim, 'already flipped')

for anim in ('idle', 'attack'):
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py',
                        'build', 'cold_inf_metis', anim],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    print('=== build', anim, 'exit', r.returncode)
    print((r.stdout or '')[-600:])
    if r.returncode:
        print((r.stderr or '')[-600:])
        raise SystemExit(1)

r2 = subprocess.run([sys.executable, 'tools/generate_unit_animations.py',
                     'selfcheck', BASE],
                    capture_output=True, text=True, encoding='utf-8', errors='replace')
print('=== selfcheck exit', r2.returncode)
print((r2.stdout or '')[-1200:])
