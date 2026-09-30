# -*- coding: utf-8 -*-
"""img25 raw 结构体检（切格前跑，09-29 定稿流程第 2 步）：3x2 列带/行带、画布触边、逐格内容宽高。
用法：python tools/img25_raw_audit.py <raw.png> [more...]
      无参 = 扫 img25_staging 全部 *_raw.png（跳过 *_rawFLIP/_raw_flip）。
判定：cols==3 且 rows==2 且无触边且无空格 → PASS；列带≠3 → 粘连/缺格；触边 → 内容被画布裁切。
目检仍不可省（本工具看不出朝向/身份/视角），它只管结构。"""
import glob
import os
import sys

import numpy as np
from PIL import Image


def bands(m, min_gap=8):
    out, s = [], None
    for i, v in enumerate(m):
        if v and s is None:
            s = i
        elif not v and s is not None:
            out.append((s, i))
            s = None
    if s is not None:
        out.append((s, len(m)))
    merged = []
    for b in out:
        if merged and b[0] - merged[-1][1] < min_gap:
            merged[-1] = (merged[-1][0], b[1])
        else:
            merged.append(b)
    return [b for b in merged if b[1] - b[0] > 12]


def audit(p):
    sheet = Image.open(p).convert("RGB")
    a = np.asarray(sheet).astype(np.int16)
    nw = ~((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235))
    H, W = nw.shape
    cols, rows = bands(nw.any(axis=0)), bands(nw.any(axis=1))
    print("%s  %dx%d cols=%s rows=%s" % (os.path.basename(p), W, H, cols, rows))
    problems = []
    if len(cols) != 3:
        problems.append("列带=%d(≠3 粘连或缺格)" % len(cols))
    if len(rows) != 2:
        problems.append("行带=%d(≠2)" % len(rows))
    if cols and cols[0][0] <= 1:
        problems.append("左缘触边(内容被裁)")
    if cols and cols[-1][1] >= W - 2:
        problems.append("右缘触边")
    if rows and rows[0][0] <= 1:
        problems.append("顶缘触边")
    if rows and rows[-1][1] >= H - 2:
        problems.append("底缘触边")
    if len(cols) == 3 and len(rows) == 2:
        for ri, (ry0, ry1) in enumerate(rows):
            for ci, (cx0, cx1) in enumerate(cols):
                sub = nw[ry0:ry1, cx0:cx1]
                ys, xs = np.where(sub)
                if len(xs) == 0:
                    # 09-29 用户拍板：6 格不必全过，空格切格时自动 f0 兜底，可接受不算 FAIL
                    print("  cell%d 空格→f0兜底(可接受)" % (ri * 3 + ci))
                    continue
                print("  cell%d w=%d h=%d" % (ri * 3 + ci, xs.max() - xs.min() + 1, ys.max() - ys.min() + 1))
    print("  => " + ("PASS" if not problems else "FAIL: " + "; ".join(problems)))
    return not problems


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    paths = sys.argv[1:] or sorted(
        p for p in glob.glob(os.path.join(root, ".godot", "unit_review", "img25_staging", "*_raw.png"))
        if "FLIP" not in os.path.basename(p).upper())
    ok = all([audit(p) for p in paths]) if paths else True
    print("AUDIT_" + ("ALL_PASS" if ok else "HAS_FAIL"))
