# -*- coding: utf-8 -*-
# 参考实现（受跟踪副本，2026-10-10 自 flow_m1a2sep 批收编）：换单位改 HERE 工作目录与输出名；门禁清单见 docs/FLOW_精灵帧生成工作流.md §12。
"""attack_asb.jpg 3x2 切格 → 品红键控 → kcell1-6.png
键判据: r>140 & b>140 & g < 0.75*min(r,b) - 10 (同色系品红+格线一起键)
边缘: 1px 羽化 alpha 140 + 紫边去饱和
"""
from PIL import Image
import numpy as np
import os

HERE = os.path.dirname(os.path.abspath(__file__))
im = Image.open(os.path.join(HERE, 'attack_asb.jpg')).convert('RGB')
W, H = im.size
CW, CH = W / 3.0, H / 2.0
print('asb', W, 'x', H, 'cell', CW, 'x', CH)

for i in range(6):
    col, row = i % 3, i // 3
    x0 = int(round(col * CW)); x1 = int(round((col + 1) * CW))
    y0 = int(round(row * CH)); y1 = int(round((row + 1) * CH))
    cell = np.asarray(im.crop((x0, y0, x1, y1))).astype(int)
    r, g, b = cell[:, :, 0], cell[:, :, 1], cell[:, :, 2]
    mag = (r > 140) & (b > 140) & (g < 0.75 * np.minimum(r, b) - 10)
    alpha = np.where(mag, 0, 255).astype(np.uint8)

    # 紫边去饱和: 未键像素若偏紫(r,b明显高于g) 压向灰
    violet = (~mag) & (r > 120) & (b > 120) & (g < 0.8 * np.minimum(r, b))
    despill = cell.copy()
    new_rb = ((r + b) // 2)
    for ch in (0, 2):
        despill[:, :, ch] = np.where(violet, (new_rb * 0.5 + despill[:, :, ch] * 0.5), despill[:, :, ch])

    # 二次键控: despill 后仍读作品红的像素直接杀 (JPEG 晕半去饱和产物)
    r2, g2, b2 = despill[:, :, 0].astype(int), despill[:, :, 1].astype(int), despill[:, :, 2].astype(int)
    mag2 = (r2 > 140) & (b2 > 140) & (g2 < 0.75 * np.minimum(r2, b2) - 10)
    alpha[mag2] = 0

    # 紫边去色: 键区 2px 邻域内偏紫的保留像素 (描边×品红过渡带) → 同亮度灰
    dil = mag2.copy()
    for _ in range(2):
        dil = dil | np.roll(dil, 1, 0) | np.roll(dil, -1, 0) | np.roll(dil, 1, 1) | np.roll(dil, -1, 1)
    purple = dil & (~mag2) & (r2 > g2 + 18) & (b2 > g2 + 8) & (al_keep := (alpha > 0))
    if purple.any():
        gray = ((r2 + g2 * 2 + b2) // 4).astype(np.uint8)
        for ch in range(3):
            despill[:, :, ch] = np.where(purple, gray, despill[:, :, ch])
    print('  purple_desat=%d' % int(purple.sum()))

    # 1px 羽化: 不透明且邻接透明 → alpha 140
    opaque = alpha == 255
    neigh = np.zeros_like(opaque)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(opaque, dy, 0), dx, 1)
        neigh |= ~sh
    alpha[opaque & neigh] = 140

    out = np.dstack([despill.astype(np.uint8), alpha])
    Image.fromarray(out, 'RGBA').save(os.path.join(HERE, 'kcell%d.png' % (i + 1)))
    print('kcell%d' % (i + 1), 'mag_px=%d mag2=%d violet=%d' % (int(mag.sum()), int(mag2.sum()), int(violet.sum())))
print('done')
