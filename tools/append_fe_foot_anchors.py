#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""增量扫描 14 张 fe_* 卡图的脚部/头部锚点，插入 data/card_foot_anchors.gd。

为什么不直接跑 generate_card_foot_anchors.py：
  1. 该脚本 ROOT/OUT 硬编码旧路径 F:\...，与当前 D:\... 不符
  2. 该脚本会全表重写 .gd，会截断丢失 VISUAL_SCALE / PLAYER_PLATFORM_TO_SCALE_ARCHETYPE
     等手工维护段（脚本只生成 FOOT_FRAC/HEAD_FRAC 两段）
  3. 本脚本只处理新增的 fe_*，增量插入现有表，零破坏

锚点算法与 generate_card_foot_anchors.py 完全一致：
  foot_frac = 脚（最低非透明像素）距纹理底部比例
  head_frac = 头（最高非透明像素）距纹理顶部比例
"""
import os, re, sys
from PIL import Image
sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
ANCHORS_FILE = os.path.join(ROOT, "data", "card_foot_anchors.gd")

ALPHA_THRESH = 10
MIN_FRAC_TO_RECORD = 0.02

FE_IDS = [
    "fe_iron_wall_bastion", "fe_iron_wall_juggernaut",
    "fe_nova_devastator", "fe_nova_ghost_sniper",
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen",
    "fe_quantum_mobile_base", "fe_quantum_repair_drone",
    "fe_helix_phantom", "fe_helix_orbital_strike",
    "fe_void_phase_cannon", "fe_void_dimensional_soldier",
    "fe_frontier_veteran", "fe_frontier_mixed_company",
]


def anchors_of(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if h == 0:
        return (0.0, 0.0)
    alpha = img.getchannel("A")
    px = alpha.load()
    bottom_y = h
    for y in range(h - 1, -1, -1):
        for x in range(0, w, 2):
            if px[x, y] > ALPHA_THRESH:
                bottom_y = y
                break
        if bottom_y < h:
            break
    top_y = -1
    for y in range(0, h):
        for x in range(0, w, 2):
            if px[x, y] > ALPHA_THRESH:
                top_y = y
                break
        if top_y >= 0:
            break
    if bottom_y >= h or top_y < 0:
        return (0.0, 0.0)
    foot_px = (h - 1) - bottom_y
    head_px = top_y
    return (foot_px / float(h), head_px / float(h))


# 1. 扫描 14 张 fe_* 锚点
print("扫描 14 张 fe_* 卡图锚点...\n")
results = {}
for fid in FE_IDS:
    path = os.path.join(PLAYER_DIR, fid + ".png")
    if not os.path.exists(path):
        print(f"  缺图: {fid}")
        continue
    foot, head = anchors_of(path)
    results[fid] = (round(foot, 3), round(head, 3))
    rec = "记录" if (foot >= MIN_FRAC_TO_RECORD or head >= MIN_FRAC_TO_RECORD) else "贴边(默认0)"
    print(f"  {fid:30} foot={foot:.3f} head={head:.3f}  [{rec}]")

# 2. 读现有 .gd
with open(ANCHORS_FILE, "r", encoding="utf-8") as f:
    src = f.read()

# 3. 在 FOOT_FRAC 表的 } 前插入 fe_* 条目
def insert_entries(src, table_name, entries_dict, comment_line):
    """在指定 const 表的闭合 } 前插入条目。entries_dict: {key: value_float}"""
    # 找表起始
    m = re.search(r'(const\s+' + table_name + r':\s*Dictionary\s*=\s*\{)', src)
    if not m:
        print(f"  错误: 找不到表 {table_name}")
        return src
    start = m.end()  # { 之后
    # 找该表的闭合 }（第一个独占行的 }）
    end = src.find("\n}", start)
    if end < 0:
        print(f"  错误: 表 {table_name} 未闭合")
        return src
    # 构建 fe_* 段（注释 + 条目）
    lines = []
    if comment_line:
        lines.append("\t# " + comment_line)
    for k in FE_IDS:
        if k in entries_dict:
            lines.append(f'\t"{k}": {entries_dict[k]:.3f},')
    insert_block = "\n".join(lines) + "\n"
    # 插入到闭合 } 前
    return src[:end] + "\n" + insert_block + src[end:]

foot_dict = {k: v[0] for k, v in results.items()}
head_dict = {k: v[1] for k, v in results.items()}

src = insert_entries(src, "FOOT_FRAC", foot_dict, "v8.x 势力专属卡（14张，AI生成）")
src = insert_entries(src, "HEAD_FRAC", head_dict, "v8.x 势力专属卡（14张，AI生成）")

with open(ANCHORS_FILE, "w", encoding="utf-8") as f:
    f.write(src)

print(f"\n已写入 {ANCHORS_FILE}")
print(f"FOOT_FRAC 插入 {len(foot_dict)} 条，HEAD_FRAC 插入 {len(head_dict)} 条")
