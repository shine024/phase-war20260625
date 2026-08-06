#!/usr/bin/env python3
"""部署 21 张改造图标到 assets/ui/icons/mod_icons/。

程序化生成的图标已是 512x512 RGB 白底（目标规格），无需缩放/裁剪/转透明。
本脚本做：
1. 校验每张图都是 512x512 RGB（不符则规范化）
2. 复制到 assets/ui/icons/mod_icons/mod_<name>.png
3. 输出部署清单

注：不生成 .import 文件——Godot 编辑器打开或 headless --check-only 会自动导入。
"""
import os
import shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成改造图标_21张")
DST_DIR = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
TARGET_SIZE = 512

# 21 张待部署图标（与 generate_mod_icons_procedural.py 的 ICONS 列表一致）
ICONS = [
    "mod_thermolite", "mod_ammo_incendiary", "mod_ammo_phosphorus", "mod_combustion_catalyst",
    "mod_emp_warhead", "mod_antiradiation", "mod_ammo_graphite", "mod_overload",
    "mod_nano_amp", "mod_nano_seeder", "mod_nano_catalyst",
    "mod_targeting_laser", "mod_beam_splitter", "mod_reflector", "mod_optical_fiber",
    "mod_targeting_drone", "mod_weakpoint",
    "mod_acid", "mod_ammo_chem", "mod_chem_sprayer", "mod_pollution",
]


def normalize(src_path, dst_path):
    """校验并规范化图片为 512x512 RGB，保存到 dst_path。"""
    im = Image.open(src_path)
    changed = False
    if im.size != (TARGET_SIZE, TARGET_SIZE):
        im = im.resize((TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)
        changed = True
    if im.mode != "RGB":
        im = im.convert("RGB")
        changed = True
    # 直接保存（已规范化或本就合规）
    im.save(dst_path, "PNG")
    return im.size, im.mode, changed


def main():
    os.makedirs(DST_DIR, exist_ok=True)
    print("Source: " + SRC_DIR)
    print("Dest:   " + DST_DIR)
    print("Deploying " + str(len(ICONS)) + " icons...\n")

    ok = 0
    missing = 0
    for i, name in enumerate(ICONS):
        src = os.path.join(SRC_DIR, name + ".png")
        dst = os.path.join(DST_DIR, name + ".png")
        if not os.path.exists(src):
            print("[" + str(i+1).zfill(2) + "] MISSING SOURCE: " + name + ".png")
            missing += 1
            continue
        size, mode, changed = normalize(src, dst)
        flag = " (normalized)" if changed else ""
        print("[" + str(i+1).zfill(2) + "/" + str(len(ICONS)) + "] " + name + ".png  "
              + str(size[0]) + "x" + str(size[1]) + " " + mode + flag)
        ok += 1

    print("\n=== Deploy Summary ===")
    print("  Deployed: " + str(ok) + "/" + str(len(ICONS)))
    if missing:
        print("  MISSING SOURCE: " + str(missing))
    print("\nNext: Godot will auto-generate .import on next editor open / --check-only.")


if __name__ == "__main__":
    main()
