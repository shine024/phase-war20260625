#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""精确统计各目录的图片，并找出重复文件。
用户质疑数量不对，需确认根目录 vs units/ 子目录的关系。"""
from pathlib import Path
from PIL import Image
import hashlib

ROOT = Path(r"F:\godot fair duet\create\phase-war\assets\card_icons")

# 分别统计根目录和 units 子目录
root_pngs = sorted([f for f in ROOT.glob("*.png")])
units_pngs = sorted([f for f in (ROOT / "units").glob("*.png")])

print(f"根目录 card_icons/*.png: {len(root_pngs)} 张")
print(f"子目录 card_icons/units/*.png: {len(units_pngs)} 张")

# 找出两个目录中同名的文件
root_names = {f.name for f in root_pngs}
units_names = {f.name for f in units_pngs}
common = root_names & units_names
only_root = root_names - units_names
only_units = units_names - root_names

print(f"\n同名(两目录都有): {len(common)} 个")
print(f"仅根目录有: {len(only_root)} 个")
print(f"仅 units 有: {len(only_units)} 个")

# 检查同名文件是否内容相同（md5）
print("\n=== 同名文件内容对比 ===")
same_content = 0
diff_content = 0
diff_list = []
for name in sorted(common):
    r = ROOT / name
    u = ROOT / "units" / name
    md5_r = hashlib.md5(r.read_bytes()).hexdigest()[:12]
    md5_u = hashlib.md5(u.read_bytes()).hexdigest()[:12]
    if md5_r == md5_u:
        same_content += 1
    else:
        diff_content += 1
        diff_list.append(name)
print(f"内容完全相同: {same_content} 个")
print(f"内容不同: {diff_content} 个")
if diff_list:
    print("内容不同的文件:")
    for n in diff_list[:30]:
        print(f"  {n}")

# 根目录独有的文件分类（这些可能就是未抠图的白底卡）
print(f"\n=== 仅根目录有的文件({len(only_root)} 个) ===")
only_root_sorted = sorted(only_root)
# 按前缀分组
prefixes = {}
for n in only_root_sorted:
    pre = n.split("_")[0] if "_" in n else n.split(".")[0]
    prefixes.setdefault(pre, []).append(n)
for pre, files in sorted(prefixes.items()):
    print(f"  {pre}_*: {len(files)} 张")

# 检查这些根目录独有文件的实际使用情况
# 看看代码里是否引用 res://assets/card_icons/ww1_ft17.png 这种根目录路径
print(f"\n=== 仅 units 有的文件({len(only_units)} 个) 样本 ===")
for n in sorted(only_units)[:15]:
    print(f"  {n}")
