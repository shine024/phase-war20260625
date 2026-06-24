#!/usr/bin/env python3
"""批量抠图、缩放到512x512并替换 card_icons 中的同名图片"""
import os
from PIL import Image

SRC_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\可用"
DST_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"
TARGET_SIZE = (512, 512)

def auto_matte(img_rgb, tolerance=25):
    arr = img_rgb.convert('RGB').load()
    w, h = img_rgb.size
    corners = [arr[0, 0], arr[w-1, 0], arr[0, h-1], arr[w-1, h-1]]
    bg_color = tuple(int(sum(c[i] for c in corners)/len(corners)) for i in range(3))
    alpha = Image.new('L', (w, h), 255)
    al = alpha.load()
    for y in range(h):
        for x in range(w):
            r, g, b = arr[x, y]
            dr, dg, db = abs(r-bg_color[0]), abs(g-bg_color[1]), abs(b-bg_color[2])
            m = max(dr, dg, db)
            if m <= tolerance:
                al[x, y] = 0
            elif m <= tolerance * 2:
                al[x, y] = 128
            else:
                al[x, y] = 255
    return alpha

def process():
    files = sorted([f for f in os.listdir(SRC_DIR)
                    if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))])
    replaced = 0
    skipped = 0
    errors = 0
    for fname in files:
        src_path = os.path.join(SRC_DIR, fname)
        dst_path = os.path.join(DST_DIR, fname)
        if not os.path.exists(dst_path):
            skipped += 1
            continue
        try:
            img = Image.open(src_path).convert('RGB')
            alpha = auto_matte(img, tolerance=25)
            rgba = img.convert('RGBA')
            rgba.putalpha(alpha)
            rgba = rgba.resize(TARGET_SIZE, Image.LANCZOS)
            rgba.save(dst_path, 'PNG')
            replaced += 1
        except Exception as e:
            print(f"错误 {fname}: {e}")
            errors += 1
    print(f"\n完成: 替换={replaced}, 跳过={skipped}, 错误={errors}")

if __name__ == '__main__':
    process()
