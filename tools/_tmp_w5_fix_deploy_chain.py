# -*- coding: utf-8 -*-
"""W5 审计·组6 部署断链修复（2026-09-14，CP-2 组6 用户确认执行）。

修复内容（审计发现②）：
1. enemy/vis_enemy_001.png、enemy/vis_enemy_075.png := flip(player 新图)（W3 §7-A 重生成
   时 enemy 翻转被写错名，正确路径仍是 09-11 旧图）；
2. 移除错名 4 件：enemy/vis_player_001.png(.import)、enemy/vis_player_075.png(.import)；
3. 备份旧图到 _art_backup/（preW5FIX 惯例）。
执行后需跑 gen_ui_thumbs --only cards + godot 重导入（本脚本只做 1-3 + 自检）。
"""
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BK = os.path.join(ROOT, "_art_backup")
os.makedirs(BK, exist_ok=True)


def flip_save(src, dst):
    img = Image.open(src).convert("RGBA")
    arr = np.asarray(img)[:, ::-1]
    Image.fromarray(arr).save(dst)
    return dst


def flip_eq(a_path, b_path):
    a = np.asarray(Image.open(a_path).convert("RGBA"))
    b = np.asarray(Image.open(b_path).convert("RGBA"))[:, ::-1]
    return a.shape == b.shape and bool((a == b).all())


def main():
    for num in ("001", "075"):
        enemy = os.path.join(ROOT, "assets", "card_icons", "enemy", "vis_enemy_%s.png" % num)
        player = os.path.join(ROOT, "assets", "card_icons", "player", "vis_player_%s.png" % num)
        misnamed = os.path.join(ROOT, "assets", "card_icons", "enemy", "vis_player_%s.png" % num)

        # 1. 备份旧图（一次性，已存在则跳过防覆盖备份本体）
        bak = os.path.join(BK, "vis_enemy_%s-preW5FIX-2026-09-14.png" % num)
        if not os.path.exists(bak):
            shutil.copy2(enemy, bak)
        old_mtime = os.path.getmtime(enemy)

        # 2. enemy := flip(player)
        flip_save(player, enemy)
        assert os.path.getmtime(enemy) != old_mtime

        # 3. 移除错名文件（png + .import）
        for p in (misnamed, misnamed + ".import"):
            if os.path.exists(p):
                os.remove(p)
                print("removed", os.path.relpath(p, ROOT))

        ok = flip_eq(enemy, player)
        print("vis_enemy_%s := flip(player) -> flip_eq=%s" % (num, ok))
        assert ok

    # 自检：enemy 目录不得再有 vis_player_* 文件
    leftover = [f for f in os.listdir(os.path.join(ROOT, "assets", "card_icons", "enemy"))
                if f.startswith("vis_player")]
    print("enemy 目录 vis_player* 残留:", leftover)
    assert not leftover
    print("OK")


if __name__ == "__main__":
    main()
