# -*- coding: utf-8 -*-
"""fix4 白边卸除 v2: 备份用 copy2(快), 每动画目录标记断点;
先从 bak_fix4_defringe/ 还原已处理帧(保证恰好处理一次), 再全量 defringe + 审计
"""
import glob
import os
import shutil
import sys
import time

import numpy as np
from PIL import Image

BASE = r'资料/单位分帧动画'
MARK = '.fix4_defringe_done'


def defringe_arr(arr):
    a = arr[..., 3]
    band = (a >= 16) & (a < 250)
    ai = a / 255.0
    for c in range(3):
        ch = arr[..., c]
        ch[band] = np.clip((ch[band] - (1.0 - ai[band]) * 255.0) / np.maximum(ai[band], 0.08), 0, 255)
    a[a < 16] = 0.0
    return arr


t0 = time.time()
n_r = n_d = 0
dirs = []
for d in sorted(os.listdir(BASE)):
    dp = os.path.join(BASE, d)
    if not os.path.isdir(dp) or d.startswith('_'):
        continue
    for anim in ('idle', 'attack'):
        adir = os.path.join(dp, anim)
        if os.path.isdir(adir):
            dirs.append(adir)

# ① 还原所有已备份帧 -> 原始状态(撤销上次被杀的半成品)
for adir in dirs:
    bak = os.path.join(adir, 'bak_fix4_defringe')
    for dst in glob.glob(os.path.join(bak, '*.png')):
        src = os.path.join(adir, os.path.basename(dst))
        if os.path.exists(src):
            shutil.copy2(dst, src)
            n_r += 1
print('restored %d frames (%.0fs)' % (n_r, time.time() - t0), flush=True)

# ② 全量 defringe(标记断点)
for adir in dirs:
    if os.path.exists(os.path.join(adir, MARK)):
        continue
    bak = os.path.join(adir, 'bak_fix4_defringe')
    os.makedirs(bak, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(adir, 'f*.png'))):
        dst = os.path.join(bak, os.path.basename(f))
        if not os.path.exists(dst):
            shutil.copy2(f, dst)
        arr = np.asarray(Image.open(f).convert('RGBA')).astype(np.float32)
        Image.fromarray(defringe_arr(arr).astype(np.uint8)).save(f)
        n_d += 1
    open(os.path.join(adir, MARK), 'w').write('ok')
print('defringed %d frames (%.0fs total)' % (n_d, time.time() - t0), flush=True)

# ③ 审计
import cv2
rows = []
for adir in dirs:
    frames = sorted(glob.glob(os.path.join(adir, 'f*.png')))
    if not frames:
        continue
    rs = hs = 0
    for f in frames:
        arr = np.asarray(Image.open(f).convert('RGBA'))
        a = arr[..., 3] >= 128
        rgbv = arr[..., :3].astype(np.int16)
        mn = rgbv.min(axis=2)
        sat = rgbv.max(axis=2) - rgbv.min(axis=2)
        resid = a & (mn >= 238) & (sat <= 15)
        trans = (~a).astype(np.uint8)
        nf, labf = cv2.connectedComponents(trans)
        border = set()
        for edge in (labf[0, :], labf[-1, :], labf[:, 0], labf[:, -1]):
            border |= set(np.unique(edge).tolist())
        border.discard(0)
        holes = np.isin(labf, [i for i in range(1, nf) if i not in border]) if nf > 1 else np.zeros_like(a)
        rs += resid.mean()
        hs += holes.mean()
    rel = os.path.relpath(adir, BASE).replace('\\', '/')
    rows.append((rel, 100 * rs / len(frames), 100 * hs / len(frames)))

print('\n== resid TOP15 (不透明近纯白=白的没抠掉) ==', flush=True)
for r in sorted(rows, key=lambda x: -x[1])[:15]:
    print('%7.2f%% resid %6.2f%% holes  %s' % (r[1], r[2], r[0]), flush=True)
print('\n== holes TOP15 (被包围透明=抠多嫌疑) ==', flush=True)
for r in sorted(rows, key=lambda x: -x[2])[:15]:
    print('%7.2f%% holes %6.2f%% resid  %s' % (r[2], r[1], r[0]), flush=True)
print('AUDIT DONE')
