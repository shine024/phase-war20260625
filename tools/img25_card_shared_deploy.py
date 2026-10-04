# -*- coding: utf-8 -*-
"""img25 换卡图·共享组部署（10-01 深夜）。

共享 vis_player 的 7 个重生成候选不能直接覆盖共享 ID（会波及同图单位），
改为 player/<unit>.png 专属副本 + ui_asset_loader.gd PLAYER_ICON_OVERRIDE 指行。
共享方（saint/sam7/stryker_mgs/fort/77mm/scout_drone/hound/rolls/medium）原图原映射不动，零波及。

加工规格对齐 Agent C 已部署 4 卡：1024 raw 白底 → 边界连通键控 → 裁内容 →
最长边缩到 450px → 512×512 RGBA 居中 → LANCZO 缩略图 256/384 双侧。
"""
import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CR = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "_card_regen")
PDIR = os.path.join(ROOT, "assets", "card_icons", "player")
T256 = os.path.join(ROOT, "assets", "card_icons", "_thumb256", "player")
T384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384", "player")

# (unit, raw 名) —— 共享组 7 候选
ITEMS = [
    ("mod_stinger", "mod_stinger"),
    ("mod_stryker_m2", "mod_stryker_m2"),
    ("platform_modern_stealth", "platform_modern_stealth"),
    ("ww1_105mm", "ww1_105mm"),
    ("ww1_a7v", "ww1_a7v"),
    ("ww1_mark4", "ww1_mark4"),
    ("ww1_lanchest", "ww1_lanchest"),
]
MAXDIM = 450   # Agent C 成品内容高 449
KEY_TOL = 20   # 白底容差


def key_white(im: Image.Image) -> Image.Image:
    """边界连通近白键控（非全局色匹配，保住武器高光/白涂装内部）。"""
    rgb = np.asarray(im.convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    near_white = (rgb > 255 - KEY_TOL).all(axis=2)
    bg = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white[y, x] and not bg[y][x]:
                bg[y][x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near_white[y, x] and not bg[y][x]:
                bg[y][x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near_white[ny, nx] and not bg[ny][nx]:
                bg[ny][nx] = True
                q.append((ny, nx))
    a = np.where(np.array(bg), 0, 255).astype("uint8")
    out = im.convert("RGBA")
    out.putalpha(Image.fromarray(a))
    return out


def process(unit: str, raw: str) -> str:
    src = os.path.join(CR, f"{raw}__raw.png")
    im = key_white(Image.open(src))
    bbox = im.getchannel("A").getbbox()
    im = im.crop(bbox)
    s = max(im.size)
    if s > MAXDIM:
        im = im.resize((round(im.width * MAXDIM / s), round(im.height * MAXDIM / s)), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(im, ((512 - im.width) // 2, (512 - im.height) // 2), im)
    dst = os.path.join(PDIR, f"{unit}.png")
    bak = dst + ".pre_regen.bak"
    if os.path.exists(dst) and not os.path.exists(bak):
        os.replace(dst, bak)  # 首次覆盖才备份
    canvas.save(dst)
    for d, size in ((T256, 256), (T384, 384)):
        os.makedirs(d, exist_ok=True)
        canvas.copy().resize((size, size), Image.LANCZOS).save(os.path.join(d, f"{unit}.png"))
    return dst


def main():
    for unit, raw in ITEMS:
        p = process(unit, raw)
        print("OK", unit, os.path.basename(p))


if __name__ == "__main__":
    main()
