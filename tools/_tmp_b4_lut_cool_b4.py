#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④ 批 4（一）：B 档卡图 LUT 压冷/压暖（2026-09-09）。

处置清单取自 资产分档审计-2026-09-08 §卡图立绘（处置含 压冷/压暖/LUT 的条目）；
rim 补/微缩放/微抠类外科处置不在本脚本（留批 4 后续轮）。
算法：暖区压缩——对 r>b 的像素把 (r-b) 差距按 WARM_COMPRESS 比例收缩（保单点
暖 accent 语义，只压面积），冷区不动。指标=暖区占比（r>b+30 且 r>90）前后对照，
目标 ≤15%（宪法口径）或相对降幅 ≥30%。
原图逐张备份 _art_backup/*-preLUT-2026-09-09.png。
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYER = os.path.join(ROOT, "assets", "card_icons", "player")
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"

WARM_COMPRESS = 0.72   # (r-b) 差距收缩比例（0.72 = 压掉 28%）

FILES = [
    "player/ww1_inf_enfield", "player/ww2_inf_kar98k", "player/ww2_arty_hummel",
    "player/cold_inf_metis", "player/cold_arty_brem1", "player/vis_player_014",
    "player/vis_player_054", "player/vis_player_008", "player/vis_player_049",
    "player/vis_player_072", "player/vis_player_064", "player/vis_player_063",
    "player/fe_void_dimensional_soldier", "player/fut_arm_hk07", "player/fut_swarm",
    "player/vis_player_027", "player/vis_player_114", "player/drop_railgun",
    "enemy/vis_enemy_036", "enemy/vis_enemy_049", "enemy/vis_enemy_071",
]


def warm_ratio(px, w, h):
    warm = 0
    total = w * h
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b, a = px[x, y]
            if a > 60 and r > b + 30 and r > 90:
                warm += 1
    t = max(1, (w // 2) * (h // 2))
    return warm / t


def cool_lut(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r > b:
                d = (r - b) * WARM_COMPRESS
                nr = int(b + d)
                px[x, y] = (nr, g, b, a)
    return img


def main() -> int:
    os.makedirs(BACKUP_DIR, exist_ok=True)
    rows = []
    for rel in FILES:
        path = os.path.join(ROOT, "assets", "card_icons", rel + ".png")
        img = Image.open(path).convert("RGBA")
        px = img.load()
        w, h = img.size
        before = warm_ratio(px, w, h)
        bdst = os.path.join(BACKUP_DIR, os.path.basename(rel) + "-preLUT-2026-09-09.png")
        if not os.path.exists(bdst):
            with open(path, "rb") as fi, open(bdst, "wb") as fo:
                fo.write(fi.read())
        img = cool_lut(img)
        px = img.load()
        after = warm_ratio(px, w, h)
        img.save(path, "PNG")
        ok = after <= 0.15 or (before > 0 and (before - after) / before >= 0.30)
        rows.append((rel, before, after, ok))
        print("%-34s 暖区 %.1f%% -> %.1f%%  %s" % (rel, before * 100, after * 100,
                                                   "OK" if ok else "仍偏暖"))
    n_ok = sum(1 for r in rows if r[3])
    print("[SUMMARY] %d/%d 达标（其余留观察/二次压）" % (n_ok, len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
