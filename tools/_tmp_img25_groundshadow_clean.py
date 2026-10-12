# -*- coding: utf-8 -*-
"""img25 阶段2' 直出 sheet 品红地面影后处理（2026-10-12 美术目检批2）

背景：§十 锚定帧管线试点（fut_nano_drone/cold_f4）均为悬浮单位，prompt【无地面】
直接生效；本批 7 目录全是地面车辆/建筑/步兵，模型在锚定帧与六格图中自绘半透
品红地面阴影——depink 公式 (lum>120) 管不到暗品红，逃过规范化全链。

处理：品红相像素（r-g、b-g 超阈，任意亮度/alpha）→ alpha 清零。
只清「品红相」，橙火（b 低）与主题紫（g 不低）不误杀。

用法: python -I tools/_tmp_img25_groundshadow_clean.py <sheet832 路径>...
"""
import sys

import numpy as np
from PIL import Image


def clean_sheet(path: str) -> int:
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    rgb = a[..., :3].astype(np.int32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = ((r - g > 25) & (b - g > 15)) | ((r - g > 60) & (b - g > 40))
    a[..., 3][magenta] = 0
    Image.fromarray(a, 'RGBA').save(path)
    return int(magenta.sum())


def main() -> None:
    for p in sys.argv[1:]:
        n = clean_sheet(p)
        print(f'{p}: cleaned {n}px')


if __name__ == '__main__':
    main()
