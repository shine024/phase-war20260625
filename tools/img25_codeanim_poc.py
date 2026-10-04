# -*- coding: utf-8 -*-
"""img25 代码驱动动画 PoC：锚定帧三层 cutout -> 10帧 5x2 开火雪碧图（2026-09-30 概念验证）

对照生图路线（img25_attack_gen.py）的替代/抢救路实验：
    锚定帧仍由生图出（保风格），动作全部由确定性代码驱动——
    车身/炮管/炮塔三层矩形切割，炮管后坐 + 炮口焰/烟代码直画，逐帧落 PNG。
    零逐格漂移（垂直注册工序消失）、零身份错位（10 帧同一张图的变换）。

用法:
    python tools/img25_codeanim_poc.py <key> [--split-y N] [--barrel-y0 N] [--barrel-y1 N] [--barrel-x N]

前置: staging/<key>_anchor_raw.png 已存在（与 img25_attack_gen.py 同一阶段0产物）。

产出（只落 staging）:
    <key>_codepoc_layers.png      三层切割调试图（目检切线）
    <key>_codepoc_sheet.png       10帧 5x2 雪碧图（512 格）
    <key>_codepoc_anim.gif        256 格 12fps 动图预览

三条禁令（知乎"代码视频"文）：不读真实时钟、随机只走固定种子、不联网——
每帧只取决于帧号，重复运行逐像素一致。
"""
import argparse
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from img25_attack_gen import detect_bg_color, chroma_key, depink  # 键控/去粉复用主路

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
SEED = 20260930

COLS, ROWS = 5, 2          # 10 帧开火表版式（与主路一致）
CELL = 512                 # PoC 雪碧图格尺寸
GIF_CELL = 256             # 动图预览格尺寸
FPS = 12

# ---- 动画参数（1024 原图坐标系）----
RECOIL_BARREL = 14         # 炮管后坐峰值（+x，炮管朝左）
RECOIL_TURRET = 4          # 炮塔随动峰值
HULL_BOB = 3               # 开火车身下沉峰值
FLASH_FRAME = 1            # 点火帧
FLASH_LIFE = 3             # 焰持续帧数
SMOKE_N = 6                # 烟团数


def load_anchor(key):
    im = Image.open(os.path.join(OUT, "%s_anchor_raw.png" % key))
    rgba = depink(chroma_key(im, detect_bg_color(im)))
    return rgba


def cut_layers(rgba, split_y, barrel):
    """三层矩形切割：炮管带（含于炮塔层之下）/ 炮塔层（split_y 以上）/ 车身层（其余）。
    炮管层后坐时从炮塔层下方缩进，接缝藏于炮塔装甲后（绘制序：车身->炮管->炮塔）。
    裁剪层保留原 y0 供合成回贴（裁剪坐标=画布绝对坐标）。"""
    y0, y1, xmax = barrel
    full = rgba.copy()
    turret = full.crop((0, 0, full.width, split_y))
    turret.paste((0, 0, 0, 0), (0, y0, xmax, y1))  # 挖走炮管带
    barrel_l = full.crop((0, y0, xmax, y1))
    barrel_l.y0 = y0
    hull = full.crop((0, split_y, full.width, full.height))
    return hull, barrel_l, turret, (0, split_y)


