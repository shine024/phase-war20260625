#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""部署 v26 新飞机系列卡图（8 张，era1-4 轰炸机/多用途，D 段池）：
  - 白底转透明 + 缩放512 + 复制到 enemy/ + 水平翻转到 player/
  - 同步生成 _thumb256 / _thumb384 双侧缩略图（列表/战场管线）
与项目现有命名 id 卡图（fut_air_drone 等）一致：512x512 RGBA 透明背景。
源图：docs/待生成卡图_v26飞机/（agnes-image-2.0-flash 生成于 v26）。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成卡图_v26飞机")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
THUMB256 = os.path.join(ROOT, "assets", "card_icons", "_thumb256")
THUMB384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384")
OUT_SIZE = 512

# v26 新飞机（manifest D 段，enemy_only）
FILES = [
    "ww2_air_bomber",          # B-17 空中堡垒
    "ww2_air_dive_bomber",     # Ju 87 斯图卡
    "cold_air_strike_fighter", # F-111 土豚
    "cold_air_bomber",         # 图-95 熊式
    "mod_air_multirole",       # F-15E 攻击鹰
    "mod_air_bomber",          # B-52 同温层堡垒
    "fut_air_stealth_multirole",  # 六代机制空型
    "fut_air_stealth_bomber",     # B-21 突袭者
]


def white_to_alpha(img: Image.Image) -> Image.Image:
    """白底转透明（容差处理近白边缘）。"""
    import numpy as np
    rgb = img.convert("RGB")
    arr = np.array(rgb, dtype=np.int16)
    brightness = (arr[:, :, 0] + arr[:, :, 1] + arr[:, :, 2]) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    out = np.dstack([
        arr[:, :, 0].astype(np.uint8),
        arr[:, :, 1].astype(np.uint8),
        arr[:, :, 2].astype(np.uint8),
        alpha,
    ])
    return Image.fromarray(out, "RGBA")


def fit_square(img: Image.Image, size: int) -> Image.Image:
    """裁剪到内容边界 + 等比缩放到 size x size（居中，88%留白）。"""
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


def make_thumb(src_png: str, dst_png: str, size: int) -> str:
    img = Image.open(src_png).convert("RGBA")
    if max(img.size) <= size:
        return "small"
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    img.save(dst_png)
    return "ok"


def main():
    print(f"Deploying {len(FILES)} v26 aircraft card icons...")
    print(f"Source: {SRC_DIR}\n")
    ok = 0
    fail = 0
    for fname in FILES:
        src = os.path.join(SRC_DIR, f"{fname}.png")
        if not os.path.exists(src):
            print(f"SKIP {fname}: source not found at {src}")
            fail += 1
            continue
        try:
            img = Image.open(src)
            img = white_to_alpha(img)
            img = fit_square(img, OUT_SIZE)

            # 校验：非透明像素足够多（防全透明空图，gen_rq7_icon 先例）
            alpha = img.getchannel("A")
            non_trans = sum(1 for p in alpha.getdata() if p > 0)
            if non_trans < 500:
                print(f"FAIL {fname}: too few non-transparent pixels ({non_trans})")
                fail += 1
                continue

            enemy_path = os.path.join(ENEMY_DIR, f"{fname}.png")
            img.save(enemy_path, "PNG")
            player_path = os.path.join(PLAYER_DIR, f"{fname}.png")
            flipped = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            flipped.save(player_path, "PNG")

            # 缩略图（双侧 256 + 384）
            t = []
            for sub in ("enemy", "player"):
                src_full = os.path.join(ENEMY_DIR if sub == "enemy" else PLAYER_DIR, f"{fname}.png")
                t.append(make_thumb(src_full, os.path.join(THUMB256, sub, f"{fname}.png"), 256))
                t.append(make_thumb(src_full, os.path.join(THUMB384, sub, f"{fname}.png"), 384))
            print(f"OK {fname}: enemy+player 512x512 ({non_trans}px) thumbs={t}")
            ok += 1
        except Exception as e:
            print(f"FAIL {fname}: {e}")
            fail += 1

    print(f"\nDone: {ok} OK, {fail} FAIL")
    if fail > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
