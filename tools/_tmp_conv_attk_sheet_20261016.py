# -*- coding: utf-8 -*-
"""四拍卷 → 现役 attack 精灵帧(2026-10-16)。

链路:2048² 卷 → 4×1024² 拍 → cut_key 五键控(§11.2 参数) → LANCZOS 256²
→ 缩放后帧域二次杀品红(G2) → 帧内放置(格心 128/底缘 252) → sheet_attack 1024×256
→ 暂存 .godot/unit_review/attk4/<uid>/(暂存审阅制,不直写 assets)。

fire:TR 帧焰掩码(r>190&90≤g≤190&b<110&α>100)质心 → fire 原始 px 报告
(fireY_pct 待 foot_frac 工具覆写后换算,G8)。

用法:python -I -u -X utf8 tools/_tmp_conv_attk_sheet_20261016.py [060,026|=all]
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw")
OUT = os.path.join(ROOT, ".godot", "unit_review", "attk4")
BEATS = ["TL", "TR", "BL", "BR"]

sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_api_card_regen_20261014 as R1  # noqa: E402
import _tmp_api_card_regen_batch2 as R2  # noqa: E402

UID = {}
for u in R1.UNITS:
    UID[u["no"]] = u["uid"]
for u in R2.UNITS2:
    UID.setdefault(u["no"], u["uid"])


def cut_key(cell):
    """五步键控(§11.2):主键/紫边去饱和/二次键/紫边去色/1px 羽化。RGB float→RGBA uint8。"""
    r, g, b = cell[:, :, 0], cell[:, :, 1], cell[:, :, 2]
    mag = (r > 140) & (b > 140) & (g < 0.75 * np.minimum(r, b) - 10)
    alpha = np.where(mag, 0, 255).astype(np.uint8)
    violet = (~mag) & (r > 120) & (b > 120) & (g < 0.8 * np.minimum(r, b))
    despill = cell.copy()
    new_rb = ((r + b) / 2)
    for ch in (0, 2):
        despill[:, :, ch] = np.where(violet, new_rb * 0.5 + despill[:, :, ch] * 0.5, despill[:, :, ch])
    r2, g2, b2 = despill[:, :, 0], despill[:, :, 1], despill[:, :, 2]
    mag2 = (r2 > 140) & (b2 > 140) & (g2 < 0.75 * np.minimum(r2, b2) - 10)
    alpha[mag2] = 0
    dil = mag2.copy()
    for _ in range(2):
        dil = dil | np.roll(dil, 1, 0) | np.roll(dil, -1, 0) | np.roll(dil, 1, 1) | np.roll(dil, -1, 1)
    keep = alpha > 0
    purple = dil & (~mag2) & (r2 > g2 + 18) & (b2 > g2 + 8) & keep
    if purple.any():
        gray = ((r2 + g2 * 2 + b2) / 4)
        for ch in range(3):
            despill[:, :, ch] = np.where(purple, gray, despill[:, :, ch])
    opaque = alpha == 255
    neigh = np.zeros_like(opaque)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(opaque, dy, 0), dx, 1)
        neigh |= ~sh
    alpha[opaque & neigh] = 140
    return despill, alpha


def frame_256(cell_rgb):
    """键控→缩 256→帧域二次杀→返回 RGBA uint8。"""
    despill, alpha = cut_key(cell_rgb)
    rgba = np.dstack([despill.astype(np.uint8), alpha])
    im = Image.fromarray(rgba, "RGBA").resize((256, 256), Image.LANCZOS)
    a = np.asarray(im).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    m = (a[:, :, 3] > 60) & (r > 140) & (b > 140) & (g < 0.75 * np.minimum(r, b) - 10)
    # 品红接触影(i2i 把影子画成暗品红,r/b 双高 g 低;现役资产零残留基准 2026-10-16)
    m |= (a[:, :, 3] > 60) & (r > g + 40) & (b > g + 15) & (r > 55) & (b > 35)
    a[m, 3] = 0
    # 孤立噪粒清除(品灰紫残粒 r-g≈32 擦边漏网;3×3 邻居计数<3 判噪,无 scipy 用 roll)
    op = a[:, :, 3] > 60
    cnt = np.zeros(op.shape, int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                cnt += np.roll(np.roll(op, dy, 0), dx, 1)
    a[op & (cnt <= 2), 3] = 0
    return a.astype(np.uint8), int(m.sum())


def place(fr):
    """帧内放置:α>20 bbox → 格心 128 / 底缘 252。"""
    m = fr[:, :, 3] > 20
    if not m.any():
        return fr, None
    ys, xs = np.where(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    w, h = x1 - x0 + 1, y1 - y0 + 1
    crop = fr[y0:y1 + 1, x0:x1 + 1]
    out = np.zeros((256, 256, 4), np.uint8)
    px = int(round(128 - w / 2))
    py = 252 - h
    px = max(0, min(256 - w, px))
    py = max(0, min(256 - h, py))
    out[py:py + h, px:px + w] = crop
    return out, (px, py, w, h)


def fire_probe(fr):
    """TR 帧焰掩码质心(橙焰);空=None。"""
    r, g, b, a = fr[:, :, 0].astype(int), fr[:, :, 1].astype(int), fr[:, :, 2].astype(int), fr[:, :, 3]
    m = (r > 190) & (g >= 90) & (g <= 190) & (b < 110) & (a > 100)
    if m.sum() < 8:
        return None
    ys, xs = np.where(m)
    return [int(xs.mean()), int(ys.mean()), int(m.sum())]


def main(nos):
    report = []
    for no in nos:
        uid = UID.get(no)
        vols = glob.glob(os.path.join(RAW, no + "·*_开火4格.png"))
        if not uid or not vols:
            report.append({"no": no, "err": "no uid or vol"})
            continue
        vol = Image.open(vols[0]).convert("RGB")
        cell_sz = vol.size[0] // 2  # 2048²卷格1024²;用户侧1024²卷格512²
        frames, fire = [], None
        res2 = 0
        touch = 0
        for i, b in enumerate(BEATS):
            x0, y0 = (i % 2) * cell_sz, (i // 2) * cell_sz
            cell = np.asarray(vol.crop((x0, y0, x0 + cell_sz, y0 + cell_sz))).astype(float)
            fr, m2 = frame_256(cell)
            res2 += m2
            fr, box = place(fr)
            frames.append(fr)
            if b == "TR":
                fire = fire_probe(fr)
            e = int((fr[0, :, 3] > 60).sum() + (fr[-1, :, 3] > 60).sum()
                    + (fr[:, 0, 3] > 60).sum() + (fr[:, -1, 3] > 60).sum())
            touch += e
        od = os.path.join(OUT, uid)
        os.makedirs(od, exist_ok=True)
        sheet = np.concatenate(frames, axis=1)
        Image.fromarray(sheet, "RGBA").save(os.path.join(od, "sheet_attack.png"))
        rec = {"no": no, "uid": uid, "sheet": "1024x256", "residual2": res2,
               "touch_edge_px": touch, "fire_tr": fire}
        report.append(rec)
        print(json.dumps(rec, ensure_ascii=False), flush=True)
    with open(os.path.join(OUT, "_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    if arg == "all":
        nos = sorted(UID)
    else:
        nos = [n for n in arg.split(",") if n in UID]
    main(nos)
