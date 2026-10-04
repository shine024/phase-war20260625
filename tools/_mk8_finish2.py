# -*- coding: utf-8 -*-
"""MK8 收尾批 2（2026-10-05）：fe_frontier_veteran 抬枪手术修正版。
第一轮失败根因（gunzoom 网格实测）：旧 muzzle(214,200)/pivot(183,167) 偏了 ~40px，
量到膝盖上了；真实枪管 = 前手 (186,126) → 枪口 (214,158)，护木前段悬空。
只转前握手以前段（box_all 纯盒阶梯盒），枪托/机匣留底图。
产物落 mk8_staging；部署另跑。用法: python tools/_mk8_finish2.py
"""
import io
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG8 = os.path.join(ROOT, ".godot", "unit_review", "mk8_staging")

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402


def load(name, path):
    src = open(path, encoding="utf-8").read()
    # 只剥顶层 wrapper 行（startswith）；嵌套引用该串的行必须保留（10-05 二次踩坑）
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


m8 = load("mk8_m8", os.path.join(ROOT, "tools", "_mk8_finish.py"))


def prep_gun2(rgba, cfg):
    """prep_gun 改：box_all 基础上叠焰色门（排除烘焙描边/辉光 13,18,28 系：
    B>R+4 且暗 → 焰），dilate 降到 1。返回 (base_clean, rifle_layer, raised_muzzle)。"""
    import math
    x0, y0, x1, y1 = cfg["band"]
    a = np.asarray(rgba).copy()
    band = a[y0:y1, x0:x1]
    rgb = band[:, :, :3].astype(int)
    opaque = band[:, :, 3] > 128
    r_, g_, b_ = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mx = rgb.max(axis=2)
    glow = (b_ > r_ + 4) & (mx < 60)          # 烘焙描边/暗蓝辉光
    body_px = opaque & ~glow
    mask0 = np.zeros_like(opaque)
    for (bx0, by0, bx1, by1) in cfg["boxes"] + cfg["hands"]:
        mask0[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0] |= \
            body_px[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0]
    fringe = (r_ > g_ + 8) & (r_ > b_ + 8) & (band[:, :, 3] > 0)

    def _dil(m, n):
        for _ in range(n):
            g2 = np.zeros_like(m)
            g2[1:, :] |= m[:-1, :]
            g2[:-1, :] |= m[1:, :]
            g2[:, 1:] |= m[:, :-1]
            g2[:, :-1] |= m[:, 1:]
            m = g2
        return m

    mask = _dil(mask0, 1) | (fringe & _dil(mask0, 3))
    clean = band.copy()
    h, w = mask.shape
    AIR = 128
    for x in range(w):
        col = mask[:, x]
        if not col.any():
            continue
        ys = np.where(col)[0]
        runs = np.split(ys, np.where(np.diff(ys) != 1)[0] + 1)
        for run in runs:
            top, bot = run[0] - 1, run[-1] + 1
            ca = band[top, x].astype(float) if top >= 0 else None
            cb = band[bot, x].astype(float) if bot < h else None
            ok_a = ca is not None and ca[3] > AIR
            ok_b = cb is not None and cb[3] > AIR
            n = len(run)
            for i, yy in enumerate(run):
                t = (i + 1) / (n + 1)
                if ok_a and ok_b:
                    clean[yy, x] = (ca * (1 - t) + cb * t).astype(np.uint8)
                elif ok_a:
                    px_ = ca.copy()
                    px_[3] = ca[3] * (1 - t)
                    clean[yy, x] = px_.astype(np.uint8)
                elif ok_b:
                    px_ = cb.copy()
                    px_[3] = cb[3] * t
                    clean[yy, x] = px_.astype(np.uint8)
                else:
                    clean[yy, x] = (0, 0, 0, 0)
    a[y0:y1, x0:x1] = clean
    base_clean = Image.fromarray(a)
    rifle = rgba.copy()
    ra = np.asarray(rifle).copy()
    m = np.zeros(ra.shape[:2], bool)
    m[y0:y1, x0:x1] = mask
    ra[:, :, 3][~m] = 0
    rifle_l = Image.fromarray(ra)
    mxp, myp = cfg["muzzle"]
    px, py = cfg["pivot"]
    t = math.radians(-cfg["deg"])
    c_, s_ = math.cos(t), math.sin(t)
    ox, oy = mxp - px, myp - py
    raised = (px + ox * c_ - oy * s_, py + ox * s_ + oy * c_)
    return base_clean, rifle_l, raised

