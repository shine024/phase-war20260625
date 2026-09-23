#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W3 步骤 3/4 外科处置包（2026-09-14，用户三项裁决）。

A. 三张新部署卡图半透明接地阴影清除（001/075/garand，player+enemy+thumbs）
B. garand sheet_attack 帧修复：帧4(idx) 火光回贴枪口 + 帧0/1 白渍清除
C. fut_inf_c96 卡图占比 90% → tighten ×0.82（b4 外科同款）
D. _raw_tracks.png(+payload/resp) 零引用中间产物移出 assets/ → _anim_review/
全部先备份 _art_backup/*-preW3B-2026-09-14.png。
"""
import os
import shutil
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(r"F:\godot fair duet\_art_backup")


def bpath(name):
    return os.path.join(BACKUP, name + "-preW3B-2026-09-14.png")


def backup_file(src):
    dst = bpath(os.path.splitext(os.path.basename(src))[0])
    dst = dst.replace(".png", "") + os.path.splitext(src)[1]
    if os.path.exists(src) and not os.path.exists(dst):
        shutil.copy2(src, dst)
        print("  备份 → " + os.path.basename(dst))


# ---------------------------------------------------------------- A 接地清除
def grounding_clear(img: Image.Image) -> Image.Image:
    """底部连通半透明灰（阴影/白渍泛洪残迹）清除：
    floodable = a<235 且 bright<215，自底边洪泛，限底部 30%。不透明主体不受影响。"""
    arr = np.asarray(img.convert("RGBA")).astype(np.int16)
    h, w = arr.shape[:2]
    y0 = int(h * 0.70)
    a = arr[..., 3]
    bright = arr[..., :3].mean(-1)
    floodable = (a < 235) & (bright < 215)
    visited = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (h - 1, h - 2):
            if floodable[y, x]:
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
    arr[visited] = 0
    print("    接地清除 %d px" % n)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def make_thumb(src_png, dst_png, size):
    img = Image.open(src_png).convert("RGBA")
    if max(img.size) <= size:
        return "small"
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    img.save(dst_png)
    return "ok"


def part_a():
    print("== A. 接地阴影清除（3 张新卡）")
    names = ["vis_player_001", "vis_player_075", "ww2_arm_garand_para"]
    for name in names:
        print("  " + name)
        for side, base in (("player", os.path.join(ROOT, "assets", "card_icons", "player")),
                           ("enemy", os.path.join(ROOT, "assets", "card_icons", "enemy"))):
            p = os.path.join(base, name + ".png")
            backup_file(p)
            img = grounding_clear(Image.open(p))
            img.save(p, "PNG")
            make_thumb(p, os.path.join(ROOT, "assets", "card_icons", "_thumb256", side, name + ".png"), 256)
            make_thumb(p, os.path.join(ROOT, "assets", "card_icons", "_thumb384", side, name + ".png"), 384)


# ------------------------------------------------------------- B 雪碧图帧修复
def part_b():
    print("== B. garand sheet_attack 帧修复")
    p = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww2_arm_garand_para", "sheet_attack.png")
    backup_file(p)
    im = Image.open(p).convert("RGBA")
    FS = 256
    arr = np.asarray(im).copy()

    # --- 帧 idx4：火光星回贴枪口 ---
    fx0 = 4 * FS
    fr = arr[0:FS, fx0:fx0 + FS]
    r, g, b, a = fr[..., 0].astype(np.int16), fr[..., 1].astype(np.int16), fr[..., 2].astype(np.int16), fr[..., 3]
    warm = (r > 120) & (r > b + 40) & (a > 40)
    ys, xs = np.nonzero(warm)
    if len(xs) == 0:
        print("  帧4 火光未检出!")
        return
    sx0, sx1, sy0, sy1 = xs.min(), xs.max(), ys.min(), ys.max()
    star = fr[sy0:sy1 + 1, sx0:sx1 + 1].copy()
    # 枪口位置（目视核定）：枪管尖 (128,62)，星形右缘搭接枪口 6px
    target_cx, target_cy = 112, 62
    sw, sh = sx1 - sx0 + 1, sy1 - sy0 + 1
    dx = int(target_cx - (sx0 + sw / 2.0))
    dy = int(target_cy - (sy0 + sh / 2.0))
    fr[sy0:sy1 + 1, sx0:sx1 + 1] = 0  # 原位清除
    for yy in range(sh):
        for xx in range(sw):
            tx, ty = sx0 + xx + dx, sy0 + yy + dy
            if 0 <= tx < FS and 0 <= ty < FS:
                fr[ty, tx] = star[yy, xx]
    arr[0:FS, fx0:fx0 + FS] = fr
    print("  帧4 火光 bbox(%d,%d)-(%d,%d) 平移(%+d,%+d) → 枪口" % (sx0, sy0, sx1, sy1, dx, dy))

    # --- 帧 idx0/1：白色涂抹渍清除（框内亮白低色度连通体）---
    for idx, box in ((0, (40, 25, 200, 125)), (1, (60, 30, 215, 110))):
        fx0 = idx * FS
        fr = arr[0:FS, fx0:fx0 + FS]
        r, g, b, a = fr[..., 0].astype(np.int16), fr[..., 1].astype(np.int16), fr[..., 2].astype(np.int16), fr[..., 3]
        bright = fr[..., :3].mean(-1)
        chroma = fr[..., :3].max(-1) - fr[..., :3].min(-1)
        cand = (bright > 165) & (chroma < 45) & (a > 0)
        mask = np.zeros((FS, FS), bool)
        x0, y0, x1, y1 = box
        mask[y0:y1, x0:x1] = cand[y0:y1, x0:x1]
        # 连通体过滤：只清 >60px 的渍块（防误伤细碎高光）
        seen = np.zeros_like(mask)
        cleared = 0
        for yy in range(FS):
            for xx in range(FS):
                if mask[yy, xx] and not seen[yy, xx]:
                    comp = deque([(xx, yy)])
                    seen[yy, xx] = True
                    pix = []
                    while comp:
                        cx, cy = comp.popleft()
                        pix.append((cx, cy))
                        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            nx, ny = cx + ddx, cy + ddy
                            if 0 <= nx < FS and 0 <= ny < FS and mask[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                comp.append((nx, ny))
                    if len(pix) > 60:
                        for cx, cy in pix:
                            fr[cy, cx] = 0
                        cleared += len(pix)
        arr[0:FS, fx0:fx0 + FS] = fr
        print("  帧%d 白渍清除 %d px" % (idx, cleared))

    Image.fromarray(arr, "RGBA").save(p, "PNG")
    print("  sheet_attack 已回写")


# ------------------------------------------------------------- C c96 微缩放
def part_c():
    print("== C. fut_inf_c96 tighten ×0.82")
    for side, base in (("player", "player"), ("enemy", "enemy")):
        p = os.path.join(ROOT, "assets", "card_icons", base, "fut_inf_c96.png")
        backup_file(p)
        img = Image.open(p).convert("RGBA")
        bbox = img.getbbox()
        core = img.crop(bbox)
        w, h = core.size
        nw, nh = max(1, int(w * 0.82)), max(1, int(h * 0.82))
        core = core.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
        canvas.paste(core, ((img.size[0] - nw) // 2, (img.size[1] - nh) // 2), core)
        # 保持脚底位置：贴底对齐（脚锚口径：底缘为接地点）
        ys = np.nonzero(np.asarray(canvas)[..., 3] > 10)[0]
        old_bottom = np.nonzero(np.asarray(img)[..., 3] > 10)[0].max()
        cur_bottom = ys.max()
        shifty = int(old_bottom - cur_bottom)
        if shifty > 0:
            canvas = Image.fromarray(np.roll(np.asarray(canvas), shifty, axis=0), "RGBA")
        canvas.save(p, "PNG")
        arr = np.asarray(canvas)
        ysc, xsc = np.nonzero(arr[..., 3] > 10)
        ratio = max((xsc.max() - xsc.min()) / 512, (ysc.max() - ysc.min()) / 512)
        print("  %s 新占比 %.0f%%" % (side, ratio * 100))
        make_thumb(p, os.path.join(ROOT, "assets", "card_icons", "_thumb256", side, "fut_inf_c96.png"), 256)
        make_thumb(p, os.path.join(ROOT, "assets", "card_icons", "_thumb384", side, "fut_inf_c96.png"), 384)


# ------------------------------------------------------- D _raw_tracks 移出
def part_d():
    print("== D. _raw_tracks 中间产物移出 assets/")
    dst_dir = os.path.join(ROOT, "_anim_review", "raw_decals_2026-09-14")
    os.makedirs(dst_dir, exist_ok=True)
    base = os.path.join(ROOT, "assets", "ground_dressing", "_raw_tracks")
    for ext in (".png", ".png.import", ".payload.json", ".resp.json"):
        src = base + ext
        if os.path.exists(src):
            shutil.move(src, os.path.join(dst_dir, "_raw_tracks" + ext))
            print("  移动 _raw_tracks" + ext)
    # 残留 .import 清理（png 已走，import 文件成为孤儿）
    orphan = base + ".png.import"
    if os.path.exists(orphan):
        os.remove(orphan)
        print("  清孤儿 import")


if __name__ == "__main__":
    for part in sys.argv[1:] or ["a", "b", "c", "d"]:
        {"a": part_a, "b": part_b, "c": part_c, "d": part_d}[part.lower()]()
    print("\nDONE")
