#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""存量镜像不对称 13 对重 derive（2026-09-14 收尾追加，用户"继续"指令）。

铁律 #2：enemy 卡图 = player 的 FLIP_LEFT_RIGHT。13 对 enemy 为历史"双渲染
take"件（目视近似、像素不对称，清单见分档表 §8.1）。本脚本：
备份 enemy 原件（preW3C-2026-09-14）→ enemy := flip(player) → 双侧 thumbs
重建 → 83 对全量 alpha 门控镜像终检。
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYER = os.path.join(ROOT, "assets", "card_icons", "player")
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy")
THUMB256 = os.path.join(ROOT, "assets", "card_icons", "_thumb256")
THUMB384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384")
BACKUP = r"F:\godot fair duet\_art_backup"

NAMES = [
    "cold_air_strike_fighter", "cold_arty_brem1", "cold_inf_metis",
    "drop_railgun", "fut_arm_hk07", "fut_swarm", "mod_air_multirole",
    "mod_inf_patriot", "mod_sup_growler", "ww1_inf_enfield",
    "ww1_sup_ford_ambulance", "ww2_arty_hummel", "ww2_inf_kar98k",
]


def make_thumb(src_png, dst_png, size):
    img = Image.open(src_png).convert("RGBA")
    if max(img.size) <= size:
        return "small"
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    img.save(dst_png)
    return "ok"


def main() -> int:
    done = 0
    for name in NAMES:
        pp = os.path.join(PLAYER, name + ".png")
        ep = os.path.join(ENEMY, name + ".png")
        if not (os.path.exists(pp) and os.path.exists(ep)):
            print("SKIP %s: 缺件" % name)
            continue
        bak = os.path.join(BACKUP, "enemy-%s-preW3C-2026-09-14.png" % name)
        if not os.path.exists(bak):
            with open(ep, "rb") as fi, open(bak, "wb") as fo:
                fo.write(fi.read())
        img = Image.open(pp).convert("RGBA")
        img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(ep, "PNG")
        make_thumb(ep, os.path.join(THUMB256, "enemy", name + ".png"), 256)
        make_thumb(ep, os.path.join(THUMB384, "enemy", name + ".png"), 384)
        done += 1
        print("OK %s（enemy 原件已备份）" % name)

    # 83 对全量终检
    files = sorted(f for f in os.listdir(PLAYER) if f.endswith(".png"))
    pairs = mismatch = 0
    bad = []
    for f in files:
        e = os.path.join(ENEMY, f)
        if not os.path.exists(e):
            continue
        pairs += 1
        a = np.asarray(Image.open(os.path.join(PLAYER, f)).convert("RGBA")).astype(np.int16)
        b = np.asarray(Image.open(e).convert("RGBA")).astype(np.int16)
        sel = (a[..., 3] > 10) | (b[..., 3] > 10)
        d = np.abs(a[:, ::-1] - b).max(-1)[sel]
        if (d > 2).sum() > 0:
            mismatch += 1
            bad.append(f)
    print("\n终检：配对 %d，不一致 %d %s" % (pairs, mismatch, bad if bad else ""))
    return 0 if (done == len(NAMES) and mismatch == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
