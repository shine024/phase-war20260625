#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检查已抠图样本，确认目标效果。并检查能量卡主体内容。"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")

# 已抠图样本
cut_samples = [
    "carrier.png", "guard.png", "hound.png", "medic.png", "omega_platform.png",
    "raider.png", "scout.png", "siege.png", "stealth.png", "titan.png",
    "radar.png",
]
print("=== 已抠图样本 ===")
for name in cut_samples:
    p = ROOT / name
    if not p.exists():
        continue
    img = Image.open(p)
    print(f"{name}: {img.size} mode={img.mode}")

# 能量卡内容采样（黑背景，需确认主体是否在中心）
print("\n=== 能量卡主体位置采样 ===")
for name in ["energy_start_1.png", "energy_start_2.png"]:
    p = ROOT / name
    if not p.exists():
        continue
    img = Image.open(p).convert("RGB")
    w, h = img.size
    # 中心区域采样
    cx, cy = w // 2, h // 2
    print(f"{name} {w}x{h}:")
    print(f"  中心: {img.getpixel((cx, cy))}")
    print(f"  中心偏移(±50): {img.getpixel((cx-50,cy))} {img.getpixel((cx+50,cy))} {img.getpixel((cx,cy-50))} {img.getpixel((cx,cy+50))}")
    # 主体范围探测：从中心向外扫描找主体边界
    # 水平方向找最远的非黑像素
    left = right = cx
    for x in range(cx, 0, -1):
        r,g,b = img.getpixel((x, cy))
        if r+g+b > 30:  # 非黑
            left = x
            break
    for x in range(cx, w):
        r,g,b = img.getpixel((x, cy))
        if r+g+b > 30:
            right = x
            break
    print(f"  水平主体范围: x={left}~{right} (中心行)")

# vis_player_054 浅灰背景主体
print("\n=== vis_player_054 (浅灰背景) ===")
p = ROOT / "vis_player_054.png"
if p.exists():
    img = Image.open(p).convert("RGB")
    w, h = img.size
    cx, cy = w//2, h//2
    print(f"{w}x{h} 中心: {img.getpixel((cx,cy))}")
    print(f"  四分之一处: {img.getpixel((cx//2, cy))} {img.getpixel((cx+cx//2, cy))}")
