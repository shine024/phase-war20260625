#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""列出无法解析的卡，看它们走哪条取图路径。"""
import re
from pathlib import Path

ROOT = Path(r"D:/godotplay/godt fair duet/create/phase-war")
ROOT = Path(r"D:/godotplay/godot fair duel/phase-war")

with open(ROOT / "data/unified_card_table.gd", encoding="utf-8") as f:
    content = f.read()
pat = re.compile(r'"card_id":"([^"]+)"[^}]*?"display_name":"([^"]+)"[^}]*?"era":(\d+)[^}]*?"combat_kind":(\d+)')
card_meta = {}
for cid, dn, era, ck in pat.findall(content):
    card_meta[cid] = (dn, int(era), int(ck))

with open(ROOT / "scripts/ui_asset_loader.gd", encoding="utf-8") as f:
    ul = f.read()
override = {}
in_ov = False
for line in ul.splitlines():
    if "const PLAYER_ICON_OVERRIDE" in line:
        in_ov = True
        continue
    if in_ov:
        if line.strip() == "}":
            in_ov = False
            continue
        m = re.search(r'"([^"]+)":\s*"vis_player_(\d+)"', line)
        if m:
            override[m.group(1)] = f"vis_player_{m.group(2)}"

root_imgs = {p.stem for p in (ROOT / "assets/card_icons").glob("*.png")}
enemy_imgs = {p.stem for p in (ROOT / "assets/card_icons/enemy").glob("*.png")}
player_imgs = {p.stem for p in (ROOT / "assets/card_icons/player").glob("*.png")}

ERA = {0:"一战",1:"二战",2:"冷战",3:"现代",4:"近未来"}
CK = {0:"步兵",1:"装甲",2:"支援",3:"空中",4:"堡垒"}

print("=== 无法用 override/专属图/enemy图 解析的卡（走 manifest 或 fallback）===")
print("card_id | 单位名 | 分类 | 取图路径")
unresolved = []
for cid, (dn, era, ck) in sorted(card_meta.items()):
    if cid in root_imgs:
        continue
    if cid in override:
        continue
    if cid in enemy_imgs:
        continue
    # 走 manifest 或 fallback
    unresolved.append((cid, dn, era, ck))

# 按路径细分
print(f"\n总数: {len(unresolved)}\n")
for cid, dn, era, ck in unresolved:
    # 检查 player 目录是否有同名（manifest 可能映射）
    in_player = cid in player_imgs
    path = "manifest/fallback"
    if in_player:
        path = "player目录有同名图?"
    print(f"{cid} | {dn} | {ERA[era]}{CK[ck]} | {path}")
