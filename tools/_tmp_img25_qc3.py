# -*- coding: utf-8 -*-
"""img25 QC 第三轮（2026-09-30，用户否决后补强）。

背景：前两轮目检用 ~64px 缩略拼图，对帧间朝向翻转/轻微变形/大小漂移/身份色差不敏感。
本轮程序指标全量筛 88 单位×2 动画×6 帧：

  1 朝向离群  ：帧质心水平偏置方向 vs 全表众数方向相反（且幅值>8px）→ 该帧疑似翻转
  2 大小漂移  ：帧内容高 vs 6 帧中位数偏差 >18%
  3 宽高比异常：帧 bbox 宽高比 vs f0 宽高比偏差 >35%（变形/画错代理）
  4 身份色差  ：帧 HSV 直方图与 f0 相关度 < 0.45（身份漂移代理）

产物：
  _qc3_report.json   全部明细
  _qc3_flags.txt     逐单位问题清单（人读）
  _qc3_<key>.png     有问题单位的全尺寸逐帧拼图（上=idle 下=attack，每格 256 原尺寸）
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_img25_redo_88 as R

OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
FS = 256


def hull_offset(m):
    """帧质心水平偏置（相对 256 中心），无内容返回 None。"""
    a = np.asarray(m)
    ys, xs = np.where(a[:, :, 3] > 8)
    if len(xs) < 30:
        return None
    return float(xs.mean()) - (FS / 2.0)


def hsv_hist(im):
    hsv = im.convert("HSV")
    h = np.asarray(hsv)[:, :, 0][np.asarray(im)[:, :, 3] > 8]
    if len(h) == 0:
        return None
    hist, _ = np.histogram(h, bins=18, range=(0, 255), density=True)
    return hist


def corr(a, b):
    if a is None or b is None:
        return 0.0
    a = a - a.mean(); b = b - b.mean()
    d = (np.sqrt((a * a).sum()) * np.sqrt((b * b).sum()))
    return float((a * b).sum() / d) if d > 1e-9 else 0.0


def qc_unit(key):
    """返回 {tag: [问题串]}。"""
    f0, _ = R.load_card(R.U[[x[0] for x in R.U].index(key)][1]) if key in [x[0] for x in R.U] else (None, None)
    rep = {}
    for tag in ("attackC", "idle"):
        p = os.path.join(OUT, "%s_%s.png" % (key, tag))
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        probs = []
        frames, offs, hs, ratios, corrs = [], [], [], [], []
        for i in range(6):
            fr = im.crop((i * FS, 0, (i + 1) * FS, FS))
            a = np.asarray(fr)
            ys, xs = np.where(a[:, :, 3] > 8)
            if len(ys) < 30:
                frames.append(None); offs.append(None); hs.append(0); ratios.append(0); corrs.append(0)
                continue
            h = ys.max() - ys.min() + 1; w = xs.max() - xs.min() + 1
            frames.append(fr)
            offs.append(float(xs.mean()) - FS / 2.0)
            hs.append(h)
            ratios.append(w / float(h))
            if f0 is not None:
                fa = np.asarray(f0)
                fys, fxs = np.where(fa[:, :, 3] > 8)
                fh = fys.max() - fys.min() + 1
                ratios_f0 = (fxs.max() - fxs.min() + 1) / float(fh)
            else:
                ratios_f0 = None
            corrs.append(ratios_f0)
        # f0 宽高比（一次）
        if f0 is not None:
            fa = np.asarray(f0)
            fys, fxs = np.where(fa[:, :, 3] > 8)
            f0_ratio = (fxs.max() - fxs.min() + 1) / float(fys.max() - fys.min() + 1)
            f0_hist = hsv_hist(f0)
        else:
            f0_ratio, f0_hist = None, None
        med_h = float(np.median([h for h in hs if h > 0])) if any(hs) else 0
        dir_mode = np.sign([o for o in offs if o is not None and abs(o) > 8]).astype(int)
        mode = int(np.bincount(dir_mode + 1).argmax()) - 1 if len(dir_mode) else 0
        for i in range(6):
            if frames[i] is None:
                probs.append("f%d: 空/近空" % i)
                continue
            if abs(offs[i]) > 8 and mode != 0 and np.sign(offs[i]) != mode:
                probs.append("f%d: 朝向离群(偏置%+.0f, 表众数%+d)" % (i, offs[i], mode))
            if med_h > 0 and abs(hs[i] - med_h) / med_h > 0.18:
                probs.append("f%d: 高漂移 %d vs 中位 %d" % (i, hs[i], int(med_h)))
            if f0_ratio and ratios[i] > 0:
                dev = abs(ratios[i] - f0_ratio) / f0_ratio
                if dev > 0.35:
                    probs.append("f%d: 宽高比 %.2f vs f0 %.2f (偏差%.0f%%)" % (i, ratios[i], f0_ratio, dev * 100))
            if f0_hist is not None:
                c = corr(hsv_hist(frames[i]), f0_hist)
                if c < 0.45:
                    probs.append("f%d: 色差 corr=%.2f" % (i, c))
        if probs:
            rep[tag] = probs
    return rep


def main():
    all_rep = {}
    for (key, rel, weapon, energy, defensive) in R.U:
        all_rep[key] = qc_unit(key)
    # 汇总
    lines, bad_units = [], []
    for key, rep in all_rep.items():
        if not rep:
            continue
        n = sum(len(v) for v in rep.values())
        bad_units.append((key, n))
        lines.append("%s (%d 条)" % (key, n))
        for tag, probs in rep.items():
            for s in probs:
                lines.append("  [%s] %s" % (tag, s))
    open(os.path.join(OUT, "_qc3_flags.txt"), "w", encoding="utf-8").write("\n".join(lines) or "全部干净")
    json.dump(all_rep, open(os.path.join(OUT, "_qc3_report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("有问题单位: %d / 88" % len(bad_units))
    for k, n in sorted(bad_units, key=lambda x: -x[1]):
        print("  %-26s %d 条" % (k, n))


if __name__ == "__main__":
    main()
