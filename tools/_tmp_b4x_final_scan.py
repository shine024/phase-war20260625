#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""终版合规重扫描（2026-09-14 收尾）。量测口径=b4/宪法：
- 卡图：暖区占比（r>b+30 & r>90 / 不透明像素）>15% 旗标；内容最长维占比 >90% 旗标
- 镜像：enemy == FLIP_LEFT_RIGHT(player) 逐对校验
- 背景：本轮 22 张 LUT 后暖区复核（≤15% 线）
输出汇总计数+旗标清单（供计划文档终版数字）。
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYER = os.path.join(ROOT, "assets", "card_icons", "player")
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy")


def warm_ratio(arr):
    r, b = arr[..., 0].astype(np.int16), arr[..., 2].astype(np.int16)
    a = arr[..., 3]
    sel = a > 60
    if sel.sum() < 100:
        return 0.0
    return float(((r > b + 30) & (r > 90) & sel).sum()) / float(sel.sum())


def content_ratio(arr):
    ys, xs = np.nonzero(arr[..., 3] > 10)
    if len(xs) == 0:
        return 0.0
    return max((xs.max() - xs.min()) / arr.shape[1], (ys.max() - ys.min()) / arr.shape[0])


def main() -> int:
    files = sorted(f for f in os.listdir(PLAYER) if f.endswith(".png") and "_thumb" not in f)
    warm_flags, ratio_flags, flip_flags = [], [], []
    pairs = 0
    for f in files:
        p = np.asarray(Image.open(os.path.join(PLAYER, f)).convert("RGBA"))
        e = os.path.join(ENEMY, f)
        if os.path.exists(e):
            pairs += 1
            ei = Image.open(e).convert("RGBA")
            ref = Image.fromarray(p).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if list(ei.getdata()) != list(ref.getdata()):
                flip_flags.append(f)
        w = warm_ratio(p)
        if w > 0.15:
            warm_flags.append((f, round(w * 100, 1)))
        c = content_ratio(p)
        if c > 0.90:
            ratio_flags.append((f, round(c * 100)))

    bgs = ["bg_level_02", "bg_level_05", "bg_level_08", "bg_level_15", "bg_level_18",
           "bg_level_25", "bg_level_28", "bg_level_32", "bg_level_35", "bg_level_45",
           "bg_level_48", "bg_level_52", "bg_level_62", "bg_level_65", "bg_level_72",
           "bg_level_75", "bg_level_78", "bg_level_82", "bg_level_88", "bg_level_95",
           "bg_level_98", "bg_endless_gate_t2"]
    bg_over = []
    for b in bgs:
        arr = np.asarray(Image.open(os.path.join(ROOT, "assets", "backgrounds", b + ".png")).convert("RGB"))
        r, bb = arr[..., 0].astype(np.int16), arr[..., 2].astype(np.int16)
        w = float(((r > bb + 30) & (r > 90)).mean()) * 100
        if w > 15.0:
            bg_over.append((b, round(w, 1)))
        print("%s 暖区 %.1f%%" % (b, w))

    print("\n=== 汇总 ===")
    print("卡图扫描 %d 张（player 侧）；player/enemy 配对 %d" % (len(files), pairs))
    print("暖区旗标 %d：%s" % (len(warm_flags), warm_flags))
    print("占比旗标 %d：%s" % (len(ratio_flags), ratio_flags))
    print("镜像不一致 %d：%s" % (len(flip_flags), flip_flags))
    print("背景 B 档 22 张超线 %d：%s" % (len(bg_over), bg_over))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
