# -*- coding: utf-8 -*-
"""img25 批量 88 单位雪碧图重做——新路线（卡图 f0 锚 + 程序焰贴片，2026-09-30）。

流程定案（fut_nano_drone 实测全链打通后推广）：
  A 桶  动能速射   f0 + prog_flash 橙黄，回文 12（火光两次观感=速射）
  S 桶  慢速重炮   坦克主炮/榴弹炮/反坦克炮：单向一炮（循环点落净 f0+微浮动）
  E 桶  能量武器   prog_flash 蓝白调色，回文 12
  D 桶  防御单位   脉冲微光变体（不强求开火），回文 12
  B 桶  生成动作帧 fut_nano_drone 已完成，跳过

铁律（今日踩坑沉淀）：
  - f0/雪碧图主体一律来自卡图（身份零漂移硬保证）
  - 反写卡图必须无焰帧（带焰帧会污染 f0 → idle 全带火光）
  - 候选卡图透明 RGBA（convert("RGB") 丢 alpha → f0 白底）
  - muzzle 人工标定表优先，自动定位（左缘质心）只做兜底+置信度
  - 程序焰零抠图零链路（生成焰抠取 5 道脆弱环节，已废）

用法：
  python tools/_tmp_img25_batch_88.py dry    # 干跑：muzzle 自动+标定网格图+置信度报告
  python tools/_tmp_img25_batch_88.py full   # 全量：出 sheet_idle/attack 进 staging/hybrid/<key>/
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_img25_redo_88 as R

OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "hybrid")
FS = 256

SLOW_WEAPONS = {"坦克主炮", "榴弹炮", "反坦克武器"}
SKIP_DONE = {"fut_nano_drone"}  # B 桶已完成

# 炮口人工标定表（网格图目测填这里，格式：key: (mx, my)）
MUZZLE_OVERRIDE = {
    "fut_nano_drone": (4, 149),   # 已完成单位留档
    # 低置信 8 单位（_muzzle_precision8.png 目测 2026-09-30）
    "mod_challenger2": (14, 138),  # 坦克炮口（自动点被天线拉偏）
    "mod_leo2a6": (12, 136),
    "mod_m1a2": (15, 145),
    "mod_stryker_m2": (95, 121),   # 车顶武器站枪口
    "mod_stryker_mgs": (70, 150),  # 炮塔机枪口（小图拿不准，验收页复核）
    "platform_cold_scout": (20, 172),  # 车头上部（验收页复核）
    "ww1_enfield": (76, 82),       # 步枪枪口
    "ww2_sup_gmc_truck": (26, 192),  # 车头（验收页复核）
    # 第二批精标（_muzzle_precision6.png 目测 2026-09-30）
    "fut_stormcore": (100, 35),    # 能量塔顶发射点
    "ww2_m120": (185, 112),        # 臼炮仰角炮口
    "ww1_m76": (32, 82),           # 反坦克炮左上炮口
    "mod_hummer_m2": (98, 114),    # 车顶机枪口
    "mod_hummer_tow": (114, 117),  # TOW 发射管口
    "fut_howitzer": (175, 132),    # 火箭炮箱左端面
}


def muzzle_auto(f0):
    """左缘质心兜底 + 置信度。置信度=左缘 3px 带 y 极差的负相关（极差小=炮管清晰=高置信）。"""
    a = np.asarray(f0)
    ys, xs = np.where(a[:, :, 3] > 8)
    if len(xs) < 30:
        return None, 0.0
    x0 = int(xs.min())
    band = ys[xs <= x0 + 3]
    if len(band) < 4:
        return None, 0.0
    span = int(band.max() - band.min())
    conf = max(0.0, 1.0 - span / 80.0)  # 极差 ≤12px 满置信；≥80px 零置信
    return (x0, int(band.mean())), conf


def shift(fr, dx, dy):
    if dx == 0 and dy == 0:
        return fr
    return fr.transform((FS, FS), Image.AFFINE, (1, 0, -dx, 0, 1, -dy))


def overlay(base, patch, cx, cy):
    """焰贴片合成（numpy 手动 alpha，支持负坐标；焰心 35% 越过炮口）。"""
    out = base.copy()
    a = np.asarray(out).astype(np.uint8).copy()
    p = np.asarray(patch.convert("RGBA"))
    px, py = int(cx - p.shape[1] * 0.35), int(cy - p.shape[0] / 2)
    h, w = p.shape[:2]
    x0, y0 = max(px, 0), max(py, 0)
    x1, y1 = min(px + w, FS), min(py + h, FS)
    if x1 <= x0 or y1 <= y0:
        return out
    ps = p[y0 - py:y1 - py, x0 - px:x1 - px].astype(np.float32)
    region = a[y0:y1, x0:x1].astype(np.float32)
    alpha = ps[:, :, 3:4] / 255.0
    a[y0:y1, x0:x1, :3] = np.clip(ps[:, :, :3] * alpha + region[:, :, :3] * (1 - alpha), 0, 255)
    a[y0:y1, x0:x1, 3] = np.maximum(region[:, :, 3], (alpha[:, :, 0] * 255).astype(np.uint8))
    return Image.fromarray(a, "RGBA")


def prog_flash(S=110, seed=7, palette="kinetic"):
    """程序枪口焰：白热核心 + 8 针星芒 + 辉光。palette: kinetic 橙黄 | energy 蓝白。"""
    rnd = random.Random(seed)
    yy, xx = np.mgrid[0:S, 0:S]
    cx = cy = (S - 1) / 2.0
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    a = np.zeros((S, S), dtype=np.float32)
    a += np.exp(-(d / (S * 0.16)) ** 2) * 1.0
    for k in range(8):
        ang = math.radians(k * 45 + rnd.uniform(-8, 8))
        L = (S * (0.46 if k % 2 == 0 else 0.30)) * rnd.uniform(0.85, 1.1)
        w = S * (0.035 if k % 2 == 0 else 0.025)
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - cx) * ux + (yy - cy) * uy
        s = -(xx - cx) * uy + (yy - cy) * ux
        m = (t > 0) & (t < L) & (np.abs(s) < w * (1 - t / max(L, 1)))
        a += m * (1.0 - t / max(L, 1)) * 0.9
    a = np.clip(a, 0, 1)
    core = np.exp(-(d / (S * 0.055)) ** 2)
    if palette == "energy":
        ff = (170, 220, 255)   # 青蓝焰
        cf = (235, 245, 255)   # 白蓝核心
    else:
        ff = (255, 190, 70)    # 橙黄焰
        cf = (255, 235, 170)   # 白黄核心
    rgb = np.zeros((S, S, 3), dtype=np.float32)
    for i in range(3):
        rgb[:, :, i] = np.where(core > 0.45, cf[i], ff[i])
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8),
                                      (a * 255).astype(np.uint8)]), "RGBA")


def pulse_ring(S=150, palette="kinetic"):
    """防御单位脉冲：圆环辉光（微光不火光）。"""
    yy, xx = np.mgrid[0:S, 0:S]
    cx = cy = (S - 1) / 2.0
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    r = d / (S * 0.32)
    ring = np.exp(-((r - 1.0) / 0.22) ** 2)
    glow = np.exp(-(d / (S * 0.22)) ** 2) * 0.5
    a = np.clip(ring + glow, 0, 1)
    if palette == "energy":
        col = (170, 220, 255)
    else:
        col = (200, 225, 255)
    rgb = np.zeros((S, S, 3), dtype=np.float32)
    for i in range(3):
        rgb[:, :, i] = col[i]
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), (a * 255).astype(np.uint8)]), "RGBA")


def build_unit(key, rel, weapon, energy, defensive):
    """单单位全链：f0 → muzzle → 程序序列 → sheets。返回 (muzzle, conf, note)。"""
    d_out = os.path.join(OUT, key)
    os.makedirs(d_out, exist_ok=True)
    f0, _ = R.load_card(rel)
    f0.save(os.path.join(d_out, "f0.png"))

    if key in MUZZLE_OVERRIDE:
        mz, conf, note = MUZZLE_OVERRIDE[key], 1.0, "人工标定"
    else:
        mz, conf = muzzle_auto(f0)
        note = "自动(左缘)" if mz else "失败"

    palette = "energy" if energy and key != "ww1_flame" else "kinetic"
    # ww1_flame 特例：喷火器虽走能量通道，火就是橙黄（蓝白焰违和）

    # idle8：程序垂直浮动（零生成）
    idle_srcs = [f0, shift(f0, 0, -1), shift(f0, 0, -2), shift(f0, 0, -1),
                 f0, shift(f0, 0, 1), shift(f0, 0, 2), shift(f0, 0, 1)]

    if defensive:
        # D 桶：脉冲微光
        pr = pulse_ring(palette=palette)
        pr_w = pr.point(lambda v: int(v * 0.5))
        mx, my = (mz if mz else (FS // 2, FS // 2))
        cx, cy = FS // 2, int(np.asarray(f0)[:, :, 3].nonzero()[0].mean()) if np.any(np.asarray(f0)[:, :, 3]) else FS // 2
        s_p = overlay(f0, pr, cx, cy)
        s_pw = overlay(f0, pr_w, cx, cy)
        atk_srcs = [f0, f0, s_p, s_pw, f0, f0]
        order = [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0]
    else:
        fl = prog_flash(seed=7, palette=palette)
        fl_half = fl.point(lambda v: int(v * 0.55))
        mx, my = (mz if mz else (FS // 2, FS // 2))
        s_fire = overlay(f0, fl, mx + 2, my)
        s_decay = overlay(f0, fl_half, mx + 1, my)
        s_recoil = shift(f0, 2, 1)
        if weapon in SLOW_WEAPONS:
            # S 桶：单向一炮——循环点落净 f0+微浮动（火光只闪一次）
            bob = shift(f0, 0, -1)
            atk_srcs = [f0, f0, s_fire, s_decay, f0, f0, bob, f0, shift(f0, 0, 1), f0, bob, f0]
            order = list(range(12))
            note += "|单向一炮"
        else:
            # A/E 桶：回文 12（速射观感）
            atk_srcs = [f0, f0, s_fire, shift(s_decay, 2, 1), s_recoil, f0]
            order = [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0]
    atk_frames = [atk_srcs[i] for i in order]

    for name, frames in (("idle", idle_srcs), ("attack", atk_frames)):
        sheet = Image.new("RGBA", (FS * len(frames), FS), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(fr, (i * FS, 0))
        sheet.save(os.path.join(d_out, "sheet_%s.png" % name))
    return mz, conf, note


def calibration_grid():
    """88 单位标定汇总图：每格 f0 缩略+自动炮口红圈+置信度标注。低置信黄框排前。"""
    rows = []
    for (key, rel, weapon, energy, defensive) in R.U:
        if key in SKIP_DONE:
            continue
        p = os.path.join(OUT, key, "f0.png")
        if not os.path.exists(p):
            continue
        f0 = Image.open(p).convert("RGBA")
        if key in MUZZLE_OVERRIDE:
            mz, conf, tag = MUZZLE_OVERRIDE[key], 1.0, "人工"
        else:
            mz, conf = muzzle_auto(f0)
            tag = "自动"
        rows.append((key, f0, mz, conf, tag, energy, defensive))
    rows.sort(key=lambda r: r[3])  # 低置信排前
    per, cols = 22, 4
    H, W0 = 240, 244
    n_img = (len(rows) + per - 1) // per
    for pg in range(n_img):
        chunk = rows[pg * per:(pg + 1) * per]
        img = Image.new("RGB", (cols * W0, ((len(chunk) + cols - 1) // cols) * H), (16, 16, 20))
        d = ImageDraw.Draw(img)
        for i, (key, f0, mz, conf, tag, energy, defensive) in enumerate(chunk):
            gx, gy = (i % cols) * W0, (i // cols) * H
            t = f0.copy()
            t.thumbnail((200, 200), Image.LANCZOS)
            img.paste(t, (gx + 40, gy + 30), t)
            if mz:
                s = t.width / float(FS)
                d.ellipse([gx + 40 + mz[0] * s - 7, gy + 30 + mz[1] * s - 7,
                           gx + 40 + mz[0] * s + 7, gy + 30 + mz[1] * s + 7],
                          outline=(255, 60, 40), width=2)
            lab = "%s %s%.2f" % (key, tag, conf)
            warn = conf < 0.55
            d.text((gx + 6, gy + 6), lab, fill=(255, 90, 60) if warn else (140, 220, 140))
            if warn:
                d.rectangle([gx + 2, gy + 2, gx + W0 - 3, gy + H - 3], outline=(200, 160, 40), width=2)
            marks = "".join([c for c, on in (("E", energy), ("D", defensive)) if on])
            if marks:
                d.text((gx + W0 - 26, gy + 6), marks, fill=(120, 180, 255))
        img.save(os.path.join(OUT, "_muzzle_grid88_%d.png" % pg))
    # 报告
    rep = [{"key": k, "muzzle": m, "conf": round(c, 2), "tag": t,
            "energy": e, "defensive": df} for (k, _, m, c, t, e, df) in rows]
    json.dump(rep, open(os.path.join(OUT, "_muzzle_report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    low = [r for r in rep if r["conf"] < 0.55]
    print("标定图 %d 页；低置信 %d 单位需人工审:" % (n_img, len(low)))
    for r in low:
        print("  %-26s conf=%.2f" % (r["key"], r["conf"]))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "dry"
    if mode == "dry":
        calibration_grid()
        return
    done, fails = [], []
    for (key, rel, weapon, energy, defensive) in R.U:
        if key in SKIP_DONE:
            continue
        try:
            mz, conf, note = build_unit(key, rel, weapon, energy, defensive)
            done.append((key, note, conf))
        except Exception as e:  # noqa
            fails.append((key, repr(e)))
    print("完成 %d / 失败 %d" % (len(done), len(fails)))
    for k, e in fails:
        print("  FAIL %s: %s" % (k, e))
    json.dump({k: {"note": n, "conf": round(c, 2)} for k, n, c in done},
              open(os.path.join(OUT, "_batch_report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
