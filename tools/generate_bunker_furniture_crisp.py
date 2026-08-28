#!/usr/bin/env python3
"""余烬要塞 · 家具图标高清重生成（精致度批次，2026-08-26）。

识图评审点名两张图标细节糊：fur_depot（仓库货架）/ fur_antenna（气象站天线）
——源图 139/155px 宽，是全套最小的两张。本脚本用原版 prompt + 锐化风格词
重生成 1024² 高清版，走原处理管线（白底转透明 → 裁边 → 缩到高 160px）覆盖。

复用 tools/generate_bunker_assets.py 的风格前缀/生成/后处理函数，保证组内风格一致。
生成后必须：1) 重跑 generate_bunker_bg.py 烘焙 2) godot --headless --import
3) 按美术备份铁律打包项目外 zip。
"""
import os
import shutil
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import generate_bunker_assets as gba  # noqa: E402（复用前缀/生成/后处理）

RAW_DIR = gba.RAW_DIR
OUT_DIR = gba.OUT_DIR

CRISP = ("硬朗清晰的高对比轮廓，边缘锐利，细节密度高，笔触干净利落，"
         "清晰锐利的游戏图标质感")

ITEMS = [
    {"fname": "fur_depot",
     "desc": "金属仓储货架侧视：四层重型货架，大部分格子空着落满灰，仅几只军绿色箱子。" + CRISP},
    {"fname": "fur_antenna",
     "desc": "气象站天线阵列侧视：倾斜的桁架塔上的风速计与蝶形天线，半埋在碎石尘土中。" + CRISP},
]


def main():
    os.makedirs(RAW_DIR, exist_ok=True)
    for item in ITEMS:
        fname = item["fname"]
        out_path = os.path.join(OUT_DIR, fname + ".png")
        # 备份旧版（PNG 不入 git，覆盖前必须留底）
        if os.path.exists(out_path):
            bak = os.path.join(RAW_DIR, fname + "_v1_backup.png")
            shutil.copy(out_path, bak)
            print("backup:", bak)
        raw_path = os.path.join(RAW_DIR, fname + "_crisp_raw.png")
        prompt = gba.SPRITE_PREFIX + item["desc"] + "。" + gba.NEG
        ok, msg = gba.generate_image(prompt, raw_path)
        print(fname, "generate:", ok, msg)
        if not ok:
            sys.exit(1)
        # 后处理：白底转透明 + 裁边 + 缩到高 160（与全套一致）
        gba_img = {"kind": "sprite"}
        size = gba.post_process(gba_img, raw_path, out_path)
        print(fname, "deployed:", size)
    print("DONE — 记得：重跑 generate_bunker_bg.py → godot --import → 项目外备份 zip")


if __name__ == "__main__":
    main()
