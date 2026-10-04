# -*- coding: utf-8 -*-
"""img25 雪碧图常用错误体检（2026-10-01）：每单位每掷全项机检。

用法:
    python tools/img25_healthcheck.py <sheet_832.png> [...]     # 单/多张
    python tools/img25_healthcheck.py --staging                 # 扫 staging 全部 *_R*_attack_sheet_832.png

检查项（常用错误清单，全部来自 09-30/10-01 实踩）:
  [EMPTY]   空格/坏格        格内容像素 < 40
  [EDGE]    触边裁切         内容贴格边（主体被切）
  [VJUMP]   垂直跳动         滤焰 bbox 底缘/中心 y 逐格差 ≥8px（256 显示 ~2.5px）
  [HJUMP]   水平漂移         中心 x 逐格差 ≥40px
  [SIZE]    尺寸跳变         机身高极差 ≥12% 均值
  [PINK]    品红残留         粉像素 >500（finalize 会清，转正前提示）
  [RAIL]    残线             列/行 alpha 跨度异常（strip_rail_cols 同判据）
  [DUP]     重复帧           md5 相同格对 >1（回文预期内 1 对）
  [SHAPE]   图像变形         逐格主体掩膜与待机格(格1)最优对齐 IoU <0.5（炮管弯折/车体融变/部件漂移，
                             v8 生视频时代"复杂机械形逐帧融变"的雪碧图版；目检裁定）
  [C6IDLE]  首尾待机漂移     格6 与格1 IoU <0.8（回环闭合差，回文播放时肉眼可见）
  [NOFLAME] 无开火           六格橙焰像素总量 <300（能量武器单位目检兜底）
输出: 每张 PASS/WARN/FAIL 一行 + JSON 明细（--json 落盘）。
朝向/身份漂移不在此列——必须 500px 目检（facing() 双向不可靠，09-30 定论）。
"""
import argparse
import glob
import hashlib
import json
import os
from collections import deque

from PIL import Image
import numpy as np

F = 832


def cell_of(im, i):
    x0, y0 = (i % 3) * F, (i // 3) * F
    return im.crop((x0, y0, x0 + F, y0 + F))


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


def largest_cc_mask(mask):
    """最大连通域掩膜（SHAPE 对比用，滤掉碎屑污染 IoU）。"""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=bool)
    best = None
    bestn = 0
    for yy in range(h):
        for xx in range(w):
            if mask[yy, xx] and not lab[yy, xx]:
                comp = np.zeros((h, w), dtype=bool)
                dq = deque([(yy, xx)])
                lab[yy, xx] = True
                comp[yy, xx] = True
                n = 0
                while dq:
                    y, x = dq.popleft()
                    n += 1
                    for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = True
                            comp[ny, nx] = True
                            dq.append((ny, nx))
                if n > bestn:
                    bestn, best = n, comp
    return best


