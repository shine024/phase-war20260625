#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W3 步骤 4 部署轮（2026-09-14）：三张重生成原图 → 正式卡图。

链路（§6.1 生成后流程）：garand 肩章星条旗修补（禁则 3）→ 灰底接地阴影清除
（底部连通中性灰泛白，色度门控防误吃蓝灰涂装）→ white_to_alpha（_deploy_r5_jets
同式）→ fit_square 512×512 88% 留白 → player 直出 / enemy FLIP_LEFT_RIGHT
（宪法口径：生成朝右）→ _thumb256/_thumb384 双侧。
原图先备份 _art_backup/*-preW3B-2026-09-14.png（部署件六张）。
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, "docs", "待生成卡图_批4x_收尾2026-09-14")
PLAYER = os.path.join(ROOT, "assets", "card_icons", "player")
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy")
THUMB256 = os.path.join(ROOT, "assets", "card_icons", "_thumb256")
THUMB384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"
OUT_SIZE = 512

UNITS = ["vis_player_001", "vis_player_075", "ww2_arm_garand_para"]
# garand 星条旗臂章区（raw 坐标，目视核定）——用周边袖色+噪声修补
INPAINT = {
    "ww2_arm_garand_para": (514, 204, 572, 250),
}


def backup(name):
    for side in ("player", "enemy"):
        src = os.path.join(ROOT, "assets", "card_icons", side, name + ".png")
        dst = os.path.join(BACKUP_DIR, "%s_%s-preW3B-2026-09-14.png" % (side.replace("player", "vis_player").replace("enemy", "vis_enemy"), name)) \
            if False else os.path.join(BACKUP_DIR, "%s-%s-preW3B-2026-09-14.png" % (side, name))
        if os.path.exists(src) and not os.path.exists(dst):
            with open(src, "rb") as fi, open(dst, "wb") as fo:
                fo.write(fi.read())


def inpaint_flag(img, box):
    """星条旗臂章修补：逐行取旗区左右外侧袖色线性插值 + 噪声 + 轻模糊。"""
    x0, y0, x1, y1 = box
    arr = np.asarray(img.convert("RGB")).astype(np.float32)
    pad = 6
    for y in range(y0, y1):
        lx = max(0, x0 - pad)
        rx = min(arr.shape[1] - 1, x1 + pad)
        lc = arr[y, lx - 2:lx + 1].mean(axis=0) if lx >= 1 else arr[y, rx + 1:rx + 4].mean(axis=0)
        rc = arr[y, rx + 1:rx + 4].mean(axis=0)
        w = np.linspace(0, 1, x1 - x0)[:, None]
        arr[y, x0:x1] = lc * (1 - w) + rc * w
    rng = np.random.default_rng(20260914)
    arr[y0:y1, x0:x1] += rng.normal(0, 5.0, (y1 - y0, x1 - x0, 3))
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    # 轻模糊羽化修补区（3px 边带）
    from PIL import ImageFilter
    blur = out.filter(ImageFilter.GaussianBlur(1.6))
    mask = Image.new("L", out.size, 0)
    marr = np.zeros((out.size[1], out.size[0]), np.uint8)
    marr[y0:y1, x0:x1] = 255
    mask = Image.fromarray(marr).filter(ImageFilter.GaussianBlur(2.0))
    out = Image.composite(blur, out, mask)
    return out


def clear_ground_shadow(img):
    """底部连通中性灰（阴影）泛白：色度门控（|max-min|<22）+亮度带[120,242]，
    从底边洪泛，限底部 30%。蓝灰涂装（色度大）不受影响。"""
    arr = np.asarray(img.convert("RGB")).astype(np.int16)
    h, w = arr.shape[:2]
    y0 = int(h * 0.70)
    chroma = arr.max(-1) - arr.min(-1)
    bright = arr.mean(-1)
    floodable = (chroma < 22) & (bright >= 120) & (bright <= 242)
    visited = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (h - 1, h - 2, h - 3):
            if floodable[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if y0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and floodable[ny, nx]:
                visited[ny, nx] = True
                q.append((nx, ny))
    n = int(visited.sum())
    arr[visited] = 255
    print("    阴影泛白 %d px" % n)
    return Image.fromarray(arr.astype(np.uint8))


def white_to_alpha(img):
    rgb = img.convert("RGB")
    arr = np.array(rgb, dtype=np.int16)
    brightness = (arr[:, :, 0] + arr[:, :, 1] + arr[:, :, 2]) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    out = np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                     arr[:, :, 2].astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def fit_square(img, size):
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


def make_thumb(src_png, dst_png, size):
    img = Image.open(src_png).convert("RGBA")
    if max(img.size) <= size:
        return "small"
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    img.save(dst_png)
    return "ok"


def warm_ratio(arr):
    r = arr[..., 0].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    a = arr[..., 3]
    return float(((r > b + 30) & (r > 90) & (a > 60)).mean())


def main() -> int:
    os.makedirs(BACKUP_DIR, exist_ok=True)
    ok = 0
    for name in UNITS:
        src = os.path.join(RAW_DIR, name + ".png")
        if not os.path.exists(src):
            print("SKIP %s: raw missing" % name)
            continue
        print(name)
        backup(name)
        img = Image.open(src)
        if name in INPAINT:
            img = inpaint_flag(img, INPAINT[name])
            print("    星条旗臂章已修补")
        img = clear_ground_shadow(img)
        img = white_to_alpha(img)
        img = fit_square(img, OUT_SIZE)
        alpha = img.getchannel("A")
        non_trans = sum(1 for p in alpha.getdata() if p > 0)
        if non_trans < 500:
            print("    FAIL: 全透明")
            continue
        player_path = os.path.join(PLAYER, name + ".png")
        img.save(player_path, "PNG")
        enemy_path = os.path.join(ENEMY, name + ".png")
        img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(enemy_path, "PNG")
        thumbs = []
        for sub, base in (("player", PLAYER), ("enemy", ENEMY)):
            thumbs.append(make_thumb(os.path.join(base, name + ".png"),
                                     os.path.join(THUMB256, sub, name + ".png"), 256))
            thumbs.append(make_thumb(os.path.join(base, name + ".png"),
                                     os.path.join(THUMB384, sub, name + ".png"), 384))
        arr = np.asarray(img)
        ys, xs = np.nonzero(arr[..., 3] > 10)
        ratio = max((xs.max() - xs.min()) / 512, (ys.max() - ys.min()) / 512)
        print("    OK 512x512 暖区 %.1f%% 占比 %.0f%% thumbs=%s"
              % (warm_ratio(arr) * 100, ratio * 100, thumbs))
        ok += 1
    print("\nDeployed %d/3" % ok)
    return 0 if ok == 3 else 1


if __name__ == "__main__":
    sys.exit(main())
