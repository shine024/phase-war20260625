# -*- coding: utf-8 -*-
"""MK8 收尾批 3（2026-10-05）：void/juggernaut 锚定路线产物组装。
输入（_mk8_anchor2 + _mk8_relight2 产物，attack 掷为 pre-lift 锚定所出但曝光可读）：
  idle  = img25_staging/<u>_idle_sheet_512.png（relit 锚定所 build，偏暗）
  attack = img25_staging/<u>_{R}_attack_sheet_832.png
处理：
  1. attack 选格序列 → depink_erase + 粉渍补刀（底带限定：(r-g>b-g+15) 粉系判据，
     不误杀 void 紫能量线（其 b-g>r-g））→ alpha bbox 归一化（统一身高，底缘锚定）
  2. idle gamma 提升：γ = ln(E_atk/255)/ln(E_idle/255)（对齐 attack 曝光，黑场不抬）
  3. 全帧水平翻转（掷出朝左 → 与现役 sheet 朝右一致）
输出 512×6f attack 横条 + 512 idle 横条（_L 后缀）落 img25_staging，部署端 bake。
用法: python tools/_mk8_finish3.py
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
STG8 = os.path.join(ROOT, ".godot", "unit_review", "mk8_staging")

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

PLAN = {
    "fe_void_dimensional_soldier": ("R1", [0, 4, 1, 1, 4, 0], {0}),   # 待机→瞄准→点射×2→收→待机
    # （R1 掷内朝向混杂：c1 朝左须翻转，c2/c5 朝右保真——火光质心+400px 目验实测）
    "fe_iron_wall_juggernaut": ("R2", [0, 1, 2, 3, 0, 0], set()),     # 待机→大光→烟尾→回复→待机
}


def depink_erase(rgba):
    a = np.asarray(rgba).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    pink = (al > 8) & (r - g > 40) & (b - g > 40)
    a[:, :, 3] = np.where(pink, 0, al)
    return Image.fromarray(a.astype("uint8"))


def scrub_pink_feet(rgba, band=0.30):
    """底带粉渍补刀：粉系（r-g>b-g+15，r-g>22，中亮度）→ 透明。
    void 紫能量线 b-g>r-g 不命中；橙火 b 低（b-g<0）不命中。"""
    a = np.asarray(rgba).astype(int)
    h = a.shape[0]
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    lum = (r + g + b) // 3
    zone = np.zeros((h, a.shape[1]), bool)
    zone[int(h * (1 - band)):, :] = True
    pink = (zone & (al > 8) & (r - g > 22) & ((r - g) > (b - g) + 15)
            & (lum > 50) & (lum < 200))
    a[:, :, 3] = np.where(pink, 0, al)
    n = int(pink.sum())
    return Image.fromarray(a.astype("uint8")), n


def alpha_bbox(rgba, thr=40):
    a = np.asarray(rgba)[:, :, 3]
    ys, xs = np.where(a > thr)
    if not len(ys):
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def body_energy(rgba):
    """非透明非火光像素均值（曝光对齐用）。"""
    a = np.asarray(rgba).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    body = al > 128
    flame = (r > 140) & (r - b > 60)
    m = body & ~flame
    if not m.any():
        return 60.0
    return float(a[:, :, :3][m].mean())


def gamma_lut(gam):
    return [min(255, int(round(255.0 * ((v / 255.0) ** gam)))) for v in range(256)]


def main():
    for unit, (roll, seq, flipset) in PLAN.items():
        print("== %s (%s %s flip=%s) ==" % (unit, roll, seq, sorted(flipset)), flush=True)
        # ── attack ──
        sh = Image.open(os.path.join(OUT, "%s_%s_attack_sheet_832.png" % (unit, roll))).convert("RGBA")
        cell = sh.width // 3
        cells = [sh.crop(((i % 3) * cell, (i // 3) * cell, (i % 3 + 1) * cell, (i // 3 + 1) * cell))
                 for i in range(6)]
        picked = []
        for idx in seq:
            c = cells[idx]
            if idx in flipset:
                c = c.transpose(Image.FLIP_LEFT_RIGHT)
            c = depink_erase(c)
            c, n = scrub_pink_feet(c)
            picked.append((c, idx, n))
        # 归一化：统一到最高身高
        boxes = [alpha_bbox(c) for c, _, _ in picked]
        hmax = max(b[3] - b[1] for b in boxes)
        wmax = max(b[2] - b[0] for b in boxes)
        FS = 512
        margin_b, margin_s = 16, 24
        frames = []
        for (c, idx, n), bb in zip(picked, boxes):
            crop = c.crop(bb)
            sc = min((FS - margin_s * 2) / (crop.width or 1),
                     (FS - margin_b * 2) / (crop.height or 1), 4.0)
            crop = crop.resize((max(1, int(crop.width * sc)), max(1, int(crop.height * sc))),
                               Image.LANCZOS)
            fr = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
            fr.paste(crop, ((FS - crop.width) // 2, FS - margin_b - crop.height), crop)
            frames.append(fr)   # 10-05 实测掷出即朝右（火光质心 567/657>416），勿翻转
            print("  cell%d 粉渍=%d bbox=%s sc=%.2f" % (idx, n, bb, sc), flush=True)
        atk = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            atk.paste(f, (i * FS, 0))
        atk.save(os.path.join(OUT, "%s_attack_sheet_512n.png" % unit))
        # ── idle：γ 对齐 attack 曝光 ──
        idl = Image.open(os.path.join(OUT, "%s_idle_sheet_512.png" % unit)).convert("RGBA")
        e_idl = body_energy(idl.crop((0, 0, FS, FS)))
        e_atk = float(np.mean([body_energy(f) for f in frames]))
        gam = np.log(e_atk / 255.0) / np.log(e_idl / 255.0)
        gam = float(np.clip(gam, 0.6, 1.0))
        lut = gamma_lut(gam)
        r_, g_, b_, a_ = idl.split()
        po = Image.merge("RGBA", (r_.point(lut), g_.point(lut), b_.point(lut), a_))
        po.save(os.path.join(OUT, "%s_idle_sheet_512L.png" % unit))
        print("  idle E=%.1f → attack E=%.1f  γ=%.3f" % (e_idl, e_atk, gam), flush=True)
        # ── 预览（深底）──
        g = Image.new("RGB", (6 * 136 + 8, 160), (38, 42, 50))
        for i, f in enumerate(frames):
            t = f.resize((128, 128), Image.LANCZOS)
            g.paste(t, (8 + i * 136, 16), t)
        g.save(os.path.join(STG8, "%s_atk_preview.png" % unit))
        g2 = Image.new("RGB", (4 * 136 + 8, 2 * 136 + 8), (38, 42, 50))
        for i in range(8):
            f = po.crop((i * FS, 0, (i + 1) * FS, FS)).resize((128, 128), Image.LANCZOS)
            g2.paste(f, (8 + (i % 4) * 136, 8 + (i // 4) * 136), f)
        g2.save(os.path.join(STG8, "%s_idle_preview.png" % unit))
    print("MK8 收尾批 3 结束", flush=True)


if __name__ == "__main__":
    main()