def iou_bottom_aligned(m1, m2, search=12, step=2):
    """底缘中心对齐 ±search 搜索后取最大 IoU（底基线对齐消掉垂直注册差，
    剩下的差异才是真形状差——变形/部件漂移）。"""
    def bbc(m):
        ys, xs = np.where(m)
        return (xs.min() + xs.max()) // 2, ys.max()  # 中心x, 底y
    c1x, c1y = bbc(m1)
    c2x, c2y = bbc(m2)
    H, W = m1.shape
    best = 0.0
    for dy in range(-search, search + 1, step):
        for dx in range(-search, search + 1, step):
            oy = c2y - c1y + dy
            ox = c2x - c1x + dx
            ys0, ys1 = max(0, oy), min(H, H + oy)
            xs0, xs1 = max(0, ox), min(W, W + ox)
            if ys1 <= ys0 or xs1 <= xs0:
                continue
            shifted = np.zeros_like(m1)
            shifted[ys0:ys1, xs0:xs1] = m2[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
            union = (m1 | shifted).sum()
            if union:
                v = (m1 & shifted).sum() / union
                if v > best:
                    best = v
    return best


def check_sheet(path):
    im = Image.open(path).convert('RGBA')
    issues = []
    bboxes, masks, dups, flames, pinks, empties, edges = [], [], [], [], [], [], []
    for i in range(6):
        cell = cell_of(im, i)
        a = np.asarray(cell)
        al = a[:, :, 3]
        npx = int((al > 8).sum())
        if npx < 40:
            empties.append(i + 1)
            issues.append(("EMPTY", "格%d 空格/坏格（内容像素 %d）" % (i + 1, npx)))
            bboxes.append(None)
            masks.append(None)
            continue
        if al[0].max() > 8 or al[-1].max() > 8 or al[:, 0].max() > 8 or al[:, -1].max() > 8:
            edges.append(i + 1)
            issues.append(("EDGE*", "格%d 内容贴边（贴边≠截断，目检裁定）" % (i + 1)))
        cc = largest_cc_mask(body_mask(cell))
        if cc is None:
            bboxes.append(None)
            masks.append(None)
            continue
        ys, xs = np.where(cc)
        bb = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        bboxes.append(bb)
        masks.append(cc)
        r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
        flames.append(int(((r > 140) & (r - b > 60) & (al > 8)).sum()))
        pinks.append(int(((r - g > 40) & (b - g > 10) & (al > 8)).sum()))
        dups.append(hashlib.md5(a.tobytes()).hexdigest())
    # 垂直/水平/尺寸
    ok_bb = [b for b in bboxes if b]
    if len(ok_bb) >= 3:
        bots = [b[3] for b in ok_bb]
        cys = [(b[1] + b[3]) / 2 for b in ok_bb]
        cxs = [(b[0] + b[2]) / 2 for b in ok_bb]
        hs = [b[3] - b[1] for b in ok_bb]
        dv = max(bots) - min(bots)
        dv2 = max(cys) - min(cys)
        if dv >= 8 or dv2 >= 12:
            issues.append(("VJUMP", "垂直跳动：底缘极差 %dpx / 中心y极差 %dpx（finalize 会注册对齐）" % (dv, dv2)))
        dh = max(cxs) - min(cxs)
        if dh >= 40:
            issues.append(("HJUMP", "水平漂移：中心x极差 %dpx（目检是否观感晃动）" % dh))
        if max(hs) - min(hs) >= 0.12 * (sum(hs) / len(hs)):
            issues.append(("SIZE", "尺寸跳变：机身高 %s（极差 %dpx，可能需跨掷借格）" % (hs, max(hs) - min(hs))))
    # SHAPE 图像变形 + C6IDLE 首尾待机漂移（底缘对齐 IoU）
    if masks[0] is not None:
        for i in range(1, 6):
            if masks[i] is None:
                continue
            v = iou_bottom_aligned(masks[0], masks[i])
            if i == 5:
                if v < 0.80:
                    issues.append(("C6IDLE", "格6与格1 IoU %.2f（首尾待机不一致，回环肉眼跳变）" % v))
            elif v < 0.50:
                issues.append(("SHAPE", "格%d 与待机格 IoU %.2f（变形/部件漂移/大动作，目检裁定）" % (i + 1, v)))
    # 粉残留
    if pinks and max(pinks) > 500:
        issues.append(("PINK", "品红残留：最脏格 %dpx（finalize 会清）" % max(pinks)))
    # 残线（列跨度）
    a0 = np.asarray(cell_of(im, 0))
    for i in range(6):
        al = np.asarray(cell_of(im, i))[:, :, 3] > 8
        for axis in (0, 1):
            prof = al.sum(axis=axis)
            hits = 0
            for k in range(3, len(prof) - 3):
                v = prof[k]
                if v < 100:
                    continue
                nb = np.median(list(prof[k - 3:k]) + list(prof[k + 1:k + 4]))
                if v > 1.8 * max(nb, 1):
                    hits += 1
            if hits >= 8:
                issues.append(("RAIL", "格%d 残线（%s向异常跨度 %d 处）" % (i + 1, "列" if axis == 0 else "行", hits)))
                break
    # 重复帧
    seen = {}
    pairs = 0
    for i, h in enumerate(dups):
        if h in seen:
            pairs += 1
        seen[h] = i
    if pairs > 1:
        issues.append(("DUP", "重复帧 %d 对（回文预期 1 对）" % pairs))
    # 无开火
    if flames and sum(flames) < 300:
        issues.append(("NOFLAME", "全表橙焰仅 %dpx——无开火动作或能量武器（目检兜底）" % sum(flames)))

    fails = [x for x in issues if x[0] in ("EMPTY",)]  # EDGE* 已降 WARN（贴边≠截断，09-30 记忆）；EMPTY=真坏格
    verdict = "FAIL" if fails else ("WARN" if issues else "PASS")
    return {"sheet": os.path.basename(path), "verdict": verdict,
            "issues": [{"tag": t, "msg": m} for t, m in issues],
            "flames_per_cell": flames, "bbox_bottoms": [b[3] if b else None for b in bboxes]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheets", nargs="*")
    ap.add_argument("--staging", action="store_true")
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    paths = args.sheets
    if args.staging:
        ST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          ".godot", "unit_review", "img25_staging")
        paths = sorted(glob.glob(os.path.join(ST, "*_R*_attack_sheet_832.png")))
    results = []
    for p in paths:
        r = check_sheet(p)
        results.append(r)
        tag = {"PASS": "✓", "WARN": "△", "FAIL": "✗"}[r["verdict"]]
        print("%s %-52s %s" % (tag, r["sheet"], "; ".join("%s" % i["msg"] for i in r["issues"])[:110]))
    n_pass = sum(1 for r in results if r["verdict"] == "PASS")
    print("--- %d 张：PASS %d / WARN %d / FAIL %d" %
          (len(results), n_pass, sum(1 for r in results if r["verdict"] == "WARN"),
           sum(1 for r in results if r["verdict"] == "FAIL")))
    if args.json:
        json.dump(results, open(args.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
