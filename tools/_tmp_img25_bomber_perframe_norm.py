# -*- coding: utf-8 -*-
"""bomber attack sheet 逐帧归一（2026-10-12 批3）：下排缩小病程序矫正。

基准：每格右侧 60% 区域（机尾段，避开机头左侧爆闪）的 solid(α≥250) bbox 高。
每帧独立缩放 scale=h0/h_i，绕「bbox 底缘中点」对齐 f0 底缘中点，整帧 LANCZOS 后贴回 832²。

用法: python -I tools/_tmp_img25_bomber_perframe_norm.py <sheet_832> <输出 sheet_832>
"""
import sys

import numpy as np
from PIL import Image

FS = 832


def solid_h(cell: np.ndarray) -> tuple:
    """右侧 60% 区域 solid bbox 高 + 全帧 alpha bbox 底缘/水平中心。"""
    w = cell.shape[1]
    zone = cell[:, int(w * 0.40):]
    solid = zone[..., 3] >= 250
    rows = np.where(solid.any(axis=1))[0]
    h = (rows.max() - rows.min() + 1) if rows.size else 0
    allm = cell[..., 3] > 30
    rr = np.where(allm.any(axis=1))[0]
    cc = np.where(allm.any(axis=0))[0]
    bot = rr.max() if rr.size else cell.shape[0]
    cx = (cc.min() + cc.max()) / 2 if cc.size else w / 2
    return int(h), int(bot), float(cx)


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    im = Image.open(src).convert('RGBA')
    cells = [np.array(im.crop((c * FS, r * FS, (c + 1) * FS, (r + 1) * FS)))
             for r in range(2) for c in range(3)]
    infos = [solid_h(c) for c in cells]
    h0, bot0, cx0 = infos[0]
    print('f0 h=%d bot=%d cx=%.0f' % infos[0])
    out = Image.new('RGBA', (FS * 3, FS * 2), (0, 0, 0, 0))
    for i, (cell, (h, bot, cx)) in enumerate(zip(cells, infos)):
        img = Image.fromarray(cell, 'RGBA')
        scale = min(1.8, h0 / max(h, 1))
        if abs(scale - 1.0) > 0.04:
            nw, nh = int(FS * scale), int(FS * scale)
            img = img.resize((nw, nh), Image.LANCZOS)
            # 锚点平移：全α bbox 底缘中点对齐到 f0 基准位置
            base = Image.new('RGBA', (FS, FS), (0, 0, 0, 0))
            px = int(cx0 - cx * scale)
            py = int(bot0 - bot * scale)
            base.alpha_composite(img, (px, py))
            img = base
            print(f'f{i}: h={h} scale={scale:.3f} shift=({px},{py})')
        else:
            print(f'f{i}: h={h} scale={scale:.3f} (kept)')
        r, c = divmod(i, 3)
        out.paste(img, (c * FS, r * FS))
    out.save(dst)
    print('saved', dst)


if __name__ == '__main__':
    main()
