#!/usr/bin/env python3
"""B5b（2026-09-14）：新弹坑暖区压冷——重生成件 19.0% 超宪法 15% 红线（旧件 12.5%）。
用 W4-2b v2 配方的分级强度（r 超蓝量 ×f，g 同压防绿偏），取"达标的最小冷却"因子。
"""
import numpy as np
from PIL import Image

P = r"F:/godot fair duet/create/phase-war/assets/battle/decals/ground_decal_crater.png"


def warm(arr):
    r, g, b, al = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    return float(((r > b + 30) & (r > 90) & (al > 60)).mean()) * 100


def main():
    im = np.array(Image.open(P).convert("RGBA")).astype(np.float64)
    print("before %.1f%%" % warm(im))
    for f, gf in [(0.70, 0.90), (0.55, 0.85), (0.45, 0.82), (0.35, 0.78)]:
        t = im.copy()
        r, g, b = t[..., 0], t[..., 1], t[..., 2]
        r2 = b + (r - b) * f
        g2 = np.minimum(b + (g - b) * gf, r2 - 2)
        t[..., 0], t[..., 1] = r2, g2
        w = warm(t)
        print("factor %.2f -> %.1f%%" % (f, w))
        if w <= 14.5:
            Image.fromarray(np.clip(t, 0, 255).astype(np.uint8), "RGBA").save(P)
            print("saved with factor %.2f" % f)
            return
    print("STILL OVER — 需人工复核")


if __name__ == "__main__":
    main()
