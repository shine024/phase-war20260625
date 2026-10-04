# -*- coding: utf-8 -*-
"""MK8 收尾批（2026-10-05）：
A. mod_sup_m4_carbine 攻击手术：R1 选优（全部正侧），f2/f3 用 c1 干净身体贴双段 stinger
   （c2 火光锥脱位/c3 火花炸机匣，整格弃用），c4/c5/c6 原样收枪回复。
   512 帧落 img25_staging（B5 部署惯例），部署端 bake_outline。
B. 抬枪三 unit（marks: 先变攻击姿势 ×2 / 要做抬枪 ×1）：现役 idle f0 ×4 放大 →
   cutoutR 切层（色距抠枪层+竖向邻域修补，codeanim prep_cutoutr 同款改种子参数化）→
   RAISE_TL 12 帧抬枪时间线 + 开火窗 stinger + 沿瞄准轴后坐 → 256 横条落 mk8_staging。
产物全部 staging；部署另跑 _mk8_deploy.py。
用法: python tools/_mk8_finish.py [a|b|ab]
"""
import io
import json
import math
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT_B = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
STG8 = os.path.join(ROOT, ".godot", "unit_review", "mk8_staging")
STINGER = os.path.join(ROOT, ".godot", "unit_review", "img25_vfx", "mod_stinger_c2.png")
os.makedirs(STG8, exist_ok=True)

from PIL import Image  # noqa: E402
import numpy as np  # noqa: E402

_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)

STG_IMG = Image.open(STINGER).convert("RGBA")

# ── A: m4_carbine 攻击手术 ────────────────────────────────────────
# c1/c4/c6 朝右瞄准（muzzle 512 空间实测），c2 脱位火光/c3 炸机匣/c5 朝左 → 弃用
M4_SEQ = [  # (cell idx, flash scale @512, flash alpha)
    (0, 0.0, 1.0), (0, 0.9, 1.0), (0, 1.2, 1.0),
    (0, 0.5, 0.8), (3, 0.0, 1.0), (5, 0.0, 1.0),
]
M4_TIP = {0: (408, 148), 3: (415, 165), 5: (425, 155)}


