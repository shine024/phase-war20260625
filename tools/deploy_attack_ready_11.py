#!/usr/bin/env python3
"""部署 docs\重修改卡图\ 第二批11张已抠好透明底卡图（2026-08-19 准备攻击姿态批次）。

命名规则（两段不同）：
  - 编号卡 vis_enemy_NNN → enemy/vis_enemy_NNN.png + player/vis_player_NNN.png（翻转）
  - D段卡 card_id       → enemy/<id>.png + player/<id>.png（翻转，同名）

流程：裁剪内容边界 → 等比缩放 88% → 居中填充 512×512（AGENTS.md 硬约定）→ 落盘。
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "重修改卡图")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
OUT_SIZE = 512

# 源文件名 → (enemy侧文件名, player侧文件名)
FILES = {
    "vis_enemy_004": ("vis_enemy_004", "vis_player_004"),
    "vis_enemy_005": ("vis_enemy_005", "vis_player_005"),
    "vis_enemy_024": ("vis_enemy_024", "vis_player_024"),
    "vis_enemy_032": ("vis_enemy_032", "vis_player_032"),
    "vis_enemy_034": ("vis_enemy_034", "vis_player_034"),
    "vis_enemy_036": ("vis_enemy_036", "vis_player_036"),
    "vis_enemy_037": ("vis_enemy_037", "vis_player_037"),
    "vis_enemy_040": ("vis_enemy_040", "vis_player_040"),
    "vis_enemy_114": ("vis_enemy_114", "vis_player_114"),
    "ww1_inf_enfield": ("ww1_inf_enfield", "ww1_inf_enfield"),
    "ww1_inf_mp18_x": ("ww1_inf_mp18_x", "ww1_inf_mp18_x"),
}


def fit_square(img: Image.Image, size: int) -> Image.Image:
    """裁剪到内容边界 + 等比缩放到 size 方形（居中，88%留白）。"""
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
    only = set(sys.argv[1:])
    ok = fail = 0
    for src_name, (enemy_name, player_name) in FILES.items():
        if only and src_name not in only:
            continue
        src = os.path.join(SRC_DIR, f"{src_name}.png")
        if not os.path.exists(src):
            print(f"SKIP {src_name}: source not found")
            fail += 1
            continue
        try:
            img = Image.open(src)
            if img.mode != "RGBA":
                print(f"FAIL {src_name}: 不是透明底 (mode={img.mode})")
                fail += 1
                continue
            img = fit_square(img, OUT_SIZE)

            non_trans = sum(1 for p in img.getdata() if p[3] > 0)
            if non_trans < 500:
                print(f"FAIL {src_name}: 内容太少 ({non_trans}px)")
                fail += 1
                continue

            img.save(os.path.join(ENEMY_DIR, f"{enemy_name}.png"), "PNG")
            img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
                os.path.join(PLAYER_DIR, f"{player_name}.png"), "PNG")
            print(f"OK {src_name}: enemy/{enemy_name}.png + player/{player_name}.png ({non_trans}px)")
            ok += 1
        except Exception as e:
            print(f"FAIL {src_name}: {e}")
            fail += 1
    print(f"\nDone: {ok} OK, {fail} FAIL")
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
