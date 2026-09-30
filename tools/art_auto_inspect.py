# -*- coding: utf-8 -*-
"""美术自动体检器 v1（记录4·六轮，用户 50 条批注转检测器）：
用 build/修复单_美术工单_20260927.md 的用户批注做标注集，实现五类可程序化检测并验证召回：

  shadow   脚下阴影/抠图残留（卡图+雪碧图帧：底带低饱和灰/半透明横带）
  cutbot   贴底截断/半身（内容触底缘，疑截肢）
  sway     待机摆动幅度（idle 帧间质心/宽度漂移）
  flash    开火火光位置（attack 增量像素质心偏下/偏后）
  mismatch 卡图与动画同套度（HSV 直方图余弦）

只读分析，零资产改动。输出 .godot/unit_review/auto_inspect.json + 控制台对照报告。
用法：python tools/art_auto_inspect.py
"""
import io
import json
import math
import os
import re

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
ICONS = os.path.join(ROOT, "assets", "card_icons")
TICKET = os.path.join(ROOT, "build", "修复单_美术工单_20260927.md")
OUT = os.path.join(ROOT, ".godot", "unit_review", "auto_inspect.json")


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.int16)


def content_mask(a, th=12):
    return a > th


def detect_shadow(arr):
    """底带内低饱和灰/半透明横带 → 疑烘焙阴影或抠图渣。
    阴影特征：低饱和(|max-min|<26)、中等亮度(40-215)、水平覆盖宽。履带=实心深色(α255,V<90)排除。"""
    a = arr[:, :, 3]
    m = content_mask(a)
    if not m.any():
        return 0.0
    ys, xs = np.where(m)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    ch = y1 - y0 + 1
    if ch < 24:
        return 0.0
    band_y0 = max(0, y1 - int(ch * 0.16))
    band = arr[band_y0:y1 + 1, x0:x1 + 1]
    br, bg, bb, ba = band[:, :, 0], band[:, :, 1], band[:, :, 2], band[:, :, 3]
    mx = np.maximum(np.maximum(br, bg), bb)
    mn = np.minimum(np.minimum(br, bg), bb)
    sat = mx - mn
    v = mx
    cand = (sat < 26) & (v > 40) & (v < 215) & (ba > 30) & ~((ba > 235) & (v < 90))
    if cand.sum() < 30:
        return 0.0
    col_has = cand.any(axis=0)
    coverage = col_has.sum() / max(1, col_has.size)
    density = cand.sum() / max(1, cand.size)
    score = coverage * 0.7 + density * 0.6
    return round(float(min(score, 1.0)), 3)


def detect_cutbot(arr):
    """内容贴画布底缘（截肢/半身）。"""
    a = arr[:, :, 3]
    m = content_mask(a)
    if not m.any():
        return 0.0
    ys, xs = np.where(m)
    y1, x0, x1 = ys.max(), xs.min(), xs.max()
    if y1 < arr.shape[0] - 3:
        return 0.0
    edge = m[y1 - 1:y1 + 1, x0:x1 + 1]
    cover = edge.any(axis=0).sum() / max(1, x1 - x0 + 1)
    return round(float(cover), 3)


def detect_sway(sheet_path, fs, n):
    """idle 帧间质心 x 漂移 + 宽度变化 → 摆动幅度分。"""
    arr = load_rgba(sheet_path)
    a = arr[:, :, 3]
    cxs, ws = [], []
    for i in range(n):
        fr = a[:, i * fs:(i + 1) * fs]
        m = fr > 12
        if not m.any():
            continue
        ys, xs = np.where(m)
        cxs.append(xs.mean())
        ws.append(xs.max() - xs.min())
    if len(cxs) < 4:
        return 0.0
    amp_x = (max(cxs) - min(cxs)) / fs
    amp_w = (max(ws) - min(ws)) / fs
    return round(float(max(amp_x, amp_w * 0.6)), 3)


def detect_flash(idle_path, attack_path, fs, n_atk):
    """attack 帧相对 idle f0 的增量像素（火光）质心：偏下(>0.62) 或偏后(朝左单位 x>0.58) 扣分。"""
    idle = load_rgba(idle_path)[:, :fs, 3] if os.path.exists(idle_path) else None
    if idle is None:
        return None
    base = content_mask(idle, 20)
    base_d = base.copy()
    for _ in range(2):
        bd = base_d.copy()
        bd[1:, :] |= base_d[:-1, :]
        bd[:-1, :] |= base_d[1:, :]
        bd[:, 1:] |= base_d[:, :-1]
        bd[:, :-1] |= base_d[:, 1:]
        bd[1:, 1:] |= base_d[:-1, :-1]
        bd[:-1, :-1] |= base_d[1:, 1:]
        bd[1:, :-1] |= base_d[:-1, 1:]
        bd[:-1, 1:] |= base_d[1:, :-1]
        base_d = bd
    arr = load_rgba(attack_path)
    worst = None
    for i in range(1, n_atk):
        fr = arr[:, i * fs:(i + 1) * fs, 3]
        added = (fr > 30) & ~base_d
        if added.sum() < fs * fs * 0.01:
            continue
        ys, xs = np.where(added)
        cy, cx = ys.mean() / fs, xs.mean() / fs
        penalty = max(0.0, cy - 0.55) + max(0.0, cx - 0.55)
        if worst is None or penalty > worst[0]:
            worst = (round(float(penalty), 3), round(float(cy), 3), round(float(cx), 3), i)
    return worst


