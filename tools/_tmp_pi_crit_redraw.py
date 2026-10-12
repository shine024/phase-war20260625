# -*- coding: utf-8 -*-
"""pi_crit 暴击图标语义重绘（2026-10-12 批3）：医疗十字冲突 → 爆裂四芒星。

族风格对齐（pi_atk 金双剑 / pi_attack_speed 青双箭 / pi_hp 绿翼十字）：
深蓝圆底 + 细亮外环 + 中央霓虹金属质感母题。暴击母题=橙金爆裂四芒星
（区分治疗绿/攻击金双剑/攻速青）。4x 超采样绘制缩 128。

产出覆盖: assets/ui/instruments/pi_crit.png + _thumb128/pi_crit.png
（原坏档已在外部目检报告批1 备份链；本脚本先备份到 _art_backup）
"""
import os
import shutil

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
ASSET = os.path.join(ROOT, 'assets', 'ui', 'instruments', 'pi_crit.png')
THUMB = os.path.join(ROOT, 'assets', 'ui', 'instruments', '_thumb128', 'pi_crit.png')
BACKUP = r'F:\godot fair duet\_art_backup\pi_crit_pre_redraw_20261012.png'

S = 512  # 4x 超采样画布

# 深蓝圆底（对齐 pi_atk 底色调）
BG_OUT = (13, 21, 38)
BG_IN = (26, 38, 66)
RING = (96, 114, 142)
GOLD_HOT = (255, 236, 170)
GOLD_MID = (255, 176, 64)
GOLD_DEEP = (232, 108, 18)


def lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def main() -> None:
    for p in (ASSET, THUMB):
        if os.path.isfile(p):
            bdir = os.path.dirname(BACKUP)
            os.makedirs(bdir, exist_ok=True)
            dst = os.path.join(bdir, os.path.basename(p)) if p == ASSET else \
                os.path.join(bdir, 'thumb128_' + os.path.basename(p))
            if not os.path.isfile(dst):
                shutil.copy2(p, dst)

    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = S / 2

    # 圆底：径向渐变（中心亮蓝 → 边缘深蓝）
    grad = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    steps = 64
    for i in range(steps):
        t = i / (steps - 1)
        r = S * 0.48 * (1 - t) + 2
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=lerp(BG_OUT, BG_IN, 1 - t) + (255,))
    im.alpha_composite(grad)

    # 细外环（双圈：亮环+内侧暗描）
    d.ellipse([3, 3, S - 3, S - 3], outline=RING + (255,), width=10)
    d.ellipse([14, 14, S - 14, S - 14], outline=(30, 44, 72, 255), width=6)

    # 四芒爆裂星：横竖长芒（菱形）+ 斜向短芒
    def spike(dx0, dy0, w, hgt, c_hot, c_mid):
        """以中心为基准的菱形长芒（垂直/水平向）。"""
        pts_v = [(cx, cy - hgt), (cx + w, cy), (cx, cy + hgt), (cx - w, cy)]
        pts_h = [(cx - hgt, cy), (cx, cy - w), (cx + hgt, cy), (cx, cy + w)]
        d.polygon(pts_v, fill=c_mid + (255,))
        d.polygon(pts_h, fill=c_mid + (255,))

    # 斜向短芒（45° 四向）
    diag = S * 0.16
    dw = S * 0.035
    for sx in (1, -1):
        for sy in (1, -1):
            pts = [(cx + sx * diag, cy), (cx, cy + sy * dw), (cx, cy - sy * dw)]
            pts = [(cx + sx * diag * 0.86, cy + sy * diag * 0.86),
                   (cx + sx * dw, cy + sy * dw * 0.2), (cx + sx * dw * 0.2, cy + sy * dw)]
            d.polygon(pts, fill=lerp(GOLD_MID, GOLD_DEEP, 0.4) + (235,))

    # 主四芒（横竖），长芒尖端细、中心粗——双层制造渐变
    L = S * 0.38
    W1 = S * 0.075
    spike(0, 0, W1, L, GOLD_HOT, GOLD_MID)
    d.polygon([(cx, cy - L), (cx + W1 * 0.55, cy), (cx, cy + L), (cx - W1 * 0.55, cy)],
              fill=lerp(GOLD_MID, GOLD_HOT, 0.55) + (255,))
    # 横向同款
    d.polygon([(cx - L, cy), (cx, cy + W1 * 0.55), (cx + L, cy), (cx, cy - W1 * 0.55)],
              fill=lerp(GOLD_MID, GOLD_HOT, 0.55) + (255,))
    d.polygon([(cx - L, cy), (cx, cy - W1), (cx + L, cy), (cx, cy + W1)],
              fill=GOLD_MID + (255,))

    # 中心白热核 + 周围爆裂弧光点
    core = S * 0.085
    d.ellipse([cx - core, cy - core, cx + core, cy + core], fill=(255, 252, 230, 255))
    core2 = S * 0.05
    d.ellipse([cx - core2, cy - core2, cx + core2, cy + core2], fill=(255, 255, 255, 255))
    # 四向飞溅小点（暴击火花）
    import math
    for ang, dist, rr in ((20, S * 0.30, 9), (70, S * 0.27, 7), (110, S * 0.31, 8),
                          (160, S * 0.28, 6), (200, S * 0.32, 8), (250, S * 0.29, 7),
                          (290, S * 0.33, 9), (340, S * 0.27, 6)):
        a = math.radians(ang)
        x, y = cx + dist * math.cos(a), cy + dist * math.sin(a)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=lerp(GOLD_HOT, GOLD_MID, 0.4) + (230,))

    out = im.resize((128, 128), Image.LANCZOS)
    out.save(ASSET)
    out.save(THUMB)
    print('pi_crit redrawn ->', ASSET, 'and thumb')


if __name__ == '__main__':
    main()