def draw_flash(dur_scale, rng, tip, flip):
    """炮口焰：多角星 + 前向锥形瓣，白芯->金黄->橙缘。dur_scale 控制生命周期衰减。"""
    if dur_scale <= 0:
        return None
    S = 110 * dur_scale
    layer = Image.new("RGBA", (int(S * 4), int(S * 4)), (0, 0, 0, 0))
    cx, cy = layer.width // 2, layer.height // 2
    d = ImageDraw.Draw(layer)
    n = 9
    for radius, width, color in (
        (1.0, 0.42, (255, 122, 26, 215)),
        (0.72, 0.34, (255, 201, 62, 235)),
        (0.42, 0.30, (255, 244, 214, 255)),
    ):
        R, r = S * radius, S * radius * width
        pts = []
        for i in range(n * 2):
            ang = 3.14159 * i / n + rng.uniform(-0.09, 0.09)
            rad = r if i % 2 else R * rng.uniform(0.72, 1.25)
            pts.append((cx + rad * -CosSin(ang)[0] * flip, cy + rad * CosSin(ang)[1]))
        d.polygon(pts, fill=color)
    # 前向锥形瓣（炮口方向拉伸）
    d.ellipse((cx - S * 1.5 * flip, cy - S * 0.30, cx + S * 0.5 * flip, cy + S * 0.30),
              fill=(255, 170, 40, 190))
    d.ellipse((cx - S * 0.55 * flip, cy - S * 0.34, cx + S * 0.55 * flip, cy + S * 0.34),
              fill=(255, 248, 228, 255))
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.09))
    layer.alpha_composite(glow)
    return layer, (tip[0] - cx, tip[1] - cy)


def CosSin(ang):
    import math
    return (math.cos(ang), math.sin(ang))