def case_a():
    print("== A: m4_carbine attack surgery ==", flush=True)
    sh = Image.open(os.path.join(OUT_B, "mod_sup_m4_carbine_R1_attack_sheet_832.png")).convert("RGBA")
    cell = sh.width // 3
    c = [sh.crop(((i % 3) * cell, (i // 3) * cell, (i % 3 + 1) * cell, (i // 3 + 1) * cell))
         .resize((512, 512), Image.LANCZOS) for i in range(6)]
    frames = []
    for ci, sc, al in M4_SEQ:
        fr = c[ci].copy()
        if sc:
            arr = paste_stinger(np.asarray(fr).copy(), M4_TIP[ci], sc, al,
                                flip=True, anchor=0.25)   # 右朝向：火光向右绽放
            fr = Image.fromarray(arr)
        frames.append(fr)
    strip = Image.new("RGBA", (512 * 6, 512), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * 512, 0))
    strip.save(os.path.join(OUT_B, "mod_sup_m4_carbine_MK8_attack_sheet_512.png"))
    g = Image.new("RGB", (6 * 190, 206), (38, 42, 50))
    for i, f in enumerate(frames):
        g.paste(f.resize((190, 190), Image.LANCZOS), (i * 190, 16), f.resize((190, 190), Image.LANCZOS))
    g.save(os.path.join(STG8, "m4_attack_surgery.png"))
    print("[A] 6帧手术卷落 img25_staging/mod_sup_m4_carbine_MK8_attack_sheet_512.png", flush=True)


def paste_stinger(arr, tip, scale, alpha, flip=False, anchor=0.75):
    st = STG_IMG
    if flip:
        st = st.transpose(Image.FLIP_LEFT_RIGHT)
    w = max(2, int(st.width * scale)); h = max(2, int(st.height * scale))
    s = st.resize((w, h), Image.LANCZOS)
    if alpha < 1.0:
        a = s.getchannel("A").point(lambda v: int(v * alpha))
        s.putalpha(a)
    tx, ty = tip
    nx = int(tx - w * anchor); ny = int(ty - h / 2)
    arr_img = Image.fromarray(arr)
    arr_img.alpha_composite(s, (max(0, nx), max(0, ny)))
    return np.asarray(arr_img).copy()


# ── B: 抬枪三 unit ───────────────────────────────────────────────
RAISE_TL = {0: 0.0, 1: 0.5, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.7, 6: 0.4, 7: 0.15,
            8: 0.0, 9: 0.0, 10: 0.0, 11: 0.0}
GUNRAISE = {
    # 256 空间坐标（脚本内 ×4 到 1024）；deg=PIL rotate 角（右朝向正角=枪口上抬）。
    # 枪与装具同色系（10-05 色距抠层失败实证）→ 纯盒提取，只转前段枪管+前握手：
    # 支点=前握手，枪托留底图，接缝被手遮。
    "fe_frontier_veteran": dict(
        deg=38, muzzle=(214, 200), pivot=(183, 167), facing=1, recoil=10,
        band=(150, 112, 232, 215),
        boxes=[(174, 142, 222, 206)], hands=[(176, 156, 200, 184)], box_all=True,
        flash={2: 1.6, 3: 2.2, 4: 1.3}),
    "fe_void_dimensional_soldier": dict(
        deg=-29, muzzle=(80, 170), pivot=(105, 158), facing=-1, recoil=10,
        band=(52, 112, 150, 196),
        boxes=[(56, 134, 110, 178)], hands=[(86, 142, 118, 174)], box_all=True,
        flash={2: 1.4, 3: 2.0, 4: 1.2}),
    "fe_iron_wall_juggernaut": dict(
        deg=27, muzzle=(232, 183), pivot=(208, 168), facing=1, recoil=12,
        band=(150, 116, 250, 206),
        boxes=[(194, 146, 246, 200)], hands=[(196, 152, 226, 188)], box_all=True,
        flash={2: 2.0, 3: 2.8, 4: 1.6}),
}


def prep_gun(rgba, cfg):
    """cutoutR 切层（prep_cutoutr 改）：box_all 纯盒提取（枪装同色系单位）+ hands 并入。
    返回 (base_clean, rifle_layer, raised_muzzle)。坐标=传入图像自身空间。"""
    x0, y0, x1, y1 = cfg["band"]
    a = np.asarray(rgba).copy()
    band = a[y0:y1, x0:x1]
    rgb = band[:, :, :3].astype(int)
    opaque = band[:, :, 3] > 128
    mask0 = np.zeros_like(opaque)
    for (bx0, by0, bx1, by1) in cfg["boxes"]:    # 纯盒提取（box_all）
        mask0[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0] |= \
            opaque[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0]
    for (bx0, by0, bx1, by1) in cfg["hands"]:    # 前握手随枪走
        mask0[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0] |= \
            opaque[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0]
    r_, g_, b_ = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
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

    mask = _dil(mask0, 2) | (fringe & _dil(mask0, 5))
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
    mx, my = cfg["muzzle"]
    px, py = cfg["pivot"]
    t = math.radians(-cfg["deg"])
    c_, s_ = math.cos(t), math.sin(t)
    ox, oy = mx - px, my - py
    raised = (px + ox * c_ - oy * s_, py + ox * s_ + oy * c_)
    return base_clean, rifle_l, raised


def case_b():
    print("== B: gun-raise x3 ==", flush=True)
    for unit, cfg256 in GUNRAISE.items():
        _, _, idle = mk.load_frames(unit, "idle")
        f0 = idle[0].resize((1024, 1024), Image.LANCZOS)
        cfg = dict(cfg256)
        for k in ("muzzle", "pivot"):
            cfg[k] = tuple(v * 4 for v in cfg[k])
        cfg["band"] = tuple(v * 4 for v in cfg256["band"])
        cfg["boxes"] = [tuple(v * 4 for v in bx) for bx in cfg256["boxes"]]
        cfg["hands"] = [tuple(v * 4 for v in bx) for bx in cfg256["hands"]]
        base_clean, rifle, raised_mz = prep_gun(f0, cfg)
        n_op = int(np.asarray(rifle)[:, :, 3].__gt__(40).sum())
        print("  %s 枪层 px=%d" % (unit, n_op), flush=True)
        if n_op < 500:
            print("[B] %s 枪层过小，跳过（查 boxes）" % unit, flush=True)
            continue
        ax = cfg["facing"]          # 抬平后瞄准轴 ≈ 水平
        frames = []
        for f in range(12):
            theta = cfg["deg"] * RAISE_TL[f]
            fr = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
            fr.alpha_composite(base_clean)
            r = rifle.rotate(theta, center=cfg["pivot"], resample=Image.BICUBIC)
            t = f - 3
            wdx = int(cfg["recoil"] * pow(0.55, t)) if t >= 0 else 0
            off = (-ax * wdx, 0)
            fr.alpha_composite(r, off)
            sc = cfg["flash"].get(f, 0.0)
            if sc:
                tip = (raised_mz[0] + off[0], raised_mz[1] + off[1])
                arr = np.asarray(fr).copy()
                arr = paste_stinger(arr, tip, sc, 1.0,
                                    flip=cfg["facing"] > 0,
                                    anchor=0.25 if cfg["facing"] > 0 else 0.75)
                fr = Image.fromarray(arr)
            frames.append(fr.resize((256, 256), Image.LANCZOS))
        strip = Image.new("RGBA", (256 * 12, 256), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            strip.paste(f, (i * 256, 0))
        strip.save(os.path.join(STG8, "%s_attack_raised.png" % unit))
        g = Image.new("RGB", (13 * 96, 112), (38, 42, 50))
        g.paste(idle[0].resize((96, 96), Image.LANCZOS), (0, 16),
                idle[0].resize((96, 96), Image.LANCZOS))
        for i, f in enumerate(frames[:12]):
            g.paste(f.resize((96, 96), Image.LANCZOS), ((i + 1) * 96, 16),
                    f.resize((96, 96), Image.LANCZOS))
        g.save(os.path.join(STG8, "%s_raise_preview.png" % unit))
        print("[B] %s 抬枪卷落 mk8_staging（muzzle→%s）" % (unit, tuple(int(v) for v in raised_mz)),
              flush=True)


def main():
    which = (sys.argv[1] if len(sys.argv) > 1 else "ab").lower()
    if "a" in which:
        case_a()
    if "b" in which:
        case_b()
    print("MK8 收尾批结束", flush=True)


if __name__ == "__main__":
    main()
