#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VFX 审计截图逐格像素分析器（v20.20 自动标定版）
==============================================
对 docs/vfx_audit_shots/*.png 逐格做客观像素测量，输出 pixel_analysis.json。

截图 = 审计台整视口（含参考框/标尺/文字等道具）。测量限制在"特效安全窗口"内，
窗口以**设计坐标**（1280×720 舞台）定义，运行时自动标定截图的实际缩放/偏移：
在 f00_player_muzzle.png 里检测青色参考框线（设计位 (336,366)-(384,430)，48×64），
反推 scale 与 offset——适配任何窗口尺寸（v20.20 修复前视口被压到 1028 宽时
全图 0.8025×，硬编码映射全部失真；修复后为 1.0×，本工具两种情况都兼容）。

用法:
  python tools/vfx_shot_pixel_scan.py             # 全量
  python tools/vfx_shot_pixel_scan.py --only f05  # 只扫文件名含该子串的格
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(TOOLS_DIR)
SHOTS_DIR = os.path.join(PROJECT_ROOT, "docs", "vfx_audit_shots")
OUT_JSON = os.path.join(SHOTS_DIR, "pixel_analysis.json")

# ── 设计坐标（1280×720 舞台，映射自 vfx_audit_matrix.gd）──
# 格型中心：muzzle (360,430) / impact (900,430) / trajectory (630,430)
DESIGN_WINDOWS = {
    "muzzle": (250, 470, 310, 478),
    "impact": (780, 1010, 310, 545),
    "trajectory": (470, 790, 330, 478),
}
DESIGN_CENTERS = {
    "muzzle": (360.0, 430.0),
    "impact": (900.0, 430.0),
    "trajectory": (630.0, 430.0),
}
# 青色参考框（我方单位框）设计位置——自动标定锚点
CALIB_FRAME_DESIGN = (336, 366, 384, 430)  # x0, y0, x1, y1 (48×64)
CALIB_FILE = "f00_player_muzzle.png"


def kind_of(fname: str) -> str:
    for k in DESIGN_WINDOWS:
        if fname.endswith(f"_{k}.png"):
            return k
    return "trajectory"


def calibrate() -> tuple:
    """检测青色参考框实际位置 → (scale, ox, oy)。失败回退 (1.0, 0, 0)。"""
    path = os.path.join(SHOTS_DIR, CALIB_FILE)
    if not os.path.isfile(path):
        return 1.0, 0.0, 0.0
    im = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    cyan = (b > 200) & (g > 150) & (g < 240) & (r < 140)
    ys, xs = np.where(cyan)
    if len(xs) < 50:
        return 1.0, 0.0, 0.0
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    dx0, dy0, dx1, dy1 = CALIB_FRAME_DESIGN
    sx = (x1 - x0) / max(dx1 - dx0, 1)
    sy = (y1 - y0) / max(dy1 - dy0, 1)
    scale = (sx + sy) / 2.0
    if not (0.4 <= scale <= 1.6):
        return 1.0, 0.0, 0.0
    return scale, x0 - dx0 * scale, y0 - dy0 * scale


def connected_components(mask: np.ndarray, max_components: int = 64):
    """8 邻接连通域（2-pass 并查集）。返回按面积降序的 (area, cx, cy) 列表。"""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    parent = [0]

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    nxt = 1
    for y in range(h):
        row = mask[y]
        for x in range(w):
            if not row[x]:
                continue
            up = labels[y - 1, x] if y > 0 else 0
            left = labels[y, x - 1] if x > 0 else 0
            if up == 0 and left == 0:
                labels[y, x] = nxt
                parent.append(nxt)
                nxt += 1
            elif up != 0 and left != 0:
                labels[y, x] = min(up, left)
                union(up, left)
            else:
                labels[y, x] = max(up, left)
    stats: dict = {}
    ys, xs = np.where(mask)
    for y, x in zip(ys.tolist(), xs.tolist()):
        root = find(int(labels[y, x]))
        area, sx, sy = stats.get(root, (0, 0, 0))
        stats[root] = (area + 1, sx + x, sy + y)
    comps = sorted(((a, sx / a, sy / a) for a, sx, sy in stats.values()),
                   key=lambda t: -t[0])
    return comps[:max_components]


def analyze_cell(path: str, scale: float, ox: float, oy: float) -> dict:
    img = Image.open(path).convert("RGB")
    full = np.asarray(img, dtype=np.int16)
    kind = kind_of(os.path.basename(path))
    dx0, dx1, dy0, dy1 = DESIGN_WINDOWS[kind]
    x0 = int(dx0 * scale + ox)
    x1 = int(dx1 * scale + ox)
    y0 = int(dy0 * scale + oy)
    y1 = int(dy1 * scale + oy)
    x1 = min(x1, full.shape[1])
    y1 = min(y1, full.shape[0])
    a = full[y0:y1, x0:x1]
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    v = a.max(axis=2)
    chroma = v - a.min(axis=2)
    h, w = v.shape

    white = (r >= 230) & (g >= 230) & (b >= 230)
    fire = (r >= 180) & (g >= 80) & (b <= 110)
    glow = (v >= 150) & ~white & ~fire
    smoke = (v >= 60) & (v < 150) & (chroma <= 12)
    warm = (r > b + 30) & (v >= 90)
    cool = (b > r + 20) & (v >= 90)

    effect = (v >= 150) | smoke
    # 白热亮核：过曝 + 低色度（排除青 166 / 橙 191 参考框线与彩色单位剪影）
    core = (v >= 235) & (chroma <= 70)

    out: dict = {
        "kind": kind,
        "window": [x0, x1, y0, y1],
        "fire_px": int(fire.sum()),
        "glow_px": int(glow.sum()),
        "smoke_px": int(smoke.sum()),
        "warm": int(warm.sum()),
        "cool": int(cool.sum()),
        "white": int(white.sum()),
        "maxv": int(v.max()),
    }

    def bbox_of(mask: np.ndarray):
        ys, xs = np.where(mask)
        if len(xs) == 0:
            return 0, 0, -1.0, -1.0
        return (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1),
                float(xs.mean()), float(ys.mean()))

    bw, bh, cx, cy = bbox_of(effect)
    cbw, cbh, _, _ = bbox_of(core)
    out["bbox_w"], out["bbox_h"] = bw, bh
    # 尺寸换算回设计坐标（与规格的 64px 参考单位直接对比）
    out["bbox_design_w"] = round(bw / scale, 1) if scale else bw
    out["bbox_design_h"] = round(bh / scale, 1) if scale else bh
    out["core_bbox_w"], out["core_bbox_h"] = cbw, cbh
    out["core_bbox_design_w"] = round(cbw / scale, 1) if scale else cbw
    out["core_bbox_design_h"] = round(cbh / scale, 1) if scale else cbh
    if cx >= 0:
        rx, ry = DESIGN_CENTERS[kind]
        out["centroid_off"] = [round(cx + x0 - (rx * scale + ox), 1),
                               round(cy + y0 - (ry * scale + oy), 1)]
        xs_eff = np.where(effect)[1]
        out["right_frac"] = round(float((xs_eff > w * 0.55).sum()) / max(len(xs_eff), 1), 2)
    else:
        out["centroid_off"] = None
        out["right_frac"] = -1.0

    comps = connected_components(core)
    out["pellet_blobs"] = len([c for c in comps if c[0] >= 4])
    out["blob_areas"] = [c[0] for c in comps[:8]]
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()

    scale, ox, oy = calibrate()
    print(f"[calib] scale={scale:.4f} offset=({ox:.1f},{oy:.1f})")

    results = []
    for fn in sorted(os.listdir(SHOTS_DIR)):
        if not fn.endswith(".png"):
            continue
        if args.only and args.only not in fn:
            continue
        entry = {"file": fn}
        entry.update(analyze_cell(os.path.join(SHOTS_DIR, fn), scale, ox, oy))
        results.append(entry)
        print(f"{fn}: core={entry['core_bbox_w']}x{entry['core_bbox_h']} "
              f"(design {entry['core_bbox_design_w']}x{entry['core_bbox_design_h']}) "
              f"bbox={entry['bbox_w']}x{entry['bbox_h']} fire={entry['fire_px']} "
              f"glow={entry['glow_px']} smoke={entry['smoke_px']} warm={entry['warm']} "
              f"cool={entry['cool']} white={entry['white']} R%={entry['right_frac']} "
              f"blobs={entry['pellet_blobs']}")

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump({"calibration": {"scale": scale, "offset": [ox, oy]},
                   "cells": results}, f, ensure_ascii=False, indent=1)
    print(f"\n[done] {len(results)} cells -> {OUT_JSON}")


if __name__ == "__main__":
    main()
