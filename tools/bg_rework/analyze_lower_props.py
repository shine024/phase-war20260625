# -*- coding: utf-8 -*-
"""
分析战斗背景图下半部的大体积近景物体（相对单位卡比例失衡的道具）。

输出：
  1. 边缘密度 ASCII 热图（全图概览）
  2. 下半部连通域分析：与地面基色差异显著的大块区域 → 候选道具框
用法：
  python tools/bg_rework/analyze_lower_props.py <image_path> [half=y比例，默认0.5]
"""
import sys
import numpy as np
from PIL import Image
from collections import deque

path = sys.argv[1] if len(sys.argv) > 1 else r"docs/重修背景图/bg_level_07.png"
half_frac = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5

im = Image.open(path).convert("RGB")
a = np.asarray(im).astype(np.float32)
H, W = a.shape[:2]
lum = a.mean(axis=2)
print("image: %s  %dx%d" % (path, W, H))

# ---------- 1) 边缘密度 ASCII 热图 ----------
gx = np.abs(np.diff(lum, axis=1)); gx = np.pad(gx, ((0, 0), (0, 1)))
gy = np.abs(np.diff(lum, axis=0)); gy = np.pad(gy, ((0, 1), (0, 0)))
edge = gx + gy

cols, rows = 64, 36
cw, ch = W / cols, H / rows
chars = " .:-=+*#%@"
print("\nEDGE DENSITY MAP (chars ' .:-=+*#%%@' low->high), cell=%.0fpx" % ch)
hdr = []
for c in range(cols):
    hdr.append(str(int(c * cw / 100) % 10) if (c * cw) % 100 < cw else " ")
print("     " + "".join(hdr))
for r in range(rows):
    line = []
    for c in range(cols):
        blk = edge[int(r * ch):int((r + 1) * ch), int(c * cw):int((c + 1) * cw)]
        v = blk.mean()
        line.append(chars[min(int(v / 4), 9)])
    print("%4d %s" % (int(r * ch), "".join(line)))

# ---------- 2) 下半部“异物”连通域 ----------
y0 = int(H * half_frac)
sub = a[y0:, :, :]
sub_lum = lum[y0:, :]

# 地面基色：下半部的逐行中位数（取下半部最底部 1/3 的中位色更接近“空地”）
ground_ref = np.median(a[int(H * 0.75):, :, :].reshape(-1, 3), axis=0)
print("\nground reference color (median of bottom quarter):", ground_ref.round(1))

# 与基色的距离图 + 边缘强度，联合判定“非地面”
dist = np.sqrt(((sub - ground_ref[None, None, :]) ** 2).sum(axis=2))
edge_sub = edge[y0:, :]
d_med = np.median(dist)
d_mask = dist > max(d_med * 1.8, 40)          # 颜色显著偏离
e_mask = edge_sub > 25                          # 局部结构丰富
mask = (d_mask | e_mask).astype(np.uint8)

# 形态学膨胀 3 次把碎块连起来（纯 numpy）
def dilate(m, k=3):
    p = k // 2
    pad = np.pad(m, p)
    out = np.zeros_like(m)
    for dy in range(k):
        for dx in range(k):
            out = np.maximum(out, pad[dy:dy + m.shape[0], dx:dx + m.shape[1]])
    return out

md = dilate(mask, 5)

# 连通域（BFS，4 邻域）
lab = np.zeros(md.shape, dtype=np.int32)
cur = 0
comps = []
hh, ww = md.shape
for sy in range(0, hh, 2):          # 稀疏扫描种子加速
    for sx in range(0, ww, 2):
        if md[sy, sx] and lab[sy, sx] == 0:
            cur += 1
            q = deque([(sy, sx)])
            lab[sy, sx] = cur
            px = []
            while q:
                y, x = q.popleft()
                px.append((y, x))
                for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
                    if 0 <= ny < hh and 0 <= nx < ww and md[ny, nx] and lab[ny, nx] == 0:
                        lab[ny, nx] = cur
                        q.append((ny, nx))
            ys = [p[0] for p in px]; xs = [p[1] for p in px]
            area = len(px)
            by0, by1, bx0, bx1 = min(ys), max(ys), min(xs), max(xs)
            bw, bh = bx1 - bx0 + 1, by1 - by0 + 1
            fill = area / float(bw * bh)
            comps.append((area, bx0, by0 + y0, bx1, by1 + y0, bw, bh, fill))

comps.sort(reverse=True)
print("\nTOP candidate blobs in lower half (area>3000px):")
print("  area    bbox(x0,y0,x1,y1)      w    h   fill")
for area, x0, yy0, x1, yy1, bw, bh, fill in comps[:15]:
    if area < 3000:
        break
    print("%6d  (%4d,%4d,%4d,%4d)  %4d %4d  %.2f" % (area, x0, yy0, x1, yy1, bw, bh, fill))
