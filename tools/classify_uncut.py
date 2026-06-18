#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""精确分类：哪些根目录专属卡面是白底未抠图（真正需要处理的）。
排除：能量卡、绿幕卡、已抠图的通用图(guard/scout等)、units子目录的副本。"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")
UNITS = ROOT / "units"

def is_white_bg(img_rgb, w, h, thresh=240):
    """四角平均是否接近纯白。"""
    corners = [img_rgb.getpixel((2,2)), img_rgb.getpixel((w-3,2)),
               img_rgb.getpixel((2,h-3)), img_rgb.getpixel((w-3,h-3))]
    return all(sum(abs(c[i]-255) for i in range(3)) < (255-thresh)*3 for c in corners)

def is_green_screen(img_rgb, w, h):
    """四角是否绿幕(g占主导且r,b低)。"""
    corners = [img_rgb.getpixel((2,2)), img_rgb.getpixel((w-3,2)),
               img_rgb.getpixel((2,h-3)), img_rgb.getpixel((w-3,h-3))]
    green_count = 0
    for c in corners:
        r,g,b = c
        if g > 100 and g > r + 40 and g > b + 40:
            green_count += 1
    return green_count >= 3

def has_transparent_corners(img):
    """RGBA 且四角透明 = 已抠图。"""
    if img.mode != "RGBA":
        return False
    alpha = img.split()[3]
    corners = [(2,2),(0,0)]
    for x in range(0, 8):
        for y in range(0, 8):
            if alpha.getpixel((x,y)) >= 16: return False
    return True

# 只看根目录、且在 units 子目录有"已抠图对应版"的卡
# 因为游戏优先用根目录，如果根目录未抠图但 units 版已抠图，应该让根目录版也抠图
root_pngs = sorted([f for f in ROOT.glob("*.png") if not f.name.startswith("_")])

white_uncut = []  # 白底未抠图（需处理）
green_uncut = []  # 绿幕未抠图
already_cut = []  # 已抠图
other = []

for p in root_pngs:
    name = p.name
    # 跳过能量卡（用户选择不处理）
    if name.startswith("energy"):
        continue
    try:
        img = Image.open(p)
        img.load()
        rgb = img.convert("RGB")
        w, h = img.size
    except Exception as e:
        other.append((name, f"读取错误: {e}"))
        continue

    if has_transparent_corners(img):
        already_cut.append(name)
    elif is_white_bg(rgb, w, h):
        white_uncut.append(name)
    elif is_green_screen(rgb, w, h):
        green_uncut.append(name)
    else:
        other.append((name, "其他背景"))

print("=" * 60)
print("根目录专属卡面分类（已排除能量卡）")
print("=" * 60)
print(f"已抠图: {len(already_cut)} 张")
print(f"白底未抠图(需处理): {len(white_uncut)} 张")
print(f"绿幕未抠图(需处理): {len(green_uncut)} 张")
print(f"其他: {len(other)} 张")

print(f"\n=== 白底未抠图清单 ({len(white_uncut)} 张) ===")
# 按前缀分组
groups = {}
for n in white_uncut:
    pre = n.split("_")[0]
    groups.setdefault(pre, []).append(n)
for pre, files in sorted(groups.items()):
    print(f"\n  [{pre}_*] {len(files)} 张:")
    for f in files:
        print(f"    {f}")

print(f"\n=== 绿幕未抠图清单 ({len(green_uncut)} 张) ===")
for n in green_uncut:
    print(f"  {n}")

print(f"\n=== 其他 ({len(other)} 张) ===")
for n, reason in other[:20]:
    print(f"  {n}: {reason}")

print(f"\n=== 已抠图样本 ({len(already_cut)} 张，无需处理) ===")
print("  " + ", ".join(already_cut[:15]) + " ...")
