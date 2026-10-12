# -*- coding: utf-8 -*-
"""批2 二轮精修（2026-10-12）：flak 竖线+粉紫溢边、colossus 半透明灰影

flak:
  1) 竖线——全高灰白细线（sat<0.12 & lum>90），列连续段>250px 且列内彩色像素极少 → 清
  2) 粉紫溢边——chroma spill 残留（r-g>12 & b-g>=0 & r>=b-10 & r>90），黄橙火光 b 最小不误杀
colossus:
  3) 软影——半透明低饱和中灰（30<al<230 & sat<0.18 & 70<lum<190）→ 清；
     主体装甲为高亮白/深蓝暗部，落在此窗口的是脚下灰带

用法: python -I tools/_tmp_img25_flak_colossus_fix.py <sheet832 路径>...
"""
import sys

import numpy as np
from PIL import Image


def fix(path: str) -> None:
    im = Image.open(path).convert('RGBA')
    a = np.array(im).astype(np.int32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 0, (mx - mn) * 255 // np.maximum(mx, 1), 0)
    lum = (r * 299 + g * 587 + b * 114) // 1000

    # --- 1) 竖线检测 ---
    vis = al > 40
    grayish = vis & (sat < 30) & (lum > 90)
    n_col = vis.sum(axis=0)
    n_gray = grayish.sum(axis=0)
    line_cols = np.where((n_gray > 250) & (n_gray > n_col * 0.8))[0]
    removed_line = 0
    if len(line_cols):
        # 连通列组膨胀 ±3
        keep = np.zeros(a.shape[1], bool)
        for c in line_cols:
            keep[max(0, c - 3):c + 4] = True
        # 只清「该列主体是竖线」的组：清灰白像素所在 alpha
        m_line = np.zeros_like(al, bool)
        m_line[:, keep] = grayish[:, keep]
        a[..., 3][m_line] = 0
        removed_line = int(m_line.sum())

    # --- 2) 粉紫溢边（仅 flak 类粉 spill；colossus 主体蓝灰 r<g 不命中）---
    m_pink = (r - g > 12) & (b - g >= 0) & (r >= b - 10) & (r > 90) & (al > 0)
    a[..., 3][m_pink] = 0

    # --- 3) 半透明灰影 ---
    m_shadow = (al > 30) & (al < 230) & (sat < 46) & (lum > 70) & (lum < 190)
    a[..., 3][m_shadow] = 0

    out = path.replace('_sheet_832.png', '_sheet_832.png')
    Image.fromarray(a.astype(np.uint8), 'RGBA').save(out)
    print(f'{path}: line_cols={len(line_cols)} line_px={removed_line} '
          f'pink_px={int(m_pink.sum())} shadow_px={int(m_shadow.sum())}')


def main() -> None:
    for p in sys.argv[1:]:
        fix(p)


if __name__ == '__main__':
    main()
