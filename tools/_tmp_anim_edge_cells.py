# -*- coding: utf-8 -*-
"""anims 逐帧格贴边细化：256px 帧格内，实色(alpha>=128)触顶/触左/触右 = 截断嫌疑（触底=脚线，正常）。
输出 anims_edge_cells.txt 按目录汇总。"""
import glob, os, json
import numpy as np
from PIL import Image

ROOT = '.'
out_lines = []
rows = []
for kind in ('sheet_idle.png', 'sheet_attack.png'):
    for p in sorted(glob.glob(f'assets/effects/unit_anims/*/{kind}')):
        d = os.path.basename(os.path.dirname(p.replace('\\', '/')))
        im = Image.open(p)
        if im.mode != 'RGBA':
            im = im.convert('RGBA')
        A = np.asarray(im)[:, :, 3]
        fw = 256
        nf = im.width // fw
        bad = []
        for fi in range(nf):
            cell = A[:, fi * fw:(fi + 1) * fw]
            top = int((cell[0, :] >= 128).sum())
            left = int((cell[:, 0] >= 128).sum())
            right = int((cell[:, -1] >= 128).sum())
            hits = []
            if top >= 3: hits.append(f'T{top}')
            if left >= 3: hits.append(f'L{left}')
            if right >= 3: hits.append(f'R{right}')
            if hits:
                bad.append(f'f{fi}:{",".join(hits)}')
        if bad:
            rows.append((d, kind.replace('sheet_', '').replace('.png', ''), len(bad), nf, ' '.join(bad[:14])))

rows.sort(key=lambda x: -x[2])
with open('.godot/art_audit_20261011/anims_edge_cells.txt', 'w', encoding='utf-8') as f:
    for d, k, n, nf, det in rows:
        f.write(f'{d:34s} {k:6s} {n:2d}/{nf}格触边  {det}\n')
print('dirs with cell-edge touch:', len(rows))
for d, k, n, nf, det in rows[:40]:
    print(f'{d:34s} {k:6s} {n:2d}/{nf}  {det[:100]}')
