#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复存量卡图边距问题（对齐 88% 留白正方形约定）：
- 全出血贴边（512 内容顶边）：裁边 → 缩 88% → 居中填充 512
- 1024 原图漏部署（E 段堡垒等）：首次走 fit_square 部署到 512
- 临界（<20px 边距）：一并归一
每张同步：enemy 保存 + player 水平翻转重生成 + 384 缩略重生成。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER = os.path.join(ROOT, "assets", "card_icons", "player")
THUMB384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384")

# audit_card_margins.py 的扫描结果
FILES = [
    "vis_enemy_009", "vis_enemy_010", "vis_enemy_028", "vis_enemy_032", "vis_enemy_033",  # 全出血
    "vis_enemy_034",                                                                      # 临界 13px
    "fut_inf_x9", "vis_enemy_017", "vis_enemy_020", "vis_enemy_021", "vis_enemy_022",
    "vis_enemy_024", "vis_enemy_074", "vis_enemy_075", "vis_enemy_076", "vis_enemy_077",
    "vis_enemy_078", "vis_enemy_079", "vis_enemy_080", "vis_enemy_081",                    # 1024 漏部署
]


def fit_square(img: Image.Image, size: int = 512) -> Image.Image:
    """与 deploy_card_icons_11 一致：裁边 + 88% 留白 + 居中填充正方形。"""
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


def make_thumb(src_png: str, size: int = 384) -> None:
    img = Image.open(src_png).convert("RGBA")
    img.thumbnail((size, size), Image.LANCZOS)
    subdir = "player" if os.sep + "player" + os.sep in src_png else "enemy"
    out_dir = os.path.join(THUMB384, subdir)
    os.makedirs(out_dir, exist_ok=True)
    img.save(os.path.join(out_dir, os.path.basename(src_png)))


def main() -> None:
    ok = fail = 0
    for fname in FILES:
        src = os.path.join(ENEMY, fname + ".png")
        try:
            img = fit_square(Image.open(src))
            img.save(src, "PNG")
            player_fname = fname.replace("vis_enemy_", "vis_player_")
            player_path = os.path.join(PLAYER, player_fname + ".png")
            img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(player_path, "PNG")
            make_thumb(src)
            make_thumb(player_path)
            print("fixed:", fname)
            ok += 1
        except Exception as e:
            print("FAIL:", fname, e)
            fail += 1
    print(f"\nDone: {ok} ok, {fail} fail")


if __name__ == "__main__":
    main()
