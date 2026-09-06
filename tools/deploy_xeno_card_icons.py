#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""部署星冥族 20 张卡图：白底转透明 + 512² + enemy/ 原图 + player/ 水平翻转。

与 deploy_card_icons_11.py 同款管线；额外产出：
  资料/单位分帧动画/_ref/<key>_white.jpg  —— 动画生成的白底参考图（imgbb 上传用）
命名约定：vis_xeno_<short> 不带 vis_player_/vis_enemy_ 前缀，
manifest._icon_subdir 第三分支按敌我分流（enemy/ for_player=false，player/ for_player=true）。
"""
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xeno_assets_config import UNITS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成卡图_xeno")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
REF_DIR = os.path.join(ROOT, "资料", "单位分帧动画", "_ref")
OUT_SIZE = 512


def white_to_alpha(img: Image.Image) -> Image.Image:
    """白底转透明（容差处理近白边缘）。"""
    import numpy as np
    rgb = img.convert("RGB")
    arr = np.array(rgb, dtype=np.int16)
    brightness = arr[:, :, :3].mean(axis=2)
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    out = np.dstack([
        arr[:, :, 0].astype(np.uint8),
        arr[:, :, 1].astype(np.uint8),
        arr[:, :, 2].astype(np.uint8),
        alpha,
    ])
    return Image.fromarray(out, "RGBA")


def fit_square(img: Image.Image, size: int) -> Image.Image:
    """裁剪到内容边界 + 等比缩放居中（88% 占比留白）。"""
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * 0.88
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def main():
    os.makedirs(PLAYER_DIR, exist_ok=True)
    os.makedirs(REF_DIR, exist_ok=True)
    only = set(sys.argv[1:])
    todo = [u for u in UNITS if not only or u["key"] in only]
    print("部署星冥卡图：%d 张 → enemy/ + player/ + _ref/" % len(todo))
    n_ok = n_fail = 0
    for u in todo:
        key = u["key"]
        src = os.path.join(SRC_DIR, key + "_white.png")
        if not os.path.exists(src):
            print("  SKIP %s: 源图不存在（先跑 generate_xeno_card_icons.py）" % key)
            n_fail += 1
            continue
        img = fit_square(white_to_alpha(Image.open(src)), OUT_SIZE)
        img.save(os.path.join(ENEMY_DIR, key + ".png"), "PNG")
        img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
            os.path.join(PLAYER_DIR, key + ".png"), "PNG")
        # 动画参考图：白底原图缩 512 jpg（视频首帧要白底完整图，不透明化）
        Image.open(src).convert("RGB").resize((512, 512), Image.Resampling.LANCZOS).save(
            os.path.join(REF_DIR, key + "_white.jpg"), "JPEG", quality=92)
        print("  OK %s (%s)" % (key, u["display"]))
        n_ok += 1
    print("完成：%d OK / %d FAIL" % (n_ok, n_fail))


if __name__ == "__main__":
    main()
