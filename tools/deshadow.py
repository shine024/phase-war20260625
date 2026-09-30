# -*- coding: utf-8 -*-
"""批量去投影工具（记录4·七轮，用户拍板"去投影"）。

对象：assets/card_icons/{enemy,player}/*.png 与 assets/effects/unit_anims/*/sheet_*.png
     中 shadow_score 达标的资产（用户批注 18 + 机检 24 净新增）。
算法（逐帧/逐画布）：
  1. 内容底带（内容 bbox 最低 22%）内候选像素：低饱和(sat<28) + 中亮度(40<v<225) + α>25
  2. 细节保护：|∇v|>16 的像素膨胀 2px（靴子描边/高光/结构线）不入候选
  3. 水平游程 ≥10px 的候选才删（ protects 小块灰色细节）
  4. 删除=α 置 0；对删除边界做 1px 线性羽化防硬边
  5. 幂等：处理后 shadow_score 应 ≈0；前后分数写入报告

用法：
  python tools/deshadow.py scan            # 只列出达标资产与分数（不动文件）
  python tools/deshadow.py apply           # 备份→处理→复检→写报告
备份：.godot/art_backup_deshadow_20260927/<原相对路径>
报告：.godot/unit_review/deshadow_report.json
"""
import io
import json
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "card_icons")
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_deshadow_20260927")
REPORT = os.path.join(ROOT, ".godot", "unit_review", "deshadow_report.json")
TH = 0.45


def shadow_score(arr):
    a = arr[:, :, 3]
    m = a > 12
    if not m.any():
        return 0.0
    ys, xs = np.where(m)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    ch = y1 - y0 + 1
    if ch < 24:
        return 0.0
    band = arr[max(0, y1 - int(ch * 0.16)):y1 + 1, x0:x1 + 1]
    br, bg, bb, ba = band[:, :, 0], band[:, :, 1], band[:, :, 2], band[:, :, 3]
    mx = np.maximum(np.maximum(br, bg), bb)
    mn = np.minimum(np.minimum(br, bg), bb)
    cand = ((mx - mn) < 28) & (mx > 40) & (mx < 225) & (ba > 25) & ~((ba > 235) & (mx < 90))
    if cand.sum() < 30:
        return 0.0
    cov = cand.any(axis=0).sum() / max(1, cand.any(axis=0).size)
    den = cand.sum() / max(1, cand.size)
    return float(min(cov * 0.7 + den * 0.6, 1.0))


def gradient_protect(v):
    g = np.zeros_like(v, bool)
    gx = np.abs(np.diff(v, axis=1))
    gy = np.abs(np.diff(v, axis=0))
    g[:, 1:] |= gx > 16
    g[:, :-1] |= gx > 16
    g[1:, :] |= gy > 16
    g[:-1, :] |= gy > 16
    # 膨胀 2px
    p = g.copy()
    for _ in range(2):
        q = p.copy()
        q[1:, :] |= p[:-1, :]; q[:-1, :] |= p[1:, :]
        q[:, 1:] |= p[:, :-1]; q[:, :-1] |= p[:, 1:]
        p = q
    return p


def runs_wide(mask_row, min_run=10):
    """返回该行中游程≥min_run 的掩码。"""
    out = np.zeros_like(mask_row)
    xs = np.where(mask_row)[0]
    if len(xs) == 0:
        return out
    s = xs[0]
    prev = xs[0]
    for x in xs[1:]:
        if x == prev + 1:
            prev = x
            continue
        if prev - s + 1 >= min_run:
            out[s:prev + 1] = True
        s = x
        prev = x
    if prev - s + 1 >= min_run:
        out[s:prev + 1] = True
    return out


