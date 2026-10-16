# -*- coding: utf-8 -*-
"""四拍卷脚部基线对齐(2026-10-16):底缘(主体掩膜 99 分位 y)对齐四拍最低者。

原则:
- 极差>120px 的卷跳过(疑烟火污染底缘或真违规拍,报 suspicious 人工看)
- |dy|<=6px 跳过(抖动阈)
- 平移=整拍垂直移+品红角均值填充(同 068 手工先例)
- 改动拍记录 -> 重拼受影响卷(本地 PIL)

用法:python -I -u tools/_tmp_foot_align_20261016.py
"""
import glob
import os

import numpy as np
from PIL import Image

RAW = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "docs", "卡图API重生成_20261014", "raw")
POSES = os.path.join(RAW, "poses")
BEATS = ["TL", "TR", "BL", "BR"]
JUMP, QUIET = 120, 6


def foot_of(img):
    c = np.concatenate([img[:12, :12].reshape(-1, 3), img[:12, -12:].reshape(-1, 3),
                        img[-12:, :12].reshape(-1, 3), img[-12:, -12:].reshape(-1, 3)])
    bg = c.mean(axis=0)
    dc = np.sqrt(((img - bg) ** 2).sum(-1))
    m = dc > 40
    if m.sum() < 500:
        return None, bg
    ys, _ = np.where(m)
    return float(ys[ys >= np.percentile(ys, 99)].mean()), bg


def shift(img, dy, bg):
    out = np.empty_like(img)
    if dy > 0:
        out[dy:] = img[:img.shape[0] - dy]
        out[:dy] = bg
    else:
        d = -dy
        out[:img.shape[0] - d] = img[d:]
        out[img.shape[0] - d:] = bg
    return out


vols = sorted(glob.glob(os.path.join(RAW, "*_开火4格.png")))
touched = {}
for vp in vols:
    stem = os.path.basename(vp)[:-len("_开火4格.png")]
    if not all(os.path.exists(os.path.join(POSES, "%s_%s.png" % (stem, b))) for b in BEATS):
        print("%s 拍不全(用户侧卷),跳过" % stem, flush=True)
        continue
    imgs, feet = {}, {}
    bad = False
    for b in BEATS:
        p = os.path.join(POSES, "%s_%s.png" % (stem, b))
        img = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
        f, bg = foot_of(img)
        if f is None:
            bad = True
            break
        imgs[b] = (img, bg)
        feet[b] = f
    if bad:
        print("%s 掩膜空,跳过" % stem, flush=True)
        continue
    med = float(np.median(list(feet.values())))
    if max(feet.values()) - min(feet.values()) > JUMP:
        print("%s suspicious 极差 %.0fpx,跳过待人工" % (stem, max(feet.values()) - min(feet.values())),
              flush=True)
        continue
    base = max(feet.values())
    moved = False
    for b in BEATS:
        dy = int(round(base - feet[b]))
        if abs(dy) <= QUIET:
            continue
        img, bg = imgs[b]
        out = shift(img, dy, bg)
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(
            os.path.join(POSES, "%s_%s.png" % (stem, b)))
        touched.setdefault(stem, []).append((b, dy))
        moved = True
        print("%s %s shift %+d" % (stem, b, dy), flush=True)
    if not moved:
        print("%s 已齐(<=6px)" % stem, flush=True)

print("\n-- 重拼 %d 卷 --" % len(touched), flush=True)
for stem, moves in touched.items():
    panels = [Image.open(os.path.join(POSES, "%s_%s.png" % (stem, b))).convert("RGB") for b in BEATS]
    grid = Image.new("RGB", (2048, 2048), (255, 0, 255))
    for p, (cx, cy) in zip(panels, ((0, 0), (1024, 0), (0, 1024), (1024, 1024))):
        grid.paste(p.resize((1024, 1024), Image.LANCZOS), (cx, cy))
    grid.save(os.path.join(RAW, stem + "_开火4格.png"))
    print("拼 %s %s" % (stem, moves), flush=True)
