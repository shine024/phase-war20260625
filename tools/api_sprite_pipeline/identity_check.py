# -*- coding: utf-8 -*-
"""主体一致性指纹: 色相直方图+饱和度均值, 与参考 f0 比对。标定/门禁两用。
用法: python identity_check.py  (标定当前 frames/)"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
UNIT = "ww2_arm_garand_para"
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
ANIM = os.path.join(WS, "assets", "effects", "unit_anims", UNIT)

def palette_sig(rgba, name=""):
    """非透明像素: 12bin 色相直方图 + RGB 4³ 立方直方图 + 均值饱和/明度。
    RGB 立方直方图对去饱和灰化敏感（色相直方图测不出）。"""
    a = rgba[:, :, 3].astype(int)
    ys, xs = np.where(a > 60)
    px = rgba[ys, xs, :3].astype(float)
    p = px / 255.0
    mx, mn = p.max(1), p.min(1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = p[:, 0], p[:, 1], p[:, 2]
    hue = np.zeros(len(p))
    m = (mx == r); hue[m] = ((g - b)[m] / np.maximum((mx - mn)[m], 1e-6)) % 6
    m = (mx == g); hue[m] = (b - r)[m] / np.maximum((mx - mn)[m], 1e-6) + 2
    m = (mx == b); hue[m] = (r - g)[m] / np.maximum((mx - mn)[m], 1e-6) + 4
    hue = hue * 60.0
    sel = s > 0.15
    hist, _ = np.histogram(hue[sel], bins=12, range=(0, 360))
    hist = hist / max(1, hist.sum())
    # RGB 4³ = 64bin
    rgb_hist, _ = np.histogramdd(px / 255.0, bins=(4, 4, 4), range=((0, 1),) * 3)
    rgb_hist = rgb_hist.flatten() / max(1, rgb_hist.sum())
    return np.concatenate([hist, rgb_hist, [s[sel].mean() if sel.any() else 0, mx[sel].mean() if sel.any() else 0]])

def dist(sig_a, sig_b):
    return float(np.abs(sig_a - sig_b).sum())

# 参考: idle f0
idle = Image.open(os.path.join(ANIM, "sheet_idle.png")).convert("RGBA")
ref_sig = palette_sig(np.asarray(idle.crop((0, 0, 256, 256))))

if __name__ == "__main__":
    print("参考 f0 指纹基线")
    sigs = {}
    for i in range(1, 7):
        fr = Image.open(os.path.join(OUT, "frames", "f%d.png" % i)).convert("RGBA")
        sigs[i] = palette_sig(np.asarray(fr))
        d = dist(sigs[i], ref_sig)
        print("f%d 与参考指纹距离: %.3f" % (i, d))
    print()
    print("=== 卷内两两距离（>0.5 视为异体嫌疑）===")
    for i in range(1, 7):
        row = []
        for j in range(1, 7):
            d = dist(sigs[i], sigs[j])
            row.append("%.2f" % d)
        print("f%d: %s" % (i, "  ".join(row)))
