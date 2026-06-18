#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""精确探测各背景类型主体的边界框，确保抠图不会误删主体。
策略：对每张图，从四边向内扫描，找到第一个"明显偏离背景色"的像素，确定主体 bbox。"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")

def bg_color(img_rgb, w, h):
    """取四角平均作为背景色。"""
    corners = [
        img_rgb.getpixel((2, 2)),
        img_rgb.getpixel((w-3, 2)),
        img_rgb.getpixel((2, h-3)),
        img_rgb.getpixel((w-3, h-3)),
    ]
    return tuple(sum(c[i] for c in corners)//4 for i in range(3))

def color_dist(a, b):
    return abs(a[0]-b[0]) + abs(a[1]-b[1]) + abs(a[2]-b[2])

def find_bbox(img_rgb, bg, thresh=40, step=2):
    """从四边扫描找主体边界框。返回 (left, top, right, bottom)。"""
    w, h = img_rgb.size
    px = img_rgb.load()
    left, top, right, bottom = w, h, 0, 0
    # 采样：每隔 step 像素扫一行/列
    for y in range(0, h, step):
        for x in range(0, w, step):
            if color_dist(px[x, y], bg) > thresh:
                if x < left: left = x
                if x > right: right = x
                if y < top: top = y
                if y > bottom: bottom = y
    if right < left or bottom < top:
        return None  # 全是背景
    return (left, top, min(right+1, w), min(bottom+1, h))

samples = {
    "白底": ["ww1_ft17.png", "ww2_tiger.png", "cold_t72.png", "fut_swarm.png", "mod_marine.png"],
    "绿幕": ["mod_m1a2sep.png", "mod_technical.png", "fut_nexus.png"],
    "浅灰": ["vis_player_013.png", "vis_player_054.png"],
    "黑底能量卡": ["energy_start_1.png", "energy_start_2.png", "energy_start_3.png"],
}

for category, names in samples.items():
    print(f"\n=== {category} ===")
    for name in names:
        p = ROOT / name
        if not p.exists():
            p = ROOT / "units" / name
        if not p.exists():
            print(f"  {name}: NOT FOUND")
            continue
        img = Image.open(p).convert("RGB")
        w, h = img.size
        bg = bg_color(img, w, h)
        bbox = find_bbox(img, bg, thresh=40, step=2)
        if bbox:
            bw, bh = bbox[2]-bbox[0], bbox[3]-bbox[1]
            margin_l, margin_t = bbox[0], bbox[1]
            margin_r, margin_b = w-bbox[2], h-bbox[3]
            print(f"  {name} {w}x{h} bg=RGB{bg}")
            print(f"    bbox=({bbox[0]},{bbox[1]})~({bbox[2]},{bbox[3]}) 主体 {bw}x{bh}")
            print(f"    边距 上{margin_t} 下{margin_b} 左{margin_l} 右{margin_r}")
            # 主体占图比例
            print(f"    主体占比 {bw*100//w}%x{bh*100//h}%")
        else:
            print(f"  {name} {w}x{h} bg=RGB{bg} -> 未检测到主体(全背景?)")
