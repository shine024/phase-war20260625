#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W3 步骤 2 前置量测——增量资产逐张程序化指标（2026-09-14）。

口径与批次④一致：暖区占比=(r>b+30 且 r>90)/全像素；卡图另测内容 bbox 最长维占比、
朝向（enemy 应=player 水平镜像）。雪碧图/贴片只测尺寸与暖区。
供分档表引用，不做任何修改。
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "assets")

CARDS = [
    "card_icons/player/vis_player_001.png", "card_icons/enemy/vis_enemy_001.png",
    "card_icons/player/vis_player_075.png", "card_icons/enemy/vis_enemy_075.png",
    "card_icons/player/fut_inf_c96.png", "card_icons/enemy/fut_inf_c96.png",
    "card_icons/player/ww2_arm_garand_para.png", "card_icons/enemy/ww2_arm_garand_para.png",
    "card_icons/player/ww2_air_me262.png", "card_icons/enemy/ww2_air_me262.png",
    "card_icons/player/ww2_air_meteor_e.png", "card_icons/enemy/ww2_air_meteor_e.png",
]
PAIRS = [(0, 1), (2, 3), (4, 5), (6, 7), (8, 9), (10, 11)]
DECALS = [
    "battle/decals/ground_decal_crater.png", "battle/decals/ground_decal_grass.png",
    "battle/decals/ground_decal_rubble.png", "battle/decals/ground_decal_tracks.png",
    "battle/decals/_raw_tracks.png",
]
SHEETS = [
    "effects/unit_anims/fut_inf_c96/sheet_idle.png",
    "effects/unit_anims/fut_inf_c96/sheet_attack.png",
    "effects/unit_anims/ww1_arm_rolls/sheet_idle.png",
    "effects/unit_anims/ww1_arm_rolls/sheet_attack.png",
    "effects/unit_anims/ww2_arm_garand_para/sheet_idle.png",
    "effects/unit_anims/ww2_arm_garand_para/sheet_attack.png",
    "effects/unit_anims/ww2_fort_flak/sheet_idle.png",
    "effects/unit_anims/ww2_fort_flak/sheet_attack.png",
]


def load(rel):
    return np.asarray(Image.open(os.path.join(A, rel)).convert("RGBA"))


def metrics(arr):
    r = arr[..., 0].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    a = arr[..., 3]
    warm = float(((r > b + 30) & (r > 90) & (a > 60)).mean())
    ys, xs = np.nonzero(a > 10)
    if len(xs):
        bw, bh = int(xs.max() - xs.min()), int(ys.max() - ys.min())
        ratio = max(bw / arr.shape[1], bh / arr.shape[0])
        bbox = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    else:
        ratio, bbox = 0.0, None
    return warm, ratio, bbox


def main() -> int:
    print("== 卡图（含镜像校验）==")
    imgs = {rel: load(rel) for rel in CARDS}
    for rel in CARDS:
        arr = imgs[rel]
        w, ratio, bbox = metrics(arr)
        print("%-46s %sx%s 暖区 %.1f%% 占比 %.0f%% bbox=%s"
              % (rel, arr.shape[1], arr.shape[0], w * 100, ratio * 100, bbox))
    for pi, ei in PAIRS:
        p, e = imgs[CARDS[pi]], imgs[CARDS[ei]]
        if p.shape != e.shape:
            print("[FLIP] %s vs %s 尺寸不一致!" % (CARDS[pi], CARDS[ei]))
            continue
        same = bool(np.array_equal(p[..., :3], e[..., :3][:, ::-1]) and
                    np.array_equal(p[..., 3], e[..., 3][:, ::-1]))
        print("[FLIP] enemy==mirror(player)? %s  (%s)" % (same, CARDS[ei]))
    print("\n== 地面贴片 ==")
    for rel in DECALS:
        arr = load(rel)
        w, ratio, bbox = metrics(arr)
        print("%-46s %sx%s 暖区 %.1f%% 内容占比 %.0f%%"
              % (rel, arr.shape[1], arr.shape[0], w * 100, ratio * 100))
    print("\n== 动画雪碧图 ==")
    for rel in SHEETS:
        arr = load(rel)
        w, _, _ = metrics(arr)
        print("%-52s %sx%s 暖区 %.1f%%"
              % (rel, arr.shape[1], arr.shape[0], w * 100))
    return 0


if __name__ == "__main__":
    sys.exit(main())
