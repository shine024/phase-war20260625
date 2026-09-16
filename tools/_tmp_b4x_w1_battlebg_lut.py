#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W1 battle_bg 强 LUT 压冷 + 火光光源收敛（2026-09-14 资产合规收尾计划 W1）。

对象：assets/intro/battle_bg.png（审计 C 档——暖橙棕主调 ~50% 触暖黄主调红线
+ 火光光源 5-6 处 + 多主体混杂；批次④台账唯一在册 C 档挂起项）。
处方（收尾计划 W1）：程序化强 LUT 压冷（参照 b2_invasion 的 r>b ×0.62 口径）
+ 火光光源收敛（5-6 处 → 叙事必需 ≤2）→ 复检暖区 ≤15%。

算法（复用 _tmp_b4_lut_cool_b4.py 口径，勿改旧件）：
  1) 全局强压冷：对 r>b 像素按 (r-b)×COOL 收缩，迭代至暖区 ≤15%（≤3 轮）；
  2) 光源收敛：检测亮暖连通簇 → 保留叙事必需 KEEP_SPOTS 两处（半径软边），
     簇内按 KEEP_STRENGTH 混回原图暖色，其余火点保持压冷态；
  3) 前后暖区对照输出。纯调色不改 alpha/几何。
原图备份 _art_backup/battle_bg-preBGCHK-2026-09-14.png。
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "assets", "intro", "battle_bg.png")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"
BACKUP = os.path.join(BACKUP_DIR, "battle_bg-preBGCHK-2026-09-14.png")
PREVIEW = os.path.join(ROOT, ".godot", "agent_tools", "w1_battlebg_after.png")

COOL = 0.62          # 单轮 (r-b) 收缩比例（b2_invasion 口径）
MAX_PASSES = 3       # 迭代压冷轮数上限
WARM_LIMIT = 0.15    # 宪法一章红线
KEEP_SPOTS = [       # 叙事必需保留的火光（x, y, 半径, 强度）——按检出簇核定
    (549, 238, 110, 0.85),   # 中央地平线燃烧楼（最大簇，梦境战轴向主光源）
    (742, 251, 100, 0.80),   # 中右燃烧建筑（次大簇，装甲车后方次光源）
]


def warm_ratio(arr):
    r = arr[..., 0].astype(np.int16)
    g = arr[..., 1]
    b = arr[..., 2].astype(np.int16)
    warm = (r > b + 30) & (r > 90)
    return warm.mean()


def cool_pass(arr, k):
    r = arr[..., 0].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    d = r - b
    m = d > 0
    nr = r.copy()
    nr[m] = b[m] + (d[m].astype(np.float32) * k).astype(np.int16)
    out = arr.copy()
    out[..., 0] = np.clip(nr, 0, 255)
    return out


def detect_clusters(arr, min_pix=120):
    """亮暖像素（r>140 且 r>b+50）下采样连通域，返回 [(cx,cy,area)] 降序。"""
    small = arr[::4, ::4]
    r = small[..., 0].astype(np.int16)
    b = small[..., 2].astype(np.int16)
    m = (r > 140) & (r > b + 50)
    try:
        import cv2
        n, lab, stats, cent = cv2.connectedComponentsWithStats(m.astype(np.uint8), 8)
        out = []
        for i in range(1, n):
            area = int(stats[i, cv2.CC_STAT_AREA])
            if area * 16 < min_pix:
                continue
            cx, cy = cent[i][0] * 4, cent[i][1] * 4
            out.append((round(cx), round(cy), area * 16))
        out.sort(key=lambda t: -t[2])
        return out
    except ImportError:
        return []


def apply_keep_spots(orig, cooled):
    """保留簇：软边圆形 mask 内按强度混回原图。"""
    h, w = cooled.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    out = cooled.copy()
    for (cx, cy, rad, k) in KEEP_SPOTS:
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        fall = np.clip(1.0 - dist / rad, 0.0, 1.0)
        fall = (fall * fall * (3 - 2 * fall))  # smoothstep 软边
        a = (fall * k)[..., None]
        out = (out * (1 - a) + orig.astype(np.float32) * a).astype(np.uint8)
    return out


def main() -> int:
    os.makedirs(BACKUP_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    if not os.path.exists(BACKUP):
        with open(TARGET, "rb") as fi, open(BACKUP, "wb") as fo:
            fo.write(fi.read())
        print("[BACKUP] ->", BACKUP)

    img = Image.open(TARGET).convert("RGB")
    arr = np.asarray(img).copy()
    before = warm_ratio(arr)
    clusters = detect_clusters(arr)
    print("[BEFORE] 暖区 %.1f%%；亮暖簇 %d 处（前 8）："
          % (before * 100, len(clusters)))
    for c in clusters[:8]:
        print("   簇 @(%d,%d) 面积~%dpx" % c)

    # 1) 全局迭代压冷
    passes = 0
    cur = arr
    while passes < MAX_PASSES:
        r0 = warm_ratio(cur)
        if r0 <= WARM_LIMIT:
            break
        cur = cool_pass(cur, COOL)
        passes += 1
        print("[COOL] 第 %d 轮 ×%.2f -> 暖区 %.1f%%" % (passes, COOL, warm_ratio(cur) * 100))

    # 2) 光源收敛：簇内混回（其余保持冷态）
    out = apply_keep_spots(arr, cur)
    after = warm_ratio(out)
    ok = after <= WARM_LIMIT
    print("[AFTER] 暖区 %.1f%%（轮数 %d，保留光源 %d 处）%s"
          % (after * 100, passes, len(KEEP_SPOTS), "OK" if ok else "仍超线"))

    Image.fromarray(out).save(TARGET, "PNG")
    Image.fromarray(out).save(PREVIEW, "PNG")
    print("[SAVED]", TARGET)
    print("[PREVIEW]", PREVIEW)
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
