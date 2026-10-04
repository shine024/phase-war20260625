# -*- coding: utf-8 -*-
"""img25 终版 finalize（2026-10-01）：按终审决定把 R 掷转正为验收物。

用法:
    python tools/img25_finalize.py --decisions <json> [--dry-run]

决定 JSON（staging/_finalize_decisions.json）:
    { "<key>": {"roll": "R2", "flips": [1,4,5]}, ... }
    roll  = 选中的掷次（R1/R2/R3）；flips = 需水平翻正的格（0 基：0..5）
流程: R 版转正 → flips 翻格 → 品红清渍 → 垂直注册（滤焰最大连通域对齐 c1）→ 预览重建。
"""
import argparse
import json
import os
from collections import deque

from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ST = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
F = 832


def cell_of(im, i):
    x0, y0 = (i % 3) * F, (i // 3) * F
    return im.crop((x0, y0, x0 + F, y0 + F))


def depink_erase(im):
    # b-g>40（10-01 加严，原 >10 在 ak47 脸缘啃掉 6.2k px 暖调皮肤高光；
    # 真品红残留 b-g 通常 >70，不受影响）
    a = np.asarray(im).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    pink = (al > 8) & (r - g > 40) & (b - g > 40)
    n = int(pink.sum())
    if n:
        a[:, :, 3] = np.where(pink, 0, al)
        im = Image.fromarray(a.astype('uint8'))
    return im, n


def body_mask(cell):
    a = np.asarray(cell)
    r, g, b, al = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int), a[:, :, 3]
    body = al > 8
    flame = (r > 140) & (r - b > 60)
    light = (np.minimum(np.minimum(r, g), b) > 150) & \
            (np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b) < 40)
    return body & ~flame & ~light


def largest_cc_bbox(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=int)
    best = None
    bestn = 0
    for yy in range(h):
        for xx in range(w):
            if mask[yy, xx] and lab[yy, xx] == 0:
                lab[yy, xx] = 1
                dq = deque([(yy, xx)])
                n = 0
                x0 = x1 = xx
                y0 = y1 = yy
                while dq:
                    y, x = dq.popleft()
                    n += 1
                    if x < x0: x0 = x
                    if x > x1: x1 = x
                    if y < y0: y0 = y
                    if y > y1: y1 = y
                    for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = 1
                            dq.append((ny, nx))
                if n > bestn:
                    bestn, best = n, (x0, y0, x1, y1)
    return best


def body_right_h(cell, right_frac=0.40):
    """右 40% 窗口机身高 + 主体 bbox（嫁接等高用）。"""
    bb = largest_cc_bbox(body_mask(cell))
    if bb is None:
        return None
    x0, y0, x1, y1 = bb
    return y1 - y0, (x0, y0, x1, y1)


def graft_cell(im, cell_idx, donor_roll, key, ref_idx=0):
    """借格：donor 格按机身等高缩放后右下锚定贴入 cell_idx（0 基）。"""
    dp = os.path.join(ST, "%s_%s_attack_sheet_832.png" % (key, donor_roll))
    dc = cell_of(Image.open(dp).convert('RGBA'), cell_idx)
    rc = cell_of(im, cell_idx)
    refc = cell_of(im, ref_idx)
    rh = body_right_h(refc)
    dh = body_right_h(dc)
    if rh is None or dh is None:
        print("  [%s] 借格 c%d 失败：主体测不到" % (key, cell_idx + 1))
        return
    sc = rh[0] / dh[0]
    ds = dc.resize((int(F * sc), int(F * sc)), Image.LANCZOS)
    rb = rh[1]
    dbb = dh[1]
    ox = int(rb[2] - dbb[2] * sc)   # 主体右缘对齐
    oy = int(rb[3] - dbb[3] * sc)   # 底缘对齐
    patch = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    patch.paste(ds, (ox, oy), ds)
    im.paste(patch, ((cell_idx % 3) * F, (cell_idx // 3) * F))
    print("  [%s] 借格 c%d <- %s (sc=%.3f)" % (key, cell_idx + 1, donor_roll, sc))


def finalize(key, roll, flips, borrow=None):
    src = os.path.join(ST, "%s_%s_attack_sheet_832.png" % (key, roll))
    dst = os.path.join(ST, "%s_attack_sheet_832.png" % key)
    im = Image.open(src).convert('RGBA')
    for i in flips:
        x0, y0 = (i % 3) * F, (i // 3) * F
        im.paste(cell_of(im, i).transpose(Image.FLIP_LEFT_RIGHT), (x0, y0))
    for ci, dr in (borrow or {}).items():
        graft_cell(im, int(ci), dr, key)
    im, n_pink = depink_erase(im)
    bots = []
    for i in range(6):
        bb = largest_cc_bbox(body_mask(cell_of(im, i)))
        bots.append(bb[3] if bb else None)
    ref = bots[0]
    for i in range(1, 6):
        if bots[i] is None or ref is None:
            continue
        dy = ref - bots[i]
        if abs(dy) >= 3:
            c = cell_of(im, i)
            cleared = Image.new('RGBA', (F, F), (0, 0, 0, 0))
            cleared.paste(c, (0, dy), c)
            im.paste(cleared, ((i % 3) * F, (i // 3) * F))
    im.save(dst)
    frames = [cell_of(im, i).resize((256, 256), Image.LANCZOS) for i in range(6)]
    contact = Image.new('RGBA', (256 * 6 + 8 * 7, 256 + 16), (70, 70, 70, 255))
    for i, f in enumerate(frames):
        contact.paste(f, (8 + i * (256 + 8), 8), f)
    contact.convert('RGB').save(os.path.join(ST, "%s_attack_cells.png" % key))
    bgc = Image.new('RGBA', (256, 256), (60, 60, 60, 255))
    comp = []
    for f in frames:
        b = bgc.copy()
        b.paste(f, (0, 0), f)
        comp.append(b.convert('RGB'))
    comp[0].save(os.path.join(ST, "%s_attack_anim.gif" % key), save_all=True,
                 append_images=comp[1:], duration=125, loop=0)
    print("[%s] %s 转正 flips=%s 清渍%dpx 基线=%s" % (key, roll, flips or "无", n_pink, bots))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--decisions", default=os.path.join(ST, "_finalize_decisions.json"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dec = json.load(open(args.decisions, encoding="utf-8"))
    for key, d in dec.items():
        if args.dry_run:
            print("DRY", key, d)
            continue
        finalize(key, d["roll"], d.get("flips", []), d.get("borrow"))


if __name__ == "__main__":
    main()
