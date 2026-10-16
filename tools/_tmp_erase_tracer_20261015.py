# -*- coding: utf-8 -*-
"""band 定点擦拖尾:把指定矩形内前景像素替换为背景采样色。

用法: python _tmp_erase_tracer.py <png> <y1> <y2> <x1> <x2> [png2 y1 y2 x1 x2 ...]
band 内色距>TH 的像素视为拖尾,擦成四角背景均值。主体不进 band 即零误擦。
"""
import sys, os
import numpy as np
from PIL import Image

TH = 60

def erase_band(path, y1, y2, x1, x2):
    img = Image.open(path).convert('RGB')
    arr = np.asarray(img).astype(np.int16)
    corners = np.concatenate([
        arr[:24, :24].reshape(-1, 3), arr[:24, -24:].reshape(-1, 3),
        arr[-24:, :24].reshape(-1, 3), arr[-24:, -24:].reshape(-1, 3)])
    bg = corners.mean(axis=0)
    band = arr[y1:y2, x1:x2]
    m = np.abs(band - bg).sum(axis=2) > TH
    band[m] = bg.astype(np.int16)
    Image.fromarray(arr.astype(np.uint8)).save(path)
    return int(m.sum())

if __name__ == '__main__':
    a = sys.argv[1:]
    for i in range(0, len(a), 5):
        p, y1, y2, x1, x2 = a[i], *map(int, a[i+1:i+5])
        n = erase_band(p, y1, y2, x1, x2)
        print(os.path.basename(p), 'band', (y1, y2, x1, x2), '-> erased px', n)
