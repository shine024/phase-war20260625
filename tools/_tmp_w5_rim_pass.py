# -*- coding: utf-8 -*-
"""W5 CP-2 rim 缺位补边批（2026-09-15，B 簇后处置，用户批准开工）。

名单 = 视觉审计 B 档且 rim_actual=none 且期望档=ice 的 26 单位（§11.2 B 簇主因）。
工艺：逐行找背光侧（player 朝右=左缘；enemy vis_enemy_072 朝左=右缘）最外圈
不透明像素（a>=200），向冰天青 #99D9FF 混色（外 65% + 次像素 25%）——
**只改色不改 alpha**（剪影/脚锚不动，动画集无需联动）。
player 侧改后 enemy := flip(player) 重派（rim 落 enemy 背光侧 ✓）。
备份 _art_backup/*-preRIM-2026-09-15.png。neon 缺位 4 张与色档错位 12 张不在本批。
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BK = os.path.join(ROOT, "_art_backup")
ICE = np.array([153, 217, 255], dtype=np.float32)  # #99D9FF

PLAYERS = [
    "cold_air_bomber", "mod_air_bomber", "mod_arm_himars",
    "vis_player_002", "vis_player_005", "vis_player_006", "vis_player_007",
    "vis_player_011", "vis_player_012", "vis_player_013", "vis_player_015",
    "vis_player_038", "vis_player_073", "vis_player_074", "vis_player_076",
    "vis_player_082", "vis_player_083", "vis_player_084", "vis_player_085",
    "vis_player_086", "vis_player_088", "vis_player_090", "vis_player_091",
    "vis_player_110", "vis_player_111",
]
ENEMY_DIRECT = ["vis_enemy_072"]  # 朝左，背光=右缘，直改 enemy 文件


def backup(p):
    bak = os.path.join(BK, os.path.splitext(os.path.basename(p))[0] + "-preRIM-2026-09-15.png")
    if not os.path.exists(bak):
        Image.open(p).convert("RGBA").save(bak)


def tint_edge(img, side):
    """side='L'：每行最左实心像素混冰青；side='R'：最右。返回改动像素数。"""
    arr = np.asarray(img.convert("RGBA")).copy()
    solid = arr[..., 3] >= 200
    h, w = solid.shape
    n = 0
    for y in range(h):
        xs = np.where(solid[y])[0]
        if len(xs) == 0:
            continue
        x_edge = int(xs[0]) if side == "L" else int(xs[-1])
        px = arr[y, x_edge, :3].astype(np.float32)
        if px.mean() > 232:  # 已近白，rim 无感，跳过
            continue
        arr[y, x_edge, :3] = (px * 0.35 + ICE * 0.65).astype(np.uint8)
        n += 1
        x2 = x_edge + 1 if side == "L" else x_edge - 1
        if 0 <= x2 < w and solid[y, x2]:
            px2 = arr[y, x2, :3].astype(np.float32)
            arr[y, x2, :3] = (px2 * 0.75 + ICE * 0.25).astype(np.uint8)
    return Image.fromarray(arr, "RGBA"), n


def thumbs(png, name, side):
    for size, d in ((256, "_thumb256"), (384, "_thumb384")):
        im = Image.open(png).convert("RGBA")
        if max(im.size) > size:
            im.thumbnail((size, size), Image.Resampling.LANCZOS)
        out = os.path.join(ROOT, "assets", "card_icons", d, side, name + ".png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        im.save(out)


def main():
    total = 0
    for pid in PLAYERS:
        pp = os.path.join(ROOT, "assets", "card_icons", "player", pid + ".png")
        eid = "vis_enemy_" + pid[11:] if pid.startswith("vis_player_") else pid
        ep = os.path.join(ROOT, "assets", "card_icons", "enemy", eid + ".png")
        backup(pp)
        backup(ep)
        img, n = tint_edge(Image.open(pp), "L")
        img.save(pp, "PNG")
        arr = np.asarray(Image.open(pp).convert("RGBA"))
        Image.fromarray(arr[:, ::-1]).save(ep, "PNG")
        thumbs(pp, pid, "player")
        thumbs(ep, eid, "enemy")
        total += n
        print("%-24s rim %4d 行" % (pid, n))
    for eid in ENEMY_DIRECT:
        ep = os.path.join(ROOT, "assets", "card_icons", "enemy", eid + ".png")
        backup(ep)
        img, n = tint_edge(Image.open(ep), "R")
        img.save(ep, "PNG")
        thumbs(ep, eid, "enemy")
        total += n
        print("%-24s rim %4d 行（enemy 直改）" % (eid, n))
    print("total rim rows:", total)


if __name__ == "__main__":
    main()
