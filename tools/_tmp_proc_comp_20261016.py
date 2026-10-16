# -*- coding: utf-8 -*-
"""程序合成两单(2026-10-16,交接文档 §四):
- 116 mod_fort_citadel:闪电球 attack 6 帧(充能小→中→大→峰值→消散→收),球画核心彩环位
- 070 fut_boss_nexus:大电光 attack 6 帧,绕水晶塔主放电+分叉

闪电渲染三层(粗暗/中亮/白核)+高斯辉光,additive 混合防硬边花斑(firegrid 教训)。
seed 固定可复现。输出直接写 assets(备份已有:.godot/unit_anims_backup_20261016/)。
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
rng = np.random.default_rng(20261016)


def draw_bolt(dr, pts, w_dark, w_mid, w_core, col):
    """三层线:暗晕/亮体/白核。"""
    dr.line(pts, fill=(40, 30, 90, 160), width=w_dark, joint="curve")
    dr.line(pts, fill=col + (230,), width=w_mid, joint="curve")
    dr.line(pts, fill=(250, 250, 255, 255), width=w_core, joint="curve")


def gen_bolt(x0, y0, x1, y1, jag, n_fork=3):
    """随机游走折线+分叉。返回 [主干, 分叉1, ...] 各为 [(x,y)...]。"""
    n = max(6, int(math.hypot(x1 - x0, y1 - y0) / 12))
    xs = np.linspace(x0, x1, n)
    ys = np.linspace(y0, y1, n)
    perp = [-(y1 - y0), (x1 - x0)]
    pl = math.hypot(*perp) or 1.0
    off = rng.normal(0, jag, n)
    off[0] = off[-1] = 0
    main = [(float(xs[i] + perp[0] / pl * off[i]), float(ys[i] + perp[1] / pl * off[i]))
            for i in range(n)]
    forks = []
    for _ in range(n_fork):
        i = int(rng.integers(2, n - 2))
        fx, fy = main[i]
        ang = math.atan2(y1 - y0, x1 - x0) + float(rng.normal(0, 0.9))
        ln = float(rng.uniform(14, 34)) * (1.0 if rng.random() < 0.5 else -1.0)
        forks.append([(fx, fy),
                      (fx + math.cos(ang) * ln, fy + math.sin(ang) * ln),
                      (fx + math.cos(ang + float(rng.normal(0, 0.5))) * ln * 1.5,
                       fy + math.sin(ang + float(rng.normal(0, 0.5))) * ln * 1.5)])
    return main, forks


def glow_add(base, lay, cx_blur):
    """辉光层模糊后 additive 叠底(soft,防硬切花斑)。"""
    g = lay.filter(ImageFilter.GaussianBlur(cx_blur))
    a = np.asarray(g).astype(np.int32)
    b = np.asarray(base).astype(np.int32)
    out = np.clip(b + (a * a // 256), 0, 255).astype(np.uint8)  # 平方衰减=软辉
    return Image.fromarray(out)


def frame_compose(base_im, glow_fn, crisp_fn=None, blur=5):
    """双层合成:glow_fn 件只走 additive 软辉(羽化防硬边花斑);
    crisp_fn 件(电丝本体)blur 小幅+alpha 叠回保锐。"""
    gl = Image.new("RGBA", base_im.size, (0, 0, 0, 0))
    if glow_fn:
        glow_fn(ImageDraw.Draw(gl))
    out = glow_add(base_im, gl, blur)
    if crisp_fn:
        cl = Image.new("RGBA", base_im.size, (0, 0, 0, 0))
        crisp_fn(ImageDraw.Draw(cl))
        out = glow_add(out, cl, 1)
        out.alpha_composite(cl)
    out.alpha_composite(gl.filter(ImageFilter.GaussianBlur(blur * 2)))
    return out


def attack_sheet(base_im, frames, dst):
    """frames: [(glow_fn, crisp_fn)]"""
    fs = 256
    sheet = Image.new("RGBA", (fs * len(frames), fs), (0, 0, 0, 0))
    for i, (gf, cf) in enumerate(frames):
        fr = frame_compose(base_im, gf, cf)
        sheet.paste(fr, (i * fs, 0))
    sheet.save(dst)
    print("写", os.path.relpath(dst, ROOT))


# ---------------- 116 citadel: 闪电球 小→中→大→峰值→消散→收 ----------------
cit = Image.open(os.path.join(ANIM, "mod_fort_citadel", "sheet_idle.png")).convert("RGBA")
f0 = cit.crop((0, 0, 256, 256))
CX, CY = 128, 152          # 核心彩环圆心(目验)
RAD = [7, 13, 20, 27, 16, 5]
BRI = [0.35, 0.6, 0.85, 1.0, 0.55, 0.25]


def ball_fns(r, bri):
    """(glow_fn, crisp_fn):盘与放射丝晕走辉光层,丝芯走 crisp。"""
    def _g(dr):
        for rr, aa in [(r + 12, 46), (r + 6, 90), (r, 130)]:
            dr.ellipse([CX - rr, CY - rr, CX + rr, CY + rr],
                       fill=(110, 85, 255, int(aa * bri)))
        for _ in range(int(5 + 7 * bri)):
            a0 = float(rng.uniform(0, math.tau))
            r0 = r * float(rng.uniform(0.9, 1.15))
            pts = [(CX, CY)]
            for k in range(1, 4):
                a = a0 + float(rng.normal(0, 0.35))
                pts.append((CX + math.cos(a) * r0 * k / 3, CY + math.sin(a) * r0 * k / 3))
            dr.line(pts, fill=(190, 160, 255, int(150 * bri)), width=2, joint="curve")

    def _c(dr):
        for _ in range(int(3 + 5 * bri)):
            a0 = float(rng.uniform(0, math.tau))
            r0 = r * float(rng.uniform(0.85, 1.1))
            pts = [(CX, CY)]
            for k in range(1, 4):
                a = a0 + float(rng.normal(0, 0.35))
                pts.append((CX + math.cos(a) * r0 * k / 3, CY + math.sin(a) * r0 * k / 3))
            dr.line(pts, fill=(210, 180, 255, int(210 * bri)), width=1, joint="curve")
    return _g, _c


cit_frames = []
for i in range(6):
    bri = BRI[i]
    gf, cf = ball_fns(RAD[i], bri)
    if i != 3:
        cit_frames.append((gf, cf))
        continue

    def _peak(dr, _cf=cf):
        # 峰值帧 crisp=球丝+四周 2~3 条短外闪
        _cf(dr)
        for _ in range(3):
            a0 = float(rng.uniform(0, math.tau))
            main, forks = gen_bolt(CX + math.cos(a0) * 20, CY + math.sin(a0) * 20,
                                   CX + math.cos(a0) * 55, CY + math.sin(a0) * 55,
                                   jag=5.0, n_fork=1)
            draw_bolt(dr, main, 4, 2, 1, (190, 160, 255))
            for fk in forks:
                draw_bolt(dr, fk, 3, 1, 1, (190, 160, 255))
    cit_frames.append((gf, _peak))

attack_sheet(f0, cit_frames, os.path.join(ANIM, "mod_fort_citadel", "sheet_attack.png"))

# ---------------- 070 nexus: 塔身大电光 6 帧 ----------------
# ⚠️ 真目标=fut_nexus(attach 实走,ANIM_ALIAS fut_boss_nexus→fut_nexus);
# fut_boss_nexus 目录=死资产(无 sheet_idle,_resolve_key ①不命中)。
nex = Image.open(os.path.join(ANIM, "fut_nexus", "sheet_idle.png")).convert("RGBA")
nf0 = nex.crop((0, 0, 256, 256))
TX0, TX1 = 125, 172        # 塔身横向(目验 fut_nexus idle f0)
TY0, TY1 = 28, 158         # 塔纵向
NRI = [0.35, 0.65, 1.0, 0.8, 0.5, 0.25]
nx_frames = []
for i in range(6):
    bri = NRI[i]

    def _ng(dr, _b=bri):
        # 辉光层:塔体晕+塔尖光(仅 additive,无硬边本体)
        dr.rectangle([TX0 - 6, TY0 - 4, TX1 + 6, TY1 + 6],
                     fill=(90, 150, 255, int(60 * _b)))
        dr.ellipse([140, 12, 172, 38], fill=(110, 190, 255, int(120 * _b)))

    def _nc(dr, _b=bri):
        # crisp 层:塔身主放电 2 条 + 分叉
        for _ in range(2):
            x0 = float(rng.uniform(TX0 + 10, TX1 - 10))
            x1 = float(rng.uniform(TX0 + 10, TX1 - 10))
            main, forks = gen_bolt(x0, TY0 + float(rng.uniform(0, 10)),
                                   x1, TY1 - float(rng.uniform(0, 8)),
                                   jag=6.0, n_fork=2)
            draw_bolt(dr, main, 4, 2, 1, (140, 200, 255))
            for fk in forks:
                draw_bolt(dr, fk, 3, 1, 1, (140, 200, 255))
        if _b > 0.6:  # 强帧外扩:塔侧电弧
            for _ in range(2):
                side = 1 if rng.random() < 0.5 else -1
                y0 = float(rng.uniform(TY0 + 10, TY1))
                main, forks = gen_bolt(148 + side * 8, y0,
                                       148 + side * float(rng.uniform(34, 52)),
                                       y0 + float(rng.normal(0, 18)),
                                       jag=5.0, n_fork=1)
                draw_bolt(dr, main, 3, 1, 1, (150, 210, 255))
    nx_frames.append((_ng, _nc))

attack_sheet(nf0, nx_frames, os.path.join(ANIM, "fut_nexus", "sheet_attack.png"))
print("done")
