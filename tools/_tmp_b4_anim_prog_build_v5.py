#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v5：用批次④卡图程序化合成动画（放弃视频通道的两个问题单位）。

- ww1_arm_rolls idle+attack ← docs/flow重生成_审查/战斗卡_批4/vis_player_001.png（一战菱形坦克）
- fut_inf_c96 attack        ← docs/flow重生成_审查/战斗卡_批4/fut_inf_c96.png（科幻步兵）

卡图直出：造型与卡图逐像素一致（零视频变形）；attack 火光沿枪口水平线（向前开枪）。
朝向：卡图朝左 → sheet 朝左 = 游戏约定（我方 flip_h 镜像成朝右，实机已验证）。
输出：512 master → 审查区；256 部署 → assets/effects/unit_anims/。
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = r"F:\godot fair duet\create\phase-war"
CARD = os.path.join(ROOT, "docs", "flow重生成_审查", "战斗卡_批4")
DEPLOY = os.path.join(ROOT, "assets", "effects", "unit_anims")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")
CANVAS = 512
FOOT = int(CANVAS * 0.92)


def cut_subject(png):
    """白底卡图 → 透明底主体 RGBA（含 0.8px 羽化），返回 tight-crop。"""
    im = Image.open(png).convert("RGB")
    arr = np.asarray(im)
    mask = (arr.min(axis=2) < 235).astype(np.uint8) * 255
    a = Image.fromarray(mask).filter(ImageFilter.GaussianBlur(0.8))
    rgba = im.convert("RGBA")
    rgba.putalpha(a)
    bb = a.getbbox()
    return rgba.crop(bb)