def draw_smoke(layer, puffs):
    """烟团：浅灰软圆（大模糊半径出梯度），半径随生命膨胀、alpha 衰减。"""
    for (x, y, rad, alpha) in puffs:
        s = max(8, int(rad * 5))
        puff = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        d = ImageDraw.Draw(puff)
        d.ellipse((s // 4, s // 4, s - s // 4, s - s // 4), fill=(172, 174, 180, alpha))
        puff = puff.filter(ImageFilter.GaussianBlur(s // 5))
        layer.alpha_composite(puff, (int(x - s / 2), int(y - s / 2)))


def frame_pose(f):
    """时间表：帧号 -> 各层位移。点火->峰值->指数回落->怠速。全纯函数。"""
    t = f - FLASH_FRAME
    if t < 0:
        return 0, 0, 0, 0.0
    decay = pow(0.55, t)
    barrel_dx = int(RECOIL_BARREL * decay) if t >= 0 else 0
    turret_dx = int(RECOIL_TURRET * decay)
    bob = int(HULL_BOB * decay) if t <= 3 else 0
    flash = max(0.0, 1.0 - t / FLASH_LIFE) if t < FLASH_LIFE else 0.0
    return barrel_dx, turret_dx, bob, flash


def compose_frame(rgba, layers, f, rng, tip):
    hull, barrel_l, turret, (_sx, sy) = layers
    y0 = barrel_l.y0  # 裁剪层内坐标 -> 画布绝对坐标（裁剪即绝对坐标，勿再叠加 sy）
    barrel_dx, turret_dx, bob, flash_s = frame_pose(f)
    canvas = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    canvas.alpha_composite(hull, (0, sy + bob))
    canvas.alpha_composite(barrel_l, (barrel_dx, y0 + bob))
    canvas.alpha_composite(turret, (turret_dx, bob))
    tip_f = (tip[0] + barrel_dx, tip[1] + bob)
    if flash_s > 0:
        fl = draw_flash(flash_s, rng, tip_f, 1)
        if fl:
            img, off = fl
            canvas.alpha_composite(img, (int(off[0]), int(off[1])))
    # 烟：点火后 1 帧起，炮口左上加速漂移；错峰寿命 max_life=6.5-i*0.8
    # => f8 基本散尽、f9 全清，循环回 f0 无跳变
    t = f - FLASH_FRAME
    if 1 <= t:
        puffs = []
        for i in range(SMOKE_N):
            max_life = 6.5 - i * 0.8
            life = t - 1 - i * 0.7
            if life < 0 or life > max_life:
                continue
            k = life / 7.0
            drift = life * life * 0.35 + life * (18 + i * 5)   # 二次项出加速感
            puffs.append((tip_f[0] - 24 - drift,
                          tip_f[1] - 10 - life * (14 + i * 3.5) + rng.uniform(-6, 6),
                          13 + k * 34 + i * 2, int(125 * (1 - k))))
        draw_smoke(canvas, puffs)
    return canvas


def normalize_frames(frames, cell):
    """全帧联合 bbox 底缘对齐 + 水平居中（脚底线注册，与主路 normalize 同规则）。"""
    import numpy as np
    u = None
    for fr in frames:
        a = np.asarray(fr)[:, :, 3]
        ys, xs = np.where(a > 8)
        bb = (xs.min(), ys.min(), xs.max(), ys.max())
        u = bb if u is None else (min(u[0], bb[0]), min(u[1], bb[1]),
                                  max(u[2], bb[2]), max(u[3], bb[3]))
    out = []
    for fr in frames:
        c = fr.crop((u[0], u[1], u[2] + 1, u[3] + 1))
        sc = (cell - 16) / max(c.width, c.height)
        c = c.resize((max(1, int(c.width * sc)), max(1, int(c.height * sc))), Image.LANCZOS)
        base = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        base.alpha_composite(c, ((cell - c.width) // 2, cell - 8 - c.height))
        out.append(base)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--split-y", type=int, default=518)
    ap.add_argument("--barrel", type=int, nargs=3, default=(424, 482, 505), metavar=("Y0", "Y1", "XMAX"))
    args = ap.parse_args()

    rgba = load_anchor(args.key)
    layers = cut_layers(rgba, args.split_y, args.barrel)

    # 炮口尖 = 炮管带最左不透明像素
    import numpy as np
    ba = np.asarray(layers[1])[:, :, 3]
    ys, xs = np.where(ba > 8)
    tip = (int(xs.min()), int(ys.mean()) + args.barrel[0])
    print("muzzle tip @", tip)

    # 调试图：三层并排 + 切线
    dbg = Image.new("RGBA", (1024 * 2, 1024 + 340), (24, 24, 28, 255))
    marks = rgba.copy()
    d = ImageDraw.Draw(marks)
    d.line((0, args.split_y, 1024, args.split_y), fill=(255, 60, 60, 255), width=3)
    d.line((0, args.barrel[0], 1024, args.barrel[0]), fill=(80, 200, 255, 255), width=3)
    d.line((0, args.barrel[1], 1024, args.barrel[1]), fill=(80, 200, 255, 255), width=3)
    d.line((args.barrel[2], args.barrel[0], args.barrel[2], args.barrel[1]), fill=(80, 200, 255, 255), width=3)
    d.ellipse((tip[0] - 10, tip[1] - 10, tip[0] + 10, tip[1] + 10), outline=(255, 255, 0, 255), width=3)
    dbg.paste(marks.convert("RGB"), (0, 0))
    for i, im_ in enumerate(layers[:3]):
        thumb = im_.resize((im_.width // 2, im_.height // 2), Image.LANCZOS)
        base = Image.new("RGBA", dbg.size, (0, 0, 0, 0))
        base.alpha_composite(thumb, (60 + i * 340, 1024 + 10))
        dbg.alpha_composite(base)
    dbg.convert("RGB").save(os.path.join(OUT, "%s_codepoc_layers.png" % args.key))

    # 10 帧合成（rng 固定种子，帧序使用 => 逐帧确定）
    rng = random.Random(SEED)
    frames = [compose_frame(rgba, layers, f, rng, tip) for f in range(COLS * ROWS)]

    cells = normalize_frames(frames, CELL)
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, ((i % COLS) * CELL, (i // COLS) * CELL))
    sheet.save(os.path.join(OUT, "%s_codepoc_sheet.png" % args.key))

    gif_cells = normalize_frames(frames, GIF_CELL)
    gif = [Image.alpha_composite(Image.new("RGBA", c.size, (255, 255, 255, 255)), c).convert("P")
           for c in gif_cells]
    gif[0].save(os.path.join(OUT, "%s_codepoc_anim.gif" % args.key),
                save_all=True, append_images=gif[1:], duration=int(1000 / FPS), loop=0)
    print("OK", args.key)


if __name__ == "__main__":
    main()
