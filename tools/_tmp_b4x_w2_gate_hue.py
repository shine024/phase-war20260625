#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W2 b2_invasion 门色校正——门体橙光 → 黑门紫语义（2026-09-14 收尾计划 W2）。

来源：审计 §序章漫画 b2_invasion B 档遗留——"门体橙光而非黑门紫语义"；
批次④ §6 明示"门色校正按处方留重生成时做"。本脚本走处方 a) 局部色相旋转
（参照批次④ nova/eon 族色漂校正的色相旋转法，橙→紫），不达标再走 b) FLOW 重生成。

做法：
  1) 门体掩码：上半幅（y<310）亮暖像素（H 8-70 / S>0.22 / V>0.28）取最大连通域
     （即天幕裂缝门体），bbox 外扩 + 高斯羽化；
  2) 目标色相：对照合规样板 b6_black_gates 实测紫（圆形均值 274°）；
  3) 掩码内逐像素 H += (target - 门体橙均值)，V/S 保持（亮度结构不动）；
  4) 全图叙事火焰（下半幅燃烧楼）不在掩码内，语义保留。
原图备份 _art_backup/b2_invasion-preW2-2026-09-14.png。
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMIC = os.path.join(ROOT, "assets", "intro", "comic")
TARGET = os.path.join(COMIC, "b2_invasion.png")
REF = os.path.join(COMIC, "b6_black_gates.png")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"
BACKUP = os.path.join(BACKUP_DIR, "b2_invasion-preW2-2026-09-14.png")
PREVIEW = os.path.join(ROOT, ".godot", "agent_tools", "w2_gate_after.png")

Y_GATE = 310          # 门体只在上半幅找（下半幅燃烧楼属火焰语义）
TARGET_HUE = 274.0    # b6_black_gates 实测紫均值（脚本头注释口径）


def rgb_to_hsv(arr):
    im = arr.astype(np.float32) / 255.0
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mx = im.max(-1)
    mn = im.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    h = np.zeros_like(mx)
    m = (mx == r) & (d > 0)
    h[m] = ((g - b)[m] / d[m]) % 6
    m = (mx == g) & (d > 0)
    h[m] = (b - r)[m] / d[m] + 2
    m = (mx == b) & (d > 0)
    h[m] = (r - g)[m] / d[m] + 4
    return h * 60.0, s, mx


def hsv_to_rgb(h, s, v):
    h = (h % 360.0) / 60.0
    i = np.floor(h).astype(np.int32) % 6
    f = h - np.floor(h)
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return (np.stack([r, g, b], -1) * 255.0).round().astype(np.uint8)


def largest_component(mask):
    """8 邻接最大连通域（门体裂缝网络）。"""
    try:
        import cv2
        n, lab, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
        if n <= 1:
            return mask
        big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        return lab == big
    except ImportError:
        return mask


def main() -> int:
    os.makedirs(BACKUP_DIR, exist_ok=True)
    if not os.path.exists(BACKUP):
        with open(TARGET, "rb") as fi, open(BACKUP, "wb") as fo:
            fo.write(fi.read())
        print("[BACKUP] ->", BACKUP)

    img = Image.open(TARGET).convert("RGB")
    arr = np.asarray(img).copy()
    h, s, v = rgb_to_hsv(arr)

    # 1) 门体掩码
    zone = np.zeros(h.shape, bool)
    zone[:Y_GATE, :] = True
    warm = (h >= 8) & (h <= 70) & (s > 0.22) & (v > 0.28) & zone
    gate = largest_component(warm)
    ys, xs = np.nonzero(gate)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    mean_orange = float(np.degrees(np.angle(
        np.mean(np.exp(1j * np.radians(h[gate])))) % (2 * np.pi)))
    print("[GATE] bbox x[%d,%d] y[%d,%d] px=%d 橙均值 H=%.1f°"
          % (x0, x1, y0, y1, gate.sum(), mean_orange))

    # bbox 外扩 18px + 羽化，把门光晕染云一并纳入
    grow = 18
    box = np.zeros_like(gate)
    box[max(0, y0 - grow):min(arr.shape[0], y1 + grow),
        max(0, x0 - grow):min(arr.shape[1], x1 + grow)] = True
    sel = (warm | gate) & box
    mask_img = Image.fromarray((sel * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(3.0))
    alpha = np.asarray(mask_img).astype(np.float32) / 255.0

    # 2/3) 色相旋转（V/S 保持）
    delta = (TARGET_HUE - mean_orange) % 360.0
    h2 = (h + delta) % 360.0
    conv = hsv_to_rgb(h2, s, v)
    a3 = alpha[..., None]
    out = (arr.astype(np.float32) * (1 - a3) + conv.astype(np.float32) * a3
           ).round().astype(np.uint8)

    # 4) 复检：门区均值色相 + 全图暖区（b4 口径）对照
    h3, s3, v3 = rgb_to_hsv(out)
    band = gate | ((sel) & (s3 > 0.22) & (v3 > 0.28))
    gate_mean = float(np.degrees(np.angle(
        np.mean(np.exp(1j * np.radians(h3[band])))) % (2 * np.pi)))
    r_ = out[..., 0].astype(np.int16)
    b_ = out[..., 2].astype(np.int16)
    warm_after = ((r_ > b_ + 30) & (r_ > 90)).mean()
    print("[AFTER] 门区色相均值 H=%.1f°（目标带 ~250-285°）；全图暖区 %.1f%%（改前 %.1f%%）"
          % (gate_mean, warm_after * 100,
             ((arr[..., 0].astype(np.int16) > arr[..., 2].astype(np.int16) + 30)
              & (arr[..., 0] > 90)).mean() * 100))

    Image.fromarray(out).save(TARGET, "PNG")
    Image.fromarray(out).save(PREVIEW, "PNG")
    print("[SAVED]", TARGET)
    return 0 if 245 <= gate_mean <= 292 else 2


if __name__ == "__main__":
    sys.exit(main())
