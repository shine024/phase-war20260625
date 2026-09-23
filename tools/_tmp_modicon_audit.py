# -*- coding: utf-8 -*-
"""_tmp_modicon_audit.py —— 改造图标机器审计标准（v37.2，用户拍板：自动跑分选优，人不逐张看）

六项可测标准（阈值经 8 张样张校准）：
  R1 内容占比   bbox_ratio   主体 bbox 面积/画布，目标 0.30~0.85（过小=抠缩丢细节，过大=顶边裁切）
  R2 居中偏差   center_off   bbox 中心距画布中心/半边长，<0.20
  R3 双主体     comp2_ratio  次大连通域/最大连通域（128px 阈值掩码），<0.55（纹章框+主体≈0.3-0.5 合法）
  R4 左右对称   sym_rmse     内容 bbox 内灰度 vs 镜像 RMSE（0-255），仅对称徽章类要求 <34
  R5 族色相     hue_err      高饱和像素环形均色相 vs 族目标色相，±40° 内（族色编码验证）
  R6 26px 存活  c26          缩到 26px 后内容区亮度 p95-p5 对比度，≥55（剪影仍从底里立出来）
用法：python tools/_tmp_modicon_audit.py <img1> <img2> ...   （sym/hue 需要 --sym --hue 187 传目标）
"""
import math
import os
import sys
from PIL import Image

NORM = 128


def _grid(img, size=NORM):
    g = img.convert("L").resize((size, size), Image.LANCZOS)
    return [[g.getpixel((x, y)) for x in range(size)] for y in range(size)]


def _bg_level(grid):
    # 背景亮度估计：四角 16px 中位（徽章深底/剪影纯底都适用）
    s = sorted(grid[y][x] for y in list(range(16)) + list(range(NORM - 16, NORM))
               for x in list(range(16)) + list(range(NORM - 16, NORM)))
    return s[len(s) // 2]


def _mask(grid, bg):
    thr = 22
    return [[1 if abs(grid[y][x] - bg) > thr else 0 for x in range(NORM)] for y in range(NORM)]


def bbox_ratio_center(mask):
    xs = [x for y in range(NORM) for x in range(NORM) if mask[y][x]]
    ys = [y for y in range(NORM) for x in range(NORM) if mask[y][x]]
    if not xs:
        return 0.0, 1.0, 0.0
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    area = len(xs) / float(NORM * NORM)
    extent = max(x1 - x0 + 1, y1 - y0 + 1) / float(NORM)
    off = math.hypot((x0 + x1) / 2 - NORM / 2, (y0 + y1) / 2 - NORM / 2) / (NORM / 2)
    return area, off, extent


def components(mask):
    seen = [[False] * NORM for _ in range(NORM)]
    sizes = []
    for y in range(NORM):
        for x in range(NORM):
            if mask[y][x] and not seen[y][x]:
                stack, n = [(x, y)], 0
                seen[y][x] = True
                while stack:
                    cx, cy = stack.pop()
                    n += 1
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < NORM and 0 <= ny < NORM and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
                sizes.append(n)
    sizes.sort(reverse=True)
    return sizes


def sym_rmse(img):
    g = img.convert("L").resize((NORM, NORM), Image.LANCZOS)
    px = g.load()
    tot, n = 0.0, 0
    for y in range(NORM):
        for x in range(NORM):
            d = px[x, y] - px[NORM - 1 - x, y]
            tot += d * d
            n += 1
    return math.sqrt(tot / n)


def hue_err(img, target_deg):
    hsv = img.convert("HSV").resize((96, 96), Image.LANCZOS)
    sx = sy = 0.0
    for y in range(96):
        for x in range(96):
            h, s, v = hsv.getpixel((x, y))
            if s > 90 and v > 90:  # 只统计有彩度的像素
                a = math.radians(h * 360.0 / 255.0)
                sx += math.cos(a)
                sy += math.sin(a)
    if sx * sx + sy * sy < 1e-6:
        return 180.0
    mean = math.degrees(math.atan2(sy, sx)) % 360
    d = abs(mean - target_deg) % 360
    return min(d, 360 - d)


def c26_contrast(img):
    g = img.convert("L").resize((26, 26), Image.LANCZOS)
    vals = sorted(g.getpixel((x, y)) for y in range(26) for x in range(26))
    return vals[int(len(vals) * 0.95)] - vals[int(len(vals) * 0.05)]


def audit(path, sym=False, hue=None):
    img = Image.open(path).convert("RGB")
    grid = _grid(img)
    bg = _bg_level(grid)
    mask = _mask(grid, bg)
    ratio, off, extent = bbox_ratio_center(mask)
    sizes = components(mask)
    comp2 = (sizes[1] / sizes[0]) if len(sizes) > 1 and sizes[0] > 0 else 0.0
    res = {"extent": round(extent, 2), "area": round(ratio, 2), "center_off": round(off, 2),
           "comp2_ratio": round(comp2, 2), "c26": int(c26_contrast(img))}
    fails = []
    # R1：主体最长边占画布 0.55~0.98（细长主体用 extent 而非面积）；面积仅防碎片/满噪
    if not (0.55 <= extent <= 0.98):
        fails.append("R1占比")
    if not (0.04 <= ratio <= 0.90):
        fails.append("R1面积")
    if off > 0.20:
        fails.append("R2居中")
    if comp2 > 0.55:
        fails.append("R3双主体")
    if sym:
        s = sym_rmse(img)
        res["sym_rmse"] = int(s)
        if s > 34:
            fails.append("R4对称")
    if hue is not None:
        h = hue_err(img, hue)
        res["hue_err"] = int(h)
        if h > 40:
            fails.append("R5族色")
    if res["c26"] < 55:
        fails.append("R6小图")
    res["fails"] = fails
    res["pass"] = not fails
    return res


if __name__ == "__main__":
    args = sys.argv[1:]
    sym = "--sym" in args
    hue = None
    if "--hue" in args:
        hue = float(args[args.index("--hue") + 1])
        args = [a for a in args if a not in ("--sym", "--hue", hue and str(int(hue)))]
    args = [a for a in args if not a.startswith("--") and not a.replace(".", "").isdigit()]
    for p in args:
        if not os.path.exists(p):
            print("MISS " + p)
            continue
        r = audit(p, sym=sym, hue=hue)
        print(("PASS " if r["pass"] else "FAIL ") + os.path.basename(p) + "  " +
              " ".join("%s=%s" % kv for kv in r.items() if kv[0] not in ("fails", "pass")) +
              ("  -> " + ",".join(r["fails"]) if r["fails"] else ""))
