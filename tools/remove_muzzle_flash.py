#!/usr/bin/env python3
"""从 docs\重修改卡图\ 的4张士兵卡图里抠掉枪口火光（暖色高饱和高亮区域）。

思路：
  1. HSV 检测火光特征（橙黄 hue + 高饱和 + 高亮度），外加白热核心（暖色调+极亮）
  2. 膨胀 mask 吃掉柔光晕
  3. 邻域扩散填充（无 cv2，纯 numpy 迭代式 inpaint）
  4. 覆盖保存原文件，原图备份到 _backup火光抠前/

蓝青色能量（相位刃/电磁弧/雷电弧）hue 不在暖色区间，不受影响。
用法: python tools/remove_muzzle_flash.py   （只处理下列4张士兵图）
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "docs", "重修改卡图")
BACKUP = os.path.join(DIR, "_backup火光抠前")
FILES = ["drop_smg_mk2.png", "drop_phase_lance.png",
         "drop_thunder_field.png", "drop_railgun.png", "fut_swarm.png"]


def dilate3(mask, iterations):
    """3x3 膨胀（边缘填充避免环绕）。"""
    m = mask.copy()
    for _ in range(iterations):
        pad = np.pad(m, 1, mode="edge")
        acc = m.copy()
        for dy in (0, 1, 2):
            for dx in (0, 1, 2):
                acc = np.logical_or(acc, pad[dy:dy + m.shape[0], dx:dx + m.shape[1]])
        m = acc
    return m


def inpaint_diffuse(rgb, mask, max_iter=600):
    """迭代扩散填充：每轮用已知邻域均值填充 mask 边界像素。"""
    h, w = mask.shape
    out = rgb.astype(np.float64).copy()
    to_fill = mask.copy()
    for _ in range(max_iter):
        if not to_fill.any():
            break
        filled = ~to_fill
        valsum = np.zeros((h, w, 3))
        cnt = np.zeros((h, w))
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sf = np.zeros((h, w), bool)
            sv = np.zeros((h, w, 3))
            ys = slice(max(0, -dy), h - max(0, dy))
            yd = slice(max(0, dy), h - max(0, -dy))
            xs = slice(max(0, -dx), w - max(0, dx))
            xd = slice(max(0, dx), w - max(0, -dx))
            sf[yd, xd] = filled[ys, xs]
            sv[yd, xd] = out[ys, xs]
            valsum += sv * sf[..., None]
            cnt += sf
        boundary = to_fill & (cnt > 0)
        if not boundary.any():
            break
        out[boundary] = valsum[boundary] / cnt[boundary, None]
        to_fill &= ~boundary
    return out


def remove_flash(path):
    img = Image.open(path).convert("RGB")
    rgb = np.array(img, dtype=np.int16)
    hsv = np.array(img.convert("HSV"), dtype=np.int16)
    H, S, V = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]

    # 主火光：橙黄 hue（PIL H: 15~62 ≈ 21°~87°）+ 高饱和 + 高亮度
    flash = (H >= 15) & (H <= 62) & (S >= 110) & (V >= 140)
    # 白热核心：暖色调 + 极亮
    core = ((r - b) >= 60) & (V >= 225) & (S >= 30)
    mask = flash | core
    n_strong = int(mask.sum())

    mask = dilate3(mask, 4)  # 吃掉柔光晕
    # 柔和外晕一层（低饱和暖调），只扩 2 像素
    halo = (H >= 12) & (H <= 65) & (S >= 55) & (S < 110) & (V >= 150)
    mask = np.logical_or(mask, dilate3(halo, 2))
    # 合并后统一再膨胀 2，保证过渡自然
    mask = dilate3(mask, 2)

    if n_strong == 0:
        print(f"  [skip] 未检测到火光像素")
        return False

    out = inpaint_diffuse(rgb.astype(np.float64), mask)
    out = np.clip(out, 0, 255).astype(np.uint8)
    Image.fromarray(out).save(path)
    pct = mask.sum() / mask.size * 100
    print(f"  火光核心 {n_strong}px → 连光晕共修补 {int(mask.sum())}px ({pct:.2f}% 画面)")
    return True


def main():
    only = set(sys.argv[1:])
    os.makedirs(BACKUP, exist_ok=True)
    for name in FILES:
        if only and name[:-4] not in only:
            continue
        path = os.path.join(DIR, name)
        if not os.path.exists(path):
            print(f"[{name}] 不存在，跳过")
            continue
        bkp = os.path.join(BACKUP, name)
        if not os.path.exists(bkp):
            Image.open(path).save(bkp)
        print(f"[{name}]")
        remove_flash(path)
    print(f"\n原图备份: {BACKUP}")


if __name__ == "__main__":
    main()
