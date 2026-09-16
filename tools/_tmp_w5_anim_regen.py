#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W5 追加轮：动画-卡图同步（2026-09-14）。

1) ww1_arm_rolls（001 罗尔斯装甲车）程序化合成 v6 —— 范式沿 _tmp_b4_anim_prog_build_v5.py
   （v5 实机验收裁定：载具禁走视频通道，卡图直出零变形）。源 = 新 001 卡 enemy 512
   （透明、朝左，即 sheet 约定朝向）。旧表备份进审查区。
2) garand 视频 ref 重建（新卡设计同步；朝左，enemy 卡天然朝左，垫白 512）。
   视频任务由 generate_unit_animations.py create/poll/build 驱动，本脚本只造 ref。
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEPLOY = os.path.join(ROOT, "assets", "effects", "unit_anims")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")
REF_DIR = os.path.join(ROOT, "资料", "单位分帧动画", "_ref")
CANVAS = 512
FOOT = int(CANVAS * 0.92)


def cut_transparent(png):
    """透明底 512 卡 → tight-crop 主体 RGBA。"""
    im = Image.open(png).convert("RGBA")
    bb = im.getbbox()
    return im.crop(bb)


def to_canvas(sub, h_cap_frac=0.92):
    w, h = sub.size
    scale = min((CANVAS - 16) / w, (CANVAS * h_cap_frac - 8) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x0, y0 = (CANVAS - nw) // 2, FOOT - nh
    cv.paste(sub, (x0, y0), sub)
    return cv, (x0, y0, x0 + nw, y0 + nh)


def flash_star(draw, cx, cy, r, core=(255, 255, 220, 255), rim=(255, 170, 40, 220)):
    import math
    pts_c = []
    for i in range(10):
        ang = i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        pts_c.append((cx + rr * math.cos(ang), cy + rr * 0.72 * math.sin(ang)))
    draw.polygon(pts_c, fill=rim)
    draw.polygon([(cx + r * 0.5 * math.cos(i * math.pi / 5), cy + r * 0.36 * math.sin(i * math.pi / 5))
                  for i in range(10)], fill=core)


def emit(frames, anim, unit_dir, rev_name):
    os.makedirs(unit_dir, exist_ok=True)
    os.makedirs(REV, exist_ok=True)
    fs = frames[0].size[0]
    sh = Image.new("RGBA", (fs * len(frames), fs), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sh.paste(f, (i * fs, 0))
        f.save(os.path.join(unit_dir, "f%02d.png" % i))
    for i in range(len(frames), 14):
        p = os.path.join(unit_dir, "f%02d.png" % i)
        if os.path.exists(p):
            os.unlink(p)
    sh.save(os.path.join(REV, "%s_%s_sheet.png" % (rev_name, anim)))
    return sh


# ═══════════ 1) garand 视频 ref 重建 ═══════════
os.makedirs(REF_DIR, exist_ok=True)  # _ref 随 09-07 出库轮消失，按需重建（经 junction 落 _anim_review）
ref_path = os.path.join(REF_DIR, "ww2_arm_garand_para_white.jpg")
if os.path.exists(ref_path):
    bak = os.path.join(REF_DIR, "_backup_preW3C_2026-09-14_ww2_arm_garand_para_white.jpg")
    if not os.path.exists(bak):
        shutil.copy2(ref_path, bak)
        print("[ref] 旧 ref 已备份")
card = Image.open(os.path.join(ROOT, "assets", "card_icons", "enemy", "ww2_arm_garand_para.png")).convert("RGBA")
canvas = Image.new("RGB", (512, 512), (255, 255, 255))
canvas.paste(card, (0, 0), card)
canvas.save(ref_path, "JPEG", quality=92)
print("[ref] 新 ref 写入 ww2_arm_garand_para_white.jpg（enemy 卡朝左，垫白 512）")

# ═══════════ 2) rolls 程序化合成 v6（新 001 卡）═══════════
unit_dir = os.path.join(DEPLOY, "ww1_arm_rolls")
# 旧部署表备份（flow 轮菱形坦克版）
for anim in ("idle", "attack"):
    cur = os.path.join(unit_dir, "sheet_%s.png" % anim)
    if os.path.exists(cur):
        bak = os.path.join(REV, "ww1_arm_rolls_%s_sheet_preW3C.png" % anim)
        if not os.path.exists(bak):
            shutil.copy2(cur, bak)
print("[rolls] 旧 sheet 已备份 preW3C")

sub = cut_transparent(os.path.join(ROOT, "assets", "card_icons", "enemy", "vis_player_001.png"))
base, bb = to_canvas(sub)
x0, y0, x1, y1 = bb
arr = np.asarray(base)
solid = arr[:, :, 3] > 128
cols = np.where(solid.any(axis=0))[0]
# 炮位：车体左端（sheet 朝左=向前）；炮管高度取左缘 14 列实心行的中位
left_band = solid[:, int(cols.min()):int(cols.min()) + 14]
rows_l = np.where(left_band.any(axis=1))[0]
gun_y = int(np.median(rows_l)) if len(rows_l) else int(np.median(np.where(solid.any(axis=1))[0]))
gun_x = int(cols.min()) + 6
print("[rolls] 炮口锚点 gun=(%d,%d) bbox=%s" % (gun_x, gun_y, bb))

bob = [0, -1, -2, -1, 0, -1, -2, -1]
idle = []
for dy in bob:
    f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    f.paste(base, (0, dy), base)
    idle.append(f)

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
        d.ellipse([x1 - 60, gun_y + 8, x1 - 52, gun_y + 16], fill=(230, 160, 60, 220))
    elif 7 <= i <= 9:
        d.ellipse([gun_x - 34, gun_y - 7, gun_x - 6, gun_y + 7], fill=(255, 180, 70, 110))
    atk.append(f)

emit(idle, "idle", unit_dir, "ww1_arm_rolls")
emit(atk, "attack", unit_dir, "ww1_arm_rolls")

# 512 master 留审查区（emit 已存），部署 256
for anim in ("idle", "attack"):
    p = os.path.join(unit_dir, "sheet_%s.png" % anim)
    im = Image.open(p).convert("RGBA")
    out = im.resize((im.size[0] // 2, 256), Image.LANCZOS)
    out.save(p)
    print("[rolls] deploy", os.path.relpath(p, ROOT), out.size)
print("ROLLS V6 DONE")
