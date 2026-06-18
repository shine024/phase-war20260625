#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检查未抠图样本的背景特征，决定抠图策略。"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")
samples = [
    "ww1_ft17.png",      # NO_ALPHA 1024
    "ww1_mp18.png",      # NO_ALPHA 1024
    "cold_t72.png",      # NO_ALPHA 1024
    "mod_m1a2sep.png",   # UNCUT 512
    "mod_technical.png", # UNCUT 512
    "vis_player_013.png",# UNCUT 1024
    "fut_nexus.png",     # UNCUT 512 edge_alpha=0.022
    "energy_start_1.png",# NO_ALPHA 1536x1024
]

for name in samples:
    p = ROOT / name
    if not p.exists():
        # 试 units 子目录
        p = ROOT / "units" / name
    if not p.exists():
        print(f"{name}: NOT FOUND")
        continue
    img = Image.open(p)
    img.load()
    w, h = img.size
    mode = img.mode
    rgb = img.convert("RGB")
    # 采样四角 + 中心背景
    corners = {
        "左上": rgb.getpixel((2, 2)),
        "右上": rgb.getpixel((w - 3, 2)),
        "左下": rgb.getpixel((2, h - 3)),
        "右下": rgb.getpixel((w - 3, h - 3)),
        "中上": rgb.getpixel((w // 2, 2)),
        "中下": rgb.getpixel((w // 2, h - 3)),
    }
    print(f"\n{name}  {w}x{h} mode={mode}")
    for pos, px in corners.items():
        print(f"  {pos}: RGB{px}")
    # 检查四角是否同色（纯色背景判定）
    cvals = list(corners.values())
    same = all(abs(cvals[i][0]-cvals[0][0])<15 and abs(cvals[i][1]-cvals[0][1])<15 and abs(cvals[i][2]-cvals[0][2])<15 for i in range(1,4))
    print(f"  四角近同色(纯色背景): {same}")
