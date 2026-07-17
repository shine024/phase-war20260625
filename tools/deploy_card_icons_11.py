#!/usr/bin/env python3
"""部署 11 张卡图：白底转透明 + 缩放512 + 复制到 enemy/ + 水平翻转到 player/。
与项目现有 vis_enemy_001~081 一致：512x512 RGBA 透明背景。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成卡图_11张")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
OUT_SIZE = 512

FILES = [
    "vis_enemy_082", "vis_enemy_083", "vis_enemy_084",
    "vis_enemy_085", "vis_enemy_086", "vis_enemy_087",
    "vis_enemy_110", "vis_enemy_111", "vis_enemy_112",
    "vis_enemy_113", "vis_enemy_114",
]


def white_to_alpha(img: Image.Image) -> Image.Image:
    """白底转透明（容差处理近白边缘）。"""
    rgb = img.convert("RGB")
    try:
        import numpy as np
        arr = np.array(rgb, dtype=np.int16)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
        # 距纯白的距离（越白 alpha 越低）
        # 250+ 视为背景白
        brightness = (r + g + b) / 3.0
        # 平滑过渡：brightness 240→alpha 0, brightness 200→alpha 255
        alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
        out = np.dstack([
            arr[:, :, 0].astype(np.uint8),
            arr[:, :, 1].astype(np.uint8),
            arr[:, :, 2].astype(np.uint8),
            alpha,
        ])
        return Image.fromarray(out, "RGBA")
    except ImportError:
        px = rgb.load()
        w, h = rgb.size
        out = Image.new("RGBA", (w, h))
        opx = out.load()
        for y in range(h):
            for x in range(w):
                r, g, b = px[x, y]
                brightness = (r + g + b) / 3.0
                if brightness >= 240:
                    a = 0
                elif brightness <= 200:
                    a = 255
                else:
                    a = int((240 - brightness) / 40 * 255)
                opx[x, y] = (r, g, b, max(0, min(255, a)))
        return out


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


def main():
    print("Deploying 11 card icons...\n")
    ok = 0
    fail = 0
    for fname in FILES:
        src = os.path.join(SRC_DIR, fname + ".png")
        if not os.path.exists(src):
            print(f"  SKIP {fname}: source not found")
            fail += 1
            continue

        try:
            img = Image.open(src)
            # 白底转透明
            img = white_to_alpha(img)
            # 裁剪+缩放到 512x512
            img = fit_square(img, OUT_SIZE)

            # enemy 版（原图）
            enemy_path = os.path.join(ENEMY_DIR, fname + ".png")
            img.save(enemy_path, "PNG")

            # player 版（水平翻转）
            player_fname = fname.replace("vis_enemy_", "vis_player_")
            player_path = os.path.join(PLAYER_DIR, player_fname + ".png")
            flipped = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            flipped.save(player_path, "PNG")

            print(f"  OK {fname} -> enemy/{fname}.png + player/{player_fname}.png")
            ok += 1
        except Exception as e:
            print(f"  FAIL {fname}: {e}")
            fail += 1

    print(f"\nDone: {ok} OK, {fail} FAIL")
    print(f"Enemy dir: {ENEMY_DIR}")
    print(f"Player dir: {PLAYER_DIR}")


if __name__ == "__main__":
    main()
