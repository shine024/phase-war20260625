# -*- coding: utf-8 -*-
"""堡垒光环贴图化（记录7#15 用户裁决：贴图化）。

生成柔光呼吸环贴图 assets/effects/aura/fort_aura_ring.png（512×512，中性冷白，
运行期按阵营 modulate 染色）：
  - 主环：半径 ~168px、宽 ~30px 高斯柔边
  - 外层泛光：主环大半径低 alpha 高斯扩散
  - 内侧细环：层次
设计语言与护盾穹顶（矢量弧+贴图）同族：能量感、不上色（染色交给 modulate）。
可重跑：python tools/_tmp_record7_gen_aura_ring.py（幂等覆盖，重跑需重导入）
"""
import math
import os

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'effects', 'aura', 'fort_aura_ring.png')
S = 512
CX = CY = S / 2.0


def ring_layer(img, radius, width, alpha, blur):
    layer = Image.new('L', (S, S), 0)
    px = layer.load()
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - CX, y - CY)
            if abs(d - radius) <= width:
                k = 1.0 - abs(d - radius) / width
                px[x, y] = int(255 * alpha * (k * k))
    return layer.filter(ImageFilter.GaussianBlur(blur))


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    alpha = Image.new('L', (S, S), 0)
    for src in (
        ring_layer(alpha, 168, 22, 0.95, 3.0),    # 主环
        ring_layer(alpha, 176, 60, 0.30, 18.0),   # 外层泛光
        ring_layer(alpha, 148, 6, 0.55, 1.5),     # 内侧细环
    ):
        alpha = ImageChops.lighter(alpha, src)
    # 稀疏能量刻度：主环外 8 段短弧刻度（科技感，低 alpha）
    tick = Image.new('L', (S, S), 0)
    tpx = tick.load()
    for i in range(8):
        ang = i * math.tau / 8.0
        for t in range(26):
            rr = 196 + t * 0.8
            for w in range(-2, 3):
                x = int(CX + math.cos(ang) * rr + w * math.cos(ang + math.pi / 2))
                y = int(CY + math.sin(ang) * rr + w * math.sin(ang + math.pi / 2))
                if 0 <= x < S and 0 <= y < S:
                    tpx[x, y] = max(tpx[x, y], int(255 * 0.35))
    tick = tick.filter(ImageFilter.GaussianBlur(1.2))
    alpha = ImageChops.lighter(alpha, tick)
    im = Image.merge('RGBA', (
        Image.new('L', (S, S), 205),   # 冷白偏蓝，运行期 modulate 染阵营色
        Image.new('L', (S, S), 225),
        Image.new('L', (S, S), 255),
        alpha,
    ))
    im.save(OUT)
    print('WROTE', OUT)


if __name__ == '__main__':
    main()
