# -*- coding: utf-8 -*-
## 资产自动疑似检测（卡图 vs 雪碧图）：大小跳变/贴边截断/朝向矛盾/背景残留/色板不符
## 被 _build_card_anim_review.py import；也可独立跑打印分布调阈值。
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ALPHA_TH = 8          # alpha 判内容阈值
DEADZONE = 0.04       # 朝向质心死区（归一化 -1..1）
JITTER = 1.18         # idle 帧间内容宽/高最大最小比
SIZE_RATIO_HI = 1.45  # 卡图 vs 动画内容高占比比上限
SIZE_RATIO_LO = 0.68
WHITE_TH = 0.02       # 近白残留占比
MAGENTA_TH = 0.005    # 品红残留占比
HIST_SIM = 0.30       # 色板直方图交底下限
EDGE = 2              # 贴边判定边距(px)


def _load(path):
    return Image.open(path).convert("RGBA")


def _content(im):
    a = np.asarray(im)[:, :, 3]
    mask = a > ALPHA_TH
    n = int(mask.sum())
    if n < 30:
        return None
    ys, xs = np.where(mask)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    h, w = mask.shape
    cx = float(xs.mean()) / w * 2.0 - 1.0
    rgb = np.asarray(im.convert("RGB")).astype(np.int16)
    px = rgb[mask]
    white = float(((px > 235).all(axis=1)).sum()) / n
    mag = float(((px[:, 0] > 180) & (px[:, 2] > 180) & (px[:, 1] < 120)).sum()) / n
    return {"w": w, "h": h, "bbox": (int(x0), int(y0), int(x1), int(y1)),
            "cx": cx, "n": n, "white": white, "mag": mag,
            "hfrac": (y1 - y0 + 1) / h, "wfrac": (x1 - x0 + 1) / w, "rgb": px}


def _hist(rgb, bins=4):
    h = np.histogramdd(rgb / 256.0, bins=(bins, bins, bins),
                       range=[(0, 1)] * 3)[0]
    s = h.sum()
    return h / s if s > 0 else h


