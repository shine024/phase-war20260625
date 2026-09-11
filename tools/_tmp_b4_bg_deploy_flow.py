#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④ Flow 重生成背景部署（2026-09-10，用户已审阅认可）。

来源 docs/flow重生成_审查/背景_批4/<name>.png（1376×768 Flow 原生，10 张主图），
aspect-fill 裁 1280×720 → 备份 assets 现图后部署 assets/backgrounds/。
备选 alt 留在审查夹不入库。备份惯例沿用 _tmp_b4_bg_regen.py（_art_backup）。
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "docs", "flow重生成_审查", "背景_批4")
ASSETS = os.path.join(ROOT, "assets", "backgrounds")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"
TAG = "preFlow-2026-09-10"

NAMES = [
    "bg_endless_gate_t0", "bg_endless_gate_t1",
    "bg_level_12", "bg_level_22", "bg_level_38", "bg_level_42",
    "bg_level_55", "bg_level_58", "bg_level_68", "bg_level_92",
]


def aspect_fill_16x9(src, dst, w=1280, h=720):
    im = Image.open(src).convert("RGB")
    sw, sh = im.size
    scale = max(w / sw, h / sh)
    nw, nh = int(sw * scale + 0.5), int(sh * scale + 0.5)
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - w) // 2, (nh - h) // 2
    im.crop((left, top, left + w, top + h)).save(dst, "PNG")


def main() -> int:
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for name in NAMES:
        src = os.path.join(REVIEW, name + ".png")
        dst = os.path.join(ASSETS, name + ".png")
        if not os.path.exists(src):
            print("MISSING:", name)
            return 1
        bak = os.path.join(BACKUP_DIR, "%s-%s.png" % (name, TAG))
        if os.path.exists(dst) and not os.path.exists(bak):
            with open(dst, "rb") as fi, open(bak, "wb") as fo:
                fo.write(fi.read())
        aspect_fill_16x9(src, dst)
        print("deployed:", name, Image.open(dst).size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
