#!/usr/bin/env python3
"""部署 docs\重修改卡图\ 下6张已抠好的透明底卡图（2026-08-18 准备攻击姿态批次）。

源图已是 RGBA 透明底（用户手动抠图），跳过白转透明，只做：
  裁剪内容边界 → 等比缩放 88% → 居中填充 512×512 正方形（AGENTS.md 硬约定）
  → enemy/ 原图（朝左）+ player/ 水平翻转版
  → drop_* 4张额外落盘根目录 assets/card_icons/（三处部署约定，见 generate_drop_card_icons.py）
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "重修改卡图")
ICONS_DIR = os.path.join(ROOT, "assets", "card_icons")
ENEMY_DIR = os.path.join(ICONS_DIR, "enemy")
PLAYER_DIR = os.path.join(ICONS_DIR, "player")
OUT_SIZE = 512

FILES = [
    "drop_smg_mk2",
    "drop_phase_lance",
    "drop_thunder_field",
    "drop_railgun",
    "fut_swarm",
    "fut_nano_drone",
]
ROOT_DEPLOY = {"drop_smg_mk2", "drop_phase_lance", "drop_thunder_field", "drop_railgun"}


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
    for fname in FILES:
        if only and fname not in only:
            continue
        src = os.path.join(SRC_DIR, f"{fname}.png")
        if not os.path.exists(src):
            print(f"SKIP {fname}: source not found")
            fail += 1
            continue
        try:
            img = Image.open(src)
            if img.mode != "RGBA":
                print(f"FAIL {fname}: 不是透明底 (mode={img.mode})，本脚本只部署已抠好的图")
                fail += 1
                continue
            img = fit_square(img, OUT_SIZE)

            non_trans = sum(1 for p in img.getdata() if p[3] > 0)
            if non_trans < 500:
                print(f"FAIL {fname}: 内容太少 ({non_trans}px)")
                fail += 1
                continue

            img.save(os.path.join(ENEMY_DIR, f"{fname}.png"), "PNG")
            img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
                os.path.join(PLAYER_DIR, f"{fname}.png"), "PNG")
            extra = ""
            if fname in ROOT_DEPLOY:
                img.save(os.path.join(ICONS_DIR, f"{fname}.png"), "PNG")
                extra = " + 根目录"
            print(f"OK {fname}: enemy/ + player/{extra} ({non_trans}px)")
            ok += 1
        except Exception as e:
            print(f"FAIL {fname}: {e}")
            fail += 1
    print(f"\nDone: {ok} OK, {fail} FAIL")
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
