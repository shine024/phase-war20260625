# -*- coding: utf-8 -*-
"""W5 审计·追加轮：11 对镜像漂移同步（2026-09-14，§8 先例 + player=正身契约）。

审计发现（verify_card_icon_pairs 首跑）：16 对 player/enemy 配对非翻转等价。
mtime 甄别：11 对 player 侧更新（09-09 批处理 vs 旧 enemy）→ 本脚本同步
enemy := flip(player)；5 对 enemy 侧更新（036/049/056/071/093，09-09 当天 enemy
单独被动过、同步方向不明）→ 不动，CP-2 呈用户裁决。
每张旧 enemy 图先备份 _art_backup/*-preW5FIX2-2026-09-14.png。
"""
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BK = os.path.join(ROOT, "_art_backup")
os.makedirs(BK, exist_ok=True)

FIX = [
    ("fe_void_dimensional_soldier", 1.000),
    ("vis_enemy_008", 1.000), ("vis_enemy_014", 1.000), ("vis_enemy_022", 0.797),
    ("vis_enemy_027", 1.000), ("vis_enemy_054", 1.000), ("vis_enemy_063", 1.000),
    ("vis_enemy_064", 1.000), ("vis_enemy_072", 1.000), ("vis_enemy_113", 0.834),
    ("vis_enemy_114", 1.000),
]
PENDING = ["vis_enemy_036", "vis_enemy_049", "vis_enemy_056", "vis_enemy_071", "vis_enemy_093"]


def flip_eq(pa, pb):
    a = np.asarray(Image.open(pa).convert("RGBA"))
    b = np.asarray(Image.open(pb).convert("RGBA"))[:, ::-1]
    return a.shape == b.shape and bool((a == b).all())


def main():
    for enemy_id, _iou in FIX:
        num = enemy_id.replace("vis_enemy_", "")
        player_id = enemy_id if not enemy_id.startswith("vis_enemy_") else "vis_player_" + num
        enemy = os.path.join(ROOT, "assets", "card_icons", "enemy", enemy_id + ".png")
        player = os.path.join(ROOT, "assets", "card_icons", "player", player_id + ".png")

        bak = os.path.join(BK, enemy_id + "-preW5FIX2-2026-09-14.png")
        if not os.path.exists(bak):
            shutil.copy2(enemy, bak)

        img = Image.open(player).convert("RGBA")
        Image.fromarray(np.asarray(img)[:, ::-1]).save(enemy)
        assert flip_eq(enemy, player), enemy_id
        print("%s := flip(%s) OK" % (enemy_id, player_id))

    print("pending（未动，待 CP-2）:", PENDING)


if __name__ == "__main__":
    main()
