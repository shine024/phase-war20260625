# -*- coding: utf-8 -*-
"""img25 掷表重放（2026-10-01）：键控算法修正后从 *_attack_raw_R*.png 重放 sheet_direct。

背景: chroma_key v2 的近品红球（tol=85）被粉烟桥接进身体，暗红调面部阴影被整块抠掉
    （cold_ak47 c2-c6 脸吃没案例，真原始出图 attack_raw_R*.png 脸完好）。v3 加品红色相
    双约束后需从原始出图重放，不能在已抠坏的掷表上补 —— 坏 alpha 无法复原。
用法:
    python tools/img25_sheet_reprocess.py                    # 111.txt 10 单位 × R1-R3
    python tools/img25_sheet_reprocess.py --keys cold_ak47   # 子集
    python tools/img25_sheet_reprocess.py --all              # 全工作清单（88 单位）
卡图对齐: 与批 runner 一致传 --card-align 等价参数（fit_armor Reinhard），卡图取 _worklist.json。
产出: 覆盖 <key>_R<n>_attack_sheet_832.png + _cells + _anim(+pal8)（与批产同路径同格式）。
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from img25_attack_gen import sheet_direct  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ST = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
SPECIAL10 = ["cold_ak47", "cold_arty_brem1", "cold_mig21", "cold_rpg", "fut_assault_mech",
             "fut_stealth_bomber", "fut_sup_ps9", "mod_air_bomber", "mod_hummer_m2",
             "mod_stryker_mgs"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--rolls", default="1,2,3")
    args = ap.parse_args()

    wl = json.load(open(os.path.join(ST, "_worklist.json"), encoding="utf-8"))
    cards = {e["key"]: e["card"] for e in wl if e.get("key") and e.get("card")}

    if args.all:
        keys = [e["key"] for e in wl if e.get("key")]
    elif args.keys:
        keys = args.keys.split(",")
    else:
        keys = SPECIAL10
    rolls = [int(r) for r in args.rolls.split(",")]

    for key in keys:
        card = cards.get(key)
        card_path = os.path.join(ROOT, card) if card else None
        for r in rolls:
            raw_path = os.path.join(ST, "%s_attack_raw_R%d.png" % (key, r))
            if not os.path.exists(raw_path):
                print("[%s R%d] 缺原始出图，跳过" % (key, r), flush=True)
                continue
            print("[%s R%d] 重放…" % (key, r), flush=True)
            sheet_direct(raw_path, "%s_R%d" % (key, r), card=card_path)
    print("重放完成: %d 单位 × 掷 %s" % (len(keys), rolls))


if __name__ == "__main__":
    main()