def to_canvas(sub, h_cap_frac=0.92):
    """主体缩放到 512 画布，脚底对齐 92%，水平居中。h_cap_frac=内容高占画布上限。"""
    w, h = sub.size
    scale = min((CANVAS - 16) / w, (CANVAS * h_cap_frac - 8) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x0, y0 = (CANVAS - nw) // 2, FOOT - nh
    cv.paste(sub, (x0, y0), sub)
    return cv, (x0, y0, x0 + nw, y0 + nh)


def sheet(frames, anim, unit_dir, rev_name):
    os.makedirs(unit_dir, exist_ok=True)
    fs = frames[0].size[0]
    sh = Image.new("RGBA", (fs * len(frames), fs), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sh.paste(f, (i * fs, 0))
        f.save(os.path.join(unit_dir, "f%02d.png" % i))
        # 清多余旧帧
    for i in range(len(frames), 14):
        p = os.path.join(unit_dir, "f%02d.png" % i)
        if os.path.exists(p):
            os.unlink(p)
    sh.save(os.path.join(unit_dir, "sheet_%s.png" % anim))
    sh.save(os.path.join(REV, "%s_%s_sheet.png" % (rev_name, anim)))
    return sh


def flash_star(draw, cx, cy, r, core=(255, 255, 220, 255), rim=(255, 170, 40, 220)):
    """枪口星形火光：橙底 + 黄白芯（2x 超采样由调用方缩放）。"""
    import math
    pts_o, pts_c = [], []
    for i in range(10):
        ang = i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        x, y = cx + rr * math.cos(ang), cy + rr * 0.72 * math.sin(ang)
        (pts_c if i % 2 == 0 else pts_o).append((x, y))
        pts_o.append((x, y)) if i % 2 == 0 else None
    draw.polygon(pts_c, fill=rim)
    draw.polygon([(cx + rr * 0.5 * math.cos(i * math.pi / 5), cy + rr * 0.36 * math.sin(i * math.pi / 5))
                  for i in range(10)], fill=core)


# ────────────────────── rolls（vis_player_001 一战菱形坦克）──────────────────────
sub = cut_subject(os.path.join(CARD, "vis_player_001.png"))
base, bb = to_canvas(sub)
x0, y0, x1, y1 = bb
arr = np.asarray(base)
solid = arr[:, :, 3] > 128
cols = np.where(solid.any(axis=0))[0]
rows = np.where(solid.any(axis=1))[0]
# 炮位：车体左端，垂直取车体实心行的中位带
band = np.where(solid.sum(axis=1) > max(3, solid.any(axis=1).sum() * 0.02))[0]
gun_y = int(np.median(band))
gun_x = int(cols.min()) + 6

# idle: 车体微颤（y 抖 1-2px，引擎怠速感）
bob = [0, -1, -2, -1, 0, -1, -2, -1]
idle = []
for dy in bob:
    f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    f.paste(base, (0, dy), base)
    idle.append(f)

# attack: 0-3 瞄准 → 4-6 开火(火光+后坐+抛壳) → 7-9 余焰 → 10-11 回位
atk = []
for i in range(12):
    rec = 5 if 4 <= i <= 6 else (2 if 7 <= i <= 9 else 0)
    f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    f.paste(base, (rec, 0), base)
    d = ImageDraw.Draw(f)
    if 4 <= i <= 6:
        r = 26 if i == 4 else (20 if i == 5 else 14)
        flash_star(d, gun_x - 10, gun_y, r)
        d.ellipse([gun_x - 52, gun_y - 5, gun_x - 10, gun_y + 5], fill=(255, 200, 80, 190))
        d.ellipse([x1 - 60, gun_y + 8, x1 - 52, gun_y + 16], fill=(230, 160, 60, 220))  # 抛壳
    elif 7 <= i <= 9:
        d.ellipse([gun_x - 34, gun_y - 7, gun_x - 6, gun_y + 7], fill=(255, 180, 70, 110))
    atk.append(f)

sheet(idle, "idle", os.path.join(DEPLOY, "ww1_arm_rolls"), "ww1_arm_rolls")
sheet(atk, "attack", os.path.join(DEPLOY, "ww1_arm_rolls"), "ww1_arm_rolls")
print("rolls built: idle 8 / attack 12")

# ────────────────────── c96 attack（fut_inf_c96 科幻步兵）──────────────────────
sub2 = cut_subject(os.path.join(CARD, "fut_inf_c96.png"))
base2, bb2 = to_canvas(sub2, h_cap_frac=0.88)  # 与 v4 idle 同口径，头顶留 ~14px/256
# ⚠ 卡图人物实际朝右（网格实测：枪口 x≈365,y≈190,面甲朝右）——sheet 约定朝左，
#   必须镜像；否则我方 flip 后游戏内反向开枪 + 火光落在背包（v5 首版翻车点）。
base2 = base2.transpose(Image.FLIP_LEFT_RIGHT)
muz_x, muz_y = 147, 190  # 镜像后枪口 = (512-365, 190)，网格实测硬编码
print("c96 muzzle fixed at", muz_x, muz_y)

atk2 = []
for i in range(12):
    rec = 3 if i in (2, 3, 8, 9) else 0
    f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    f.paste(base2, (rec, 0), base2)
    d = ImageDraw.Draw(f)
    if i in (2, 3, 8, 9):
        big = i in (2, 8)
        # 水平枪口火光 + 沿水平线的能量弹痕（向前=水平向左）
        flash_star(d, muz_x - 8, muz_y, 22 if big else 14)
        L = 84 if big else 46
        d.polygon([(muz_x - 12, muz_y - 5), (muz_x - 12, muz_y + 5),
                   (muz_x - 12 - L, muz_y + 2), (muz_x - 12 - L, muz_y - 2)],
                  fill=(120, 240, 220, 160 if big else 110))
        d.ellipse([muz_x + 26, muz_y + 4, muz_x + 33, muz_y + 11],
                  fill=(255, 200, 90, 210))  # 抛壳
    atk2.append(f)

sheet(atk2, "attack", os.path.join(DEPLOY, "fut_inf_c96"), "fut_inf_c96")
print("c96 attack built: 12")

# ────────────────────── 部署 256 + 校验 ──────────────────────
for u, a, want in (("ww1_arm_rolls", "idle", 8), ("ww1_arm_rolls", "attack", 12),
                   ("fut_inf_c96", "attack", 12)):
    p = os.path.join(DEPLOY, u, "sheet_%s.png" % a)
    im = Image.open(p).convert("RGBA")
    out = im.resize((im.size[0] // 2, 256), Image.LANCZOS)
    out.save(p)
    print("deploy", p, out.size)
print("V5 DONE")
