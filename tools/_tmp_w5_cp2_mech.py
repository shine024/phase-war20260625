# -*- coding: utf-8 -*-
"""W5 CP-2 机械项处置（2026-09-14）。

A. 成片接地阴影外科清除 ×10（§11.9 组3，W3-B grounding_clear 同款：
   底边洪泛 + 限底部 30% + 只清半透明灰，不透明主体不受影响）；
B. fe_frontier_veteran 朝向修复：player := flip(player)（player 应朝右），
   顺带跑一遍接地清除（该图有淡接地痕）。
每张改后 enemy := flip(player) 同步 + 双侧 thumbs 256/384。
锚点刷新由外部 generate_card_foot_anchors.py 执行（alpha 底缘变化后必须重跑）。
"""
import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDIR = os.path.join(ROOT, "assets", "card_icons", "player")
EDIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
BK = os.path.join(ROOT, "_art_backup")
os.makedirs(BK, exist_ok=True)

SHADOW_C = [
    "vis_player_003", "vis_player_039", "vis_player_041", "vis_player_042",
    "vis_player_089", "vis_player_092", "vis_xeno_templar", "vis_xeno_thing",
    "ww1_arm_rolls_mk2", "ww1_sup_vickers",
]
FLIP_FIX = ["fe_frontier_veteran"]


def backup(p):
    dst = os.path.join(BK, os.path.splitext(os.path.basename(p))[0] + "-preCP2A-2026-09-14.png")
    if not os.path.exists(dst):
        np_img = np.asarray(Image.open(p).convert("RGBA"))
        Image.fromarray(np_img).save(dst)


def enemy_name(pid):
    if pid.startswith("vis_player_"):
        return "vis_enemy_" + pid[len("vis_player_"):]
    return pid


def grounding_clear(img, bright_cap=215):
    arr = np.asarray(img.convert("RGBA")).astype(np.int16)
    h, w = arr.shape[:2]
    y0 = int(h * 0.70)
    a = arr[..., 3]
    bright = arr[..., :3].mean(-1)
    floodable = (a < 235) & (bright < bright_cap)
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
    return Image.fromarray(arr.astype(np.uint8), "RGBA"), n


def make_thumbs(png, name):
    for size, d in ((256, "_thumb256"), (384, "_thumb384")):
        img = Image.open(png).convert("RGBA")
        if max(img.size) > size:
            img.thumbnail((size, size), Image.Resampling.LANCZOS)
        out = os.path.join(ROOT, "assets", "card_icons", d, os.path.basename(os.path.dirname(png)), name + ".png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        img.save(out)


def shadow_px(png):
    """底部 20% 的半透明灰像素计数（处置前后对比指标）。"""
    arr = np.asarray(Image.open(png).convert("RGBA")).astype(np.int16)
    h = arr.shape[0]
    zone = arr[int(h * 0.80):, :, :]
    a = zone[..., 3]
    bright = zone[..., :3].mean(-1)
    return int(((a > 0) & (a < 235) & (bright < 230)).sum())


def process(pid, do_clear=True, do_flip=False):
    pp = os.path.join(PDIR, pid + ".png")
    ep = os.path.join(EDIR, enemy_name(pid) + ".png")
    assert os.path.exists(pp) and os.path.exists(ep), pid
    backup(pp)
    backup(ep)
    before = shadow_px(pp)

    img = Image.open(pp).convert("RGBA")
    if do_flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if do_clear:
        img, n = grounding_clear(img)
    else:
        n = 0
    img.save(pp, "PNG")

    # enemy := flip(player)
    arr = np.asarray(Image.open(pp).convert("RGBA"))
    Image.fromarray(arr[:, ::-1]).save(ep)

    make_thumbs(pp, pid)
    make_thumbs(ep, enemy_name(pid))
    after = shadow_px(pp)
    ok = bool((np.asarray(Image.open(ep).convert("RGBA")) == np.asarray(Image.open(pp).convert("RGBA"))[:, ::-1]).all())
    print("%-28s 阴影像素 %6d -> %6d (清除 %6d) 镜像=%s" % (pid, before, after, n, ok))
    return before, after


def main():
    total_before = total_after = 0
    for pid in SHADOW_C:
        b, a = process(pid, do_clear=True)
        total_before += b
        total_after += a
    for pid in FLIP_FIX:
        b, a = process(pid, do_clear=True, do_flip=True)
        total_before += b
        total_after += a
    print("合计底部半透明灰 %d -> %d" % (total_before, total_after))


if __name__ == "__main__":
    main()
