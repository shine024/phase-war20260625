#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""部署 7 张我方卡图：白底转透明 + 缩放512 + 复制到 enemy/ + 水平翻转到 player/。

源图：docs/待生成卡图_7张我方卡/<中文名>.png（白底 1024x1024）
输出：
  assets/card_icons/enemy/vis_enemy_NNN.png  （原图朝左，作备份）
  assets/card_icons/player/vis_player_NNN.png（水平翻转朝右，我方实际使用）

编号分配（088-094 段，预留段空闲）：
  088 37mm高射炮      ww1_37mm
  089 标枪导弹兵      mod_javelin
  090 毒刺导弹兵      mod_stinger
  091 攻击无人机      fut_attack_drone
  092 纳米修复机      fut_nano_drone
  093 空天战斗机      fut_space_fighter
  094 隐形轰炸机      fut_stealth_bomber
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成卡图_7张我方卡")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
OUT_SIZE = 512

# 中文名源文件 → 编号
FILES = [
    ("37mm高射炮", 88),
    ("标枪导弹兵", 89),
    ("毒刺导弹兵", 90),
    ("攻击无人机", 91),
    ("纳米修复机", 92),
    ("空天战斗机", 93),
    ("隐形轰炸机", 94),
]


def white_to_alpha(img: Image.Image) -> Image.Image:
    """白底转透明（容差处理近白边缘）。"""
    rgb = img.convert("RGB")
    try:
        import numpy as np
        arr = np.array(rgb, dtype=np.int16)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
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
    print("Deploying 7 player card icons...\n")
    ok = 0
    fail = 0
    for display, num in FILES:
        src = os.path.join(SRC_DIR, display + ".png")
        if not os.path.exists(src):
            print("  SKIP %s (编号%d): source not found" % (display, num))
            fail += 1
            continue

        fname = "vis_enemy_%03d" % num
        try:
            img = Image.open(src)
            img = white_to_alpha(img)
            img = fit_square(img, OUT_SIZE)

            # enemy 版（原图）
            enemy_path = os.path.join(ENEMY_DIR, fname + ".png")
            img.save(enemy_path, "PNG")

            # player 版（水平翻转）
            player_fname = "vis_player_%03d" % num
            player_path = os.path.join(PLAYER_DIR, player_fname + ".png")
            flipped = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            flipped.save(player_path, "PNG")

            print("  OK %s -> enemy/%s.png + player/%s.png" % (display, fname, player_fname))
            ok += 1
        except Exception as e:
            print("  FAIL %s (编号%d): %s" % (display, num, e))
            fail += 1

    print("\nDone: %d OK, %d FAIL" % (ok, fail))
    print("Enemy dir: " + ENEMY_DIR)
    print("Player dir: " + PLAYER_DIR)


if __name__ == "__main__":
    main()