def deshadow_frame(arr):
    """单画布/单帧去投影。返回 (新arr, 删除像素数)。"""
    a = arr.copy()
    al = a[:, :, 3]
    m = al > 12
    if not m.any():
        return a, 0
    ys, xs = np.where(m)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    ch = y1 - y0 + 1
    if ch < 24:
        return a, 0
    band_y0 = max(0, y1 - int(ch * 0.22))
    br, bg, bb, ba = a[band_y0:, :, 0], a[band_y0:, :, 1], a[band_y0:, :, 2], a[band_y0:, :, 3]
    mx = np.maximum(np.maximum(br, bg), bb)
    mn = np.minimum(np.minimum(br, bg), bb)
    cand = ((mx - mn) < 28) & (mx > 40) & (mx < 225) & (ba > 25)
    v = mx
    prot = gradient_protect(v)
    cand &= ~prot
    # 游程过滤：逐行
    keep_rows = np.zeros_like(cand)
    for r in range(cand.shape[0]):
        keep_rows[r] = runs_wide(cand[r], 10)
    cand = keep_rows
    n = int(cand.sum())
    if n < 40:
        return a, 0
    ys2, xs2 = np.where(cand)
    abs_y = ys2 + band_y0
    a[abs_y, xs2, 3] = 0
    # 1px 羽化：删除区相邻的存活像素 α 乘 0.75（仅底带内）
    removed = np.zeros(al.shape, bool)
    removed[abs_y, xs2] = True
    edge = np.zeros_like(removed)
    edge[1:, :] |= removed[:-1, :]; edge[:-1, :] |= removed[1:, :]
    edge[:, 1:] |= removed[:, :-1]; edge[:, :-1] |= removed[:, 1:]
    edge &= ~removed & (band_y0 <= np.arange(al.shape[0])[:, None])
    a[:, :, 3][edge] = (a[:, :, 3][edge] * 0.75).astype(np.int16)
    return a, n


def process_file(path, rel, report, apply):
    arr = np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)
    before = shadow_score(arr)
    if before < TH:
        return
    total = 0
    if "sheet_" in os.path.basename(path):
        fs = 256
        aj = os.path.join(os.path.dirname(path), "anim.json")
        if os.path.exists(aj):
            fs = int(json.load(open(aj, encoding="utf-8")).get("frame_size", 256))
        n = arr.shape[1] // fs
        new = arr.copy()
        for i in range(n):
            fr = new[:, i * fs:(i + 1) * fs]
            nf, k = deshadow_frame(fr)
            new[:, i * fs:(i + 1) * fs] = nf
            total += k
        after_arr = new
    else:
        new, total = deshadow_frame(arr)
        after_arr = new
    after = shadow_score(after_arr)
    if apply and after < before and total > 0:
        bak = os.path.join(BAK, rel)
        os.makedirs(os.path.dirname(bak), exist_ok=True)
        shutil.copy2(path, bak)
        Image.fromarray(after_arr.astype(np.uint8)).save(path)
    report[rel] = {"before": round(before, 3), "after": round(after, 3) if apply else None,
                   "px": total, "applied": bool(apply and after < before and total > 0)}
    print("%s %s %.3f -> %s (px=%d)" % ("APPLY" if apply else "SCAN  ", rel, before,
          ("%.3f" % after) if apply else "-", total))


def main(apply):
    report = {}
    if apply:
        os.makedirs(BAK, exist_ok=True)
    for sub in ("enemy", "player"):
        d = os.path.join(ICONS, sub)
        for f in sorted(os.listdir(d)):
            if f.endswith(".png"):
                process_file(os.path.join(d, f), "assets/card_icons/%s/%s" % (sub, f), report, apply)
    for u in sorted(os.listdir(ANIM)):
        for f in ("sheet_idle.png", "sheet_attack.png"):
            p = os.path.join(ANIM, u, f)
            if os.path.exists(p):
                process_file(p, "assets/effects/unit_anims/%s/%s" % (u, f), report, apply)
    io.open(REPORT, "w", encoding="utf-8").write(json.dumps(report, ensure_ascii=False, indent=0))
    n = sum(1 for v in report.values() if v["applied"])
    print("TOTAL scanned=%d applied=%d report=%s" % (len(report), n, REPORT))


if __name__ == "__main__":
    main(len(os.sys.argv) > 1 and os.sys.argv[1] == "apply")
