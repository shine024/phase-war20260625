# -*- coding: utf-8 -*-
"""verify_card_icon_pairs.py — 卡图双侧配对卫生校验（W5 审计组6 防复发，2026-09-14）。

三条铁律（源自 W5 审计发现②部署断链）：
1. enemy/ 目录不得出现 vis_player_* 文件（部署翻转必须落 vis_enemy_NNN / 同名 id 正确路径）；
2. player 每张卡图若存在 enemy 配对文件，必须 = 水平翻转（FLIP_LEFT_RIGHT 契约）；
3. enemy vis_enemy_NNN 若存在同号 vis_player_NNN，必须互为翻转（防旧图滞留）。

用法：python tools/verify_card_icon_pairs.py   （全量，秒级；CI/部署后均可跑）
退出码：0=全过，1=有违规（打印清单）。
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDIR = os.path.join(ROOT, "assets", "card_icons", "player")
EDIR = os.path.join(ROOT, "assets", "card_icons", "enemy")

# W5 审计追加轮登记：enemy 侧更新（09-09 单侧被动过）、同步方向待用户裁决的 5 对。
# 裁决后处置并从本清单移除；在此之前校验只报 PENDING 不算失败。
KNOWN_PENDING = {
    "vis_enemy_036", "vis_enemy_049", "vis_enemy_056", "vis_enemy_071", "vis_enemy_093",
}


def flip_eq(pa, pb):
    a = np.asarray(Image.open(pa).convert("RGBA"))
    b = np.asarray(Image.open(pb).convert("RGBA"))[:, ::-1]
    return a.shape == b.shape and bool((a == b).all())


def main():
    bad = []
    pending = []
    players = sorted(f[:-4] for f in os.listdir(PDIR) if f.endswith(".png"))
    enemies = sorted(f[:-4] for f in os.listdir(EDIR) if f.endswith(".png"))

    # 铁律 1
    for e in enemies:
        if e.startswith("vis_player"):
            bad.append("[铁律1] enemy/ 目录混入 player 命名文件: enemy/%s.png" % e)

    eset = set(enemies)
    # 铁律 2 + 3：凡同名配对必须互为翻转（两侧各查一遍，名义上等价但都列出让报错可定位）
    for p in players:
        if p in eset:
            if not flip_eq(os.path.join(PDIR, p + ".png"), os.path.join(EDIR, p + ".png")):
                bad.append("[铁律2] enemy/%s.png != flip(player/%s.png)（旧图滞留或未同步）" % (p, p))
    for e in enemies:
        if e.startswith("vis_enemy_"):
            p = "vis_player_" + e[len("vis_enemy_"):]
            if p in set(players) and not flip_eq(os.path.join(EDIR, e + ".png"), os.path.join(PDIR, p + ".png")):
                if e in KNOWN_PENDING:
                    pending.append("[PENDING] enemy/%s.png 与 player/%s.png 非翻转（enemy 侧较新，同步方向待裁决）" % (e, p))
                else:
                    bad.append("[铁律3] enemy/%s.png != flip(player/%s.png)（vis 号配对旧图滞留）" % (e, p))

    for w in pending:
        print(w)
    if bad:
        print("FAIL %d 项：" % len(bad))
        for b in bad:
            print(" ", b)
        sys.exit(1)
    print("OK：player %d 张 / enemy %d 张，配对卫生通过（PENDING %d 对待裁决不计失败）"
          % (len(players), len(enemies), len(pending)))


if __name__ == "__main__":
    main()