def analyze_card(icon_rel, anim, boss_dir, pose_dir, calib=False):
    """返回 (suspects 列表, metrics 简表)。路径均为项目相对（../assets/... 或 None）。"""
    sus = []
    met = {}
    ic = None
    if icon_rel:
        p = os.path.join(ROOT, icon_rel.lstrip("./"))
        if os.path.isfile(p):
            ic = _content(_load(p))
    # ── idle 雪碧图逐帧 ──
    idl = None
    if anim and anim.get("idle", 0) >= 2 and anim.get("sheet_idle"):
        p = os.path.join(ROOT, anim["sheet_idle"].lstrip("./"))
        if os.path.isfile(p):
            im = _load(p)
            fs = anim["fs"]
            n = anim["idle"]
            ws, hs, cxs = [], [], []
            frames = []
            for i in range(n):
                fr = im.crop((i * fs, 0, (i + 1) * fs, fs))
                c = _content(fr)
                frames.append(c)
                if c:
                    ws.append(c["wfrac"]); hs.append(c["hfrac"])
                    cxs.append(c["cx"])
            idl = frames[0] if frames else None
            # idle 同侧富余基线（供 clip 判定）：margin={L,R,T}
            idle_m = {"L": min(c["bbox"][0] for c in frames if c),
                      "R": min(c["w"] - 1 - c["bbox"][2] for c in frames if c),
                      "T": min(c["bbox"][1] for c in frames if c)}
            if ws:
                met["jit_w"] = round(max(ws) / max(min(ws), 1e-3), 3)
                met["jit_h"] = round(max(hs) / max(min(hs), 1e-3), 3)
                if met["jit_h"] > JITTER:
                    sus.append("size_jit" if calib else "size")
            # 残留检测取最差帧
            wt = max((c["white"] for c in frames if c), default=0)
            mg = max((c["mag"] for c in frames if c), default=0)
            met["res"] = round(max(wt / WHITE_TH if WHITE_TH else 0,
                                   mg / MAGENTA_TH if MAGENTA_TH else 0), 2)
            if wt > WHITE_TH or mg > MAGENTA_TH:
                sus.append("bg")
            # ── 攻击贴边截断 ──
            if anim.get("attack", 0) > 0 and anim.get("sheet_attack"):
                pa = os.path.join(ROOT, anim["sheet_attack"].lstrip("./"))
                if os.path.isfile(pa):
                    aim = _load(pa)
                    an = anim["attack"]
                    clip = 0
                    for i in range(an):
                        fr = aim.crop((i * fs, 0, (i + 1) * fs, fs))
                        c = _content(fr)
                        if not c:
                            continue
                        x0, y0, x1, y1 = c["bbox"]
                        hit = []
                        if x0 <= EDGE:
                            hit.append("L" if idle_m["L"] > EDGE else "")
                        if x1 >= fs - 1 - EDGE:
                            hit.append("R" if idle_m["R"] > EDGE else "")
                        if y0 <= EDGE:
                            hit.append("T" if idle_m["T"] > EDGE else "")
                        clip += 1 if any(hit) else 0
                    met["clip"] = clip
                    if clip > 0:
                        sus.append("clip")
    # ── boss 帧（截断/大小用首帧近似）──
    if boss_dir:
        p0 = os.path.join(ROOT, "assets/effects/unit_anims", boss_dir["dir"], "idle_f0.png")
        if os.path.isfile(p0):
            c = _content(_load(p0))
            if c:
                if c["white"] > WHITE_TH or c["mag"] > MAGENTA_TH:
                    sus.append("bg")
    # ── 朝向：卡图 vs idle 首帧（player 侧游戏内镜像后应与卡图同向）──
    flip = None
    if ic and idl:
        flip = anim.get("_flip", False) if anim else False
        s_icon = 1 if ic["cx"] > DEADZONE else (-1 if ic["cx"] < -DEADZONE else 0)
        s_sheet = 1 if idl["cx"] > DEADZONE else (-1 if idl["cx"] < -DEADZONE else 0)
        eff = -s_sheet if flip else s_sheet
        if s_icon != 0 and s_sheet != 0 and eff != s_icon:
            sus.append("face")
        met["cx_i"] = round(ic["cx"], 3); met["cx_s"] = round(idl["cx"], 3)
        # 与卡图尺寸悬殊
        r = idl["hfrac"] / max(ic["hfrac"], 1e-3)
        met["sz"] = round(r, 2)
        if r > SIZE_RATIO_HI or r < SIZE_RATIO_LO:
            sus.append("size")
            if calib:
                sus[-1] = "size_ratio"
        # 色板一致性（内容像素 4³ 直方图交）
        if ic["n"] > 200 and idl["n"] > 200:
            sim = float(np.minimum(_hist(ic["rgb"]), _hist(idl["rgb"])).sum())
            met["sim"] = round(sim, 3)
            if sim < HIST_SIM:
                sus.append("diff")
    # 卡图自身残留
    if ic and (ic["white"] > WHITE_TH * 2 or ic["mag"] > MAGENTA_TH):
        if "bg" not in sus:
            sus.append("bg")
    return sus, met


if __name__ == "__main__":
    import json, sys, io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    dump = json.load(open(os.path.join(ROOT, "_anim_review", "card_anim_dump.json"), encoding="utf-8"))
    stat = {}
    samples = {}
    szs = []
    sims = []
    for sec in ["players", "captured", "enemies", "platforms"]:
        for r in dump.get(sec, []):
            icon = ("../" + r["icon"][len("res://"):]) if r.get("icon") else None
            anim = r.get("anim")
            if anim:
                anim = dict(anim, _flip=sec in ("players", "captured"))
                for k in ("sheet_idle", "sheet_attack"):
                    anim[k] = ("../" + anim[k][len("res://"):]) if anim.get(k) else ""
            boss = {"dir": r["boss_dir"]} if r.get("boss_dir") else None
            sus, met = analyze_card(icon, anim, boss, None, calib=True)
            for s in sus:
                stat[s] = stat.get(s, 0) + 1
                samples.setdefault(s, []).append(r["id"])
            if "sz" in met:
                szs.append(met["sz"])
            if "sim" in met:
                sims.append(met["sim"])
    print("suspect dist:", stat)
    for s, ids in samples.items():
        print("  %s: %s" % (s, ",".join(ids[:12])))
    szs.sort(); sims.sort()
    def pct(a, q):
        return a[int(len(a) * q)] if a else 0
    print("sz p05=%s p10=%s p90=%s p95=%s" % (pct(szs, .05), pct(szs, .1), pct(szs, .9), pct(szs, .95)))
    print("sim p01=%s p05=%s p10=%s median=%s" % (pct(sims, .01), pct(sims, .05), pct(sims, .1), pct(sims, .5)))