def hist_sim(arr_icon, arr_frame):
    """HSV 16x4x4 直方图余弦相似度（alpha>60 区域）。"""
    def hsv_hist(arr):
        a = arr[:, :, 3]
        m = a > 60
        if m.sum() < 100:
            return None
        rgb = arr[:, :, :3][m] / 255.0
        mx = rgb.max(axis=1)
        mn = rgb.min(axis=1)
        v = mx
        s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        h = np.zeros(len(rgb))
        d = np.maximum(mx - mn, 1e-6)
        h = np.where(mx == r, ((g - b) / d) % 6, h)
        h = np.where(mx == g, (b - r) / d + 2, h)
        h = np.where(mx == b, (r - g) / d + 4, h)
        h = h / 6.0
        H = np.clip((h * 16).astype(int), 0, 15)
        S = np.clip((s * 4).astype(int), 0, 3)
        V = np.clip((v * 4).astype(int), 0, 3)
        hist = np.zeros(16 * 4 * 4)
        np.add.at(hist, H * 16 + S * 4 + V, 1)
        return hist / max(hist.sum(), 1)
    hi, hf = hsv_hist(arr_icon), hsv_hist(arr_frame)
    if hi is None or hf is None:
        return None
    return round(float(np.dot(hi, hf) / (np.linalg.norm(hi) * np.linalg.norm(hf) + 1e-9)), 3)


def main():
    report = {}
    for d in sorted(os.listdir(ANIM)):
        p = os.path.join(ANIM, d)
        if not os.path.isdir(p):
            continue
        r = {}
        aj = os.path.join(p, "anim.json")
        counts, fs = {}, 256
        if os.path.exists(aj):
            j = json.load(open(aj, encoding="utf-8"))
            counts, fs = j.get("counts", {}), int(j.get("frame_size", 256))
        si, sa = os.path.join(p, "sheet_idle.png"), os.path.join(p, "sheet_attack.png")
        if os.path.exists(si):
            idle_arr = load_rgba(si)
            r["shadow_sheet"] = detect_shadow(idle_arr[:, :fs])
            n_idle = int(counts.get("idle", 0))
            if n_idle >= 4:
                r["sway"] = detect_sway(si, fs, min(n_idle, 16))
        if os.path.exists(sa) and os.path.exists(si):
            atk_arr = load_rgba(sa)
            r["shadow_sheet_atk"] = detect_shadow(atk_arr[:, :fs])
            f = detect_flash(si, sa, fs, int(counts.get("attack", 0)))
            if f:
                r["flash"] = f
        for side in ("enemy", "player"):
            ip = os.path.join(ICONS, side, d + ".png")
            if os.path.exists(ip):
                ic = load_rgba(ip)
                r["shadow_icon_" + side] = detect_shadow(ic)
                cb = detect_cutbot(ic)
                if cb > 0:
                    r["cutbot_" + side] = cb
                if os.path.exists(si):
                    sim = hist_sim(ic, load_rgba(si)[:, :fs])
                    if sim is not None:
                        r["sim_" + side] = sim
        report[d] = r

    # 对照用户批注验证召回
    recall = {}
    if os.path.exists(TICKET):
        s = io.open(TICKET, encoding="utf-8").read()
        blocks = re.split(r"^## ", s, flags=re.M)[1:]
        kw_map = {
            "shadow": ["阴影", "抠", "白块"],
            "flash": ["错误开火", "火光", "开火位置", "衔接"],
            "sway": ["摆动", "转动", "转头"],
            "cutbot": ["半身"],
            "mismatch": ["不是一套", "与原卡图不一样", "与动画不一样"],
        }
        tp, fn = {}, {}
        for b in blocks:
            name = b.splitlines()[0].strip()
            prob = ""
            for line in b.splitlines():
                if line.startswith("- 问题:"):
                    prob = line
            r = report.get(name, {})
            for cat, keys in kw_map.items():
                if any(k in prob for k in keys):
                    got = False
                    if cat == "shadow":
                        got = any(str(k).startswith("shadow") and v >= 0.35 for k, v in r.items())
                    elif cat == "flash":
                        got = r.get("flash", [0])[0] >= 0.05 if "flash" in r else False
                    elif cat == "sway":
                        got = r.get("sway", 0) >= 0.045
                    elif cat == "cutbot":
                        got = any(str(k).startswith("cutbot") for k in r)
                    elif cat == "mismatch":
                        got = any(str(k).startswith("sim_") and v < 0.55 for k, v in r.items())
                    if got:
                        tp.setdefault(cat, []).append(name)
                    else:
                        fn.setdefault(cat, []).append(name)
        print("\n===== 检测器 vs 用户批注 对照 =====")
        for cat in kw_map:
            tpf, fnf = tp.get(cat, []), fn.get(cat, [])
            tot = len(tpf) + len(fnf)
            print(f"{cat:9s} 召回 {len(tpf)}/{tot}" + (f"  漏: {fnf[:6]}" if fnf else ""))

    io.open(OUT, "w", encoding="utf-8").write(json.dumps(report, ensure_ascii=False, indent=0))
    print("\nsaved:", OUT)


if __name__ == "__main__":
    main()
