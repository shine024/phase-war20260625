# -*- coding: utf-8 -*-
"""fam44 std 单张体检（2026-10-07 两段式·阶段1 门禁）
检查：品红背景占比 / 游离残渣（连通域）/ 主体 bbox 四向边距。
--clean：把远离主体的残渣整框抹成背景品红（先备份 .bak）。
用法: python tools/_fam44_std_check.py <img> [<img>...] [--clean]
"""
import sys
import os
import shutil
from collections import deque
from PIL import Image

DS = 512  # 分析分辨率


def bg_dist(px):
    r, g, b = px[:3]
    return r + b - 2 * g  # 品红≈+510，主体灰/橙≈<=几十


def analyze(path, clean=False):
    im = Image.open(path).convert("RGB")
    W, H = im.size
    small = im.resize((DS, DS))
    pset = small.load()
    mask = [[bg_dist(pset[x, y]) < 150 for x in range(DS)] for y in range(DS)]  # True=内容
    seen = [[False] * DS for _ in range(DS)]
    comps = []
    for y in range(DS):
        for x in range(DS):
            if mask[y][x] and not seen[y][x]:
                q = deque([(x, y)])
                seen[y][x] = True
                pts = []
                while q:
                    cx, cy = q.popleft()
                    pts.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < DS and 0 <= ny < DS and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
                comps.append(pts)
    comps.sort(key=len, reverse=True)
    big = comps[0]
    xs = [p[0] for p in big]
    ys = [p[1] for p in big]
    mb = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)  # 512 坐标
    k = W / float(DS)
    mL, mR, mT, mB = mb[0] * k, W - mb[2] * k, mb[1] * k, H - mb[3] * k
    bgfrac = 1.0 - sum(len(c) for c in comps) / DS / DS
    debris = [c for c in comps[1:] if len(c) >= 12]
    print("%s  bg=%.1f%%  连通域=%d(残渣%d)  边距 左%.0f/右%.0f/上%.0f/下%.0f (%.1f%%/%.1f%%/%.1f%%/%.1f%%)" % (
        os.path.basename(path), bgfrac * 100, len(comps), len(debris), mL, mR, mT, mB,
        mL / W * 100, mR / W * 100, mT / H * 100, mB / H * 100), flush=True)
    for c in debris:
        cx = [p[0] for p in c]
        cy = [p[1] for p in c]
        print("   残渣 area=%d bbox512=(%d,%d,%d,%d)" % (
            len(c), min(cx), min(cy), max(cx) + 1, max(cy) + 1), flush=True)
    if clean and debris:
        keep = (mb[0] - 16, mb[1] - 16, mb[2] + 16, mb[3] + 16)  # 主体膨胀16(512系)保护
        bg = im.getpixel((3, 3))
        px = im.load()
        n = 0
        for c in debris:
            cx = [p[0] for p in c]
            cy = [p[1] for p in c]
            rb = (int(min(cx) * k), int(min(cy) * k), int((max(cx) + 1) * k), int((max(cy) + 1) * k))
            if rb[0] >= keep[0] and rb[2] <= keep[2] and rb[1] >= keep[1] and rb[3] <= keep[3]:
                for yy in range(max(0, rb[1]), min(H, rb[3])):
                    for xx in range(max(0, rb[0]), min(W, rb[2])):
                        px[xx, yy] = bg
                n += 1
        if n:
            bak = path + ".bak"
            if not os.path.exists(bak):
                shutil.copy2(path, bak)
            im.save(path)
            print("   已抹掉 %d 处残渣 (备份 %s)" % (n, os.path.basename(bak)), flush=True)
    return len(debris)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    files = [a for a in sys.argv[1:] if not a.startswith("--")]
    do_clean = "--clean" in sys.argv
    for p in files:
        analyze(p, do_clean)
