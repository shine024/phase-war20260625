# -*- coding: utf-8 -*-
"""
批量验证重摄产出：对 docs/重修背景图/ 内每张 bg_level_*.png（排除原图/对比图），
检测单位站立带（y455-660）内是否残留大块高对比结构。

判定：站立带内连通域 bbox 高度 > 55px 且面积 > 3000 → 标记 FLAG。
输出汇总表 + 需人工/视觉复查清单。
用法：python tools/bg_rework/verify_batch.py
"""
import os, glob, sys
import numpy as np
from PIL import Image
from collections import deque

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else "docs/重修背景图"
SKIP = ("_compare", "_fixed", "_ai", "_ai_50m")   # 非本次产物

Y0, Y1 = 455, 660          # 站立带（图内坐标，1280x720 基准）
H_REF = 720                # 参考高度：按实际高度缩放带位置

def blobs_in_band(a):
    """返回站立带内大块高对比连通域列表 (area, x0, y0, x1, y1)。"""
    H, W = a.shape[:2]
    s = int(Y0 * H / H_REF); e = int(Y1 * H / H_REF)
    sub = a[s:e, :, :].astype(np.float32)
    lum = sub.mean(axis=2)
    gx = np.abs(np.diff(lum, axis=1)); gx = np.pad(gx, ((0, 0), (0, 1)))
    gy = np.abs(np.diff(lum, axis=0)); gy = np.pad(gy, ((0, 1), (0, 0)))
    edge = gx + gy
    ground = np.median(sub.reshape(-1, 3), axis=0)
    dist = np.sqrt(((sub - ground[None, None, :]) ** 2).sum(axis=2))
    mask = ((edge > 25) | (dist > max(np.median(dist) * 1.8, 40))).astype(np.uint8)
    # 3x3 膨胀两次连接碎块
    def dilate3(m):
        p = np.pad(m, 1)
        out = np.zeros_like(m)
        for dy in range(3):
            for dx in range(3):
                out |= p[dy:dy + m.shape[0], dx:dx + m.shape[1]]
        return out
    md = dilate3(dilate3(mask))
    lab = np.zeros(md.shape, dtype=np.int32)
    cur = 0
    out = []
    hh, ww = md.shape
    for sy in range(0, hh, 3):
        for sx in range(0, ww, 3):
            if md[sy, sx] and lab[sy, sx] == 0:
                cur += 1
                q = deque([(sy, sx)]); lab[sy, sx] = cur; px = []
                while q:
                    y, x = q.popleft(); px.append((y, x))
                    if len(px) > 60000:
                        break
                    for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
                        if 0 <= ny < hh and 0 <= nx < ww and md[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur; q.append((ny, nx))
                ys = [q0[0] for q0 in px]; xs = [q0[1] for q0 in px]
                area = len(px)
                by0, by1, bx0, bx1 = min(ys), max(ys), min(xs), max(xs)
                bh = (by1 - by0 + 1) * H / H_REF
                if area > 3000 and bh > 55:
                    out.append((area, bx0, by0 + s, bx1, by1 + s, bh))
    return out

files = sorted(f for f in glob.glob(os.path.join(OUT_DIR, "bg_level_*.png"))
               if not any(k in f for k in SKIP))
print("verify %d files in %s" % (len(files), OUT_DIR))
flagged = {}
for f in files:
    a = np.asarray(Image.open(f).convert("RGB"))
    bl = blobs_in_band(a)
    name = os.path.basename(f)
    if bl:
        bl.sort(reverse=True)
        flagged[name] = bl[:3]
        print("FLAG %-20s %d blobs: %s" % (name, len(bl),
              "; ".join("area=%d bbox=(%d,%d,%d,%d) h=%.0f" % b for b in bl[:3])))
    else:
        print("ok   %s" % name)
print("\nsummary: %d/%d flagged" % (len(flagged), len(files)))
if flagged:
    open("tools/bg_rework/_flagged.txt", "w", encoding="utf-8").write("\n".join(flagged))