UNIT = "fe_frontier_veteran"
# 256 空间坐标（extract_debug 叠加图实测）：枪口 (190,158)，前手 (172,130)，
# 枪管下垂 57°；deg=48 → 枪口 (205,135)，指向略下压，自然瞄准角
VET = dict(
    deg=48, muzzle=(190, 158), pivot=(172, 130), facing=1, recoil=8,
    band=(150, 100, 220, 170),
    boxes=[(164, 116, 184, 140), (170, 130, 192, 156), (178, 142, 194, 162)],
    hands=[(164, 118, 182, 138)], box_all=True,
    flash={2: 1.5, 3: 2.1, 4: 1.2},
)
RAISE_TL = m8.RAISE_TL


def main():
    cfg256 = VET
    _, _, idle = m8.mk.load_frames(UNIT, "idle")
    f0 = idle[0].resize((1024, 1024), Image.LANCZOS)
    cfg = dict(cfg256)
    for k in ("muzzle", "pivot"):
        cfg[k] = tuple(v * 4 for v in cfg[k])
    cfg["band"] = tuple(v * 4 for v in cfg256["band"])
    cfg["boxes"] = [tuple(v * 4 for v in bx) for bx in cfg256["boxes"]]
    cfg["hands"] = [tuple(v * 4 for v in bx) for bx in cfg256["hands"]]

    # ── 调试：提取掩膜叠加图（红=被切走旋转的像素）───────────────
    dbg = f0.convert("RGBA")
    x0, y0, x1, y1 = cfg["band"]
    a = np.asarray(f0).copy()
    band = a[y0:y1, x0:x1]
    opaque = band[:, :, 3] > 128
    rgb = band[:, :, :3].astype(int)
    glow = (rgb[:, :, 2] > rgb[:, :, 0] + 4) & (rgb.max(axis=2) < 60)
    body_px = opaque & ~glow
    mask0 = np.zeros_like(opaque)
    for (bx0, by0, bx1, by1) in cfg["boxes"] + cfg["hands"]:
        mask0[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0] |= \
            body_px[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0]
    da = np.asarray(dbg).copy()
    region = da[y0:y1, x0:x1]
    region[mask0] = (255, 40, 40, 255)
    da[y0:y1, x0:x1] = region
    Image.fromarray(da).save(os.path.join(STG8, "vet_extract_debug.png"))
    print("[dbg] vet_extract_debug.png 落盘（红=枪层）", flush=True)

    base_clean, rifle, raised_mz = prep_gun2(f0, cfg)
    n_op = int(np.asarray(rifle)[:, :, 3].__gt__(40).sum())
    print("  枪层 px=%d → muzzle %s" % (n_op, tuple(int(v) for v in raised_mz)), flush=True)
    if n_op < 500:
        print("[!] 枪层过小，查 debug 叠加图", flush=True)
        return

    frames = []
    for f in range(12):
        theta = cfg["deg"] * RAISE_TL[f]
        fr = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        fr.alpha_composite(base_clean)
        r = rifle.rotate(theta, center=cfg["pivot"], resample=Image.BICUBIC)
        t = f - 3
        wdx = int(cfg["recoil"] * pow(0.55, t)) if t >= 0 else 0
        off = (-cfg["facing"] * wdx, 0)
        fr.alpha_composite(r, off)
        sc = cfg["flash"].get(f, 0.0)
        if sc:
            tip = (raised_mz[0] + off[0], raised_mz[1] + off[1])
            arr = np.asarray(fr).copy()
            arr = m8.paste_stinger(arr, tip, sc, 1.0, flip=True, anchor=0.25)
            fr = Image.fromarray(arr)
        frames.append(fr.resize((256, 256), Image.LANCZOS))

    strip = Image.new("RGBA", (256 * 12, 256), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * 256, 0))
    strip.save(os.path.join(STG8, "%s_attack_raised.png" % UNIT))

    g = Image.new("RGB", (13 * 96, 112), (38, 42, 50))
    g.paste(idle[0].resize((96, 96), Image.LANCZOS), (0, 16),
            idle[0].resize((96, 96), Image.LANCZOS))
    for i, f in enumerate(frames):
        g.paste(f.resize((96, 96), Image.LANCZOS), ((i + 1) * 96, 16),
                f.resize((96, 96), Image.LANCZOS))
    g.save(os.path.join(STG8, "%s_raise_preview.png" % UNIT))

    z = Image.new("RGB", (5 * 512 + 48, 528), (38, 42, 50))
    for i, fi in enumerate([0, 2, 3, 4, 8]):
        f = frames[fi].resize((512, 512), Image.NEAREST)
        z.paste(f, (8 + i * 520, 8), f)
    z.save(os.path.join(STG8, "%s_zoom.png" % UNIT))
    print("[B] %s 修正抬枪卷落 mk8_staging" % UNIT, flush=True)


if __name__ == "__main__":
    main()
