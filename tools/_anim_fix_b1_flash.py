# -*- coding: utf-8 -*-
"""B1 批：攻击帧火光修复（擦错位火光 + 按实测炮口坐标重画）。

用法:
  python tools/_anim_fix_b1_flash.py            # 全量执行
  python tools/_anim_fix_b1_flash.py key,key2   # 只跑指定 anim_key
流程: 备份 → 12帧中位数差分擦旧火光/杂物 → frames 2-5 画新火光 → 拼回 sheet。
坐标为 2026-10-03 实测 (b1_measure_*.png)。xeno_stalker 爪痕特效单独处理，不在本批。
"""
import json, math, io, sys, os, random, shutil
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw, ImageFilter

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, ".godot", "art_backup_b1_flash_20261003")

# anim_key: muzzle(x,y), style, angle_deg(0=+x, 负=向上), color, 备注
PATCH = {
    "cold_arm_t55":        ((249, 153), "cannon",     0,    "warm"),
    "cold_t72":            ((251, 161), "cannon",     0,    "warm"),
    "cold_inf_btr60":      ((230, 126), "mg",         0,    "warm"),
    "cold_sup_bmp1_x":     ((78, 115),  "cannon",     180,  "warm"),
    "cold_sup_zsu23":      ((98, 46),   "cannon",     -150, "warm"),
    "fut_arm_hovertank":   ((233, 103), "energy",     0,    "purple"),
    "mod_arm_himars":      ((246, 90),  "rocket",     -35,  "warm"),
    "mod_fort_citadel":    ((130, 133), "energy",     0,    "cyan"),
    "mod_fort_phalanx":    ((64, 110),  "mg",         180,  "warm"),
    "mod_sup_m6":          ((90, 150),  "cannon",     180,  "warm"),
    "ww1_arm_rolls":       ((210, 106), "mg",         0,    "warm"),
    "ww1_arty_m81":        ((97, 61),   "mortar",     -150, "warm"),
    "ww1_fort_pillbox":    ((105, 90),  "mg",         180,  "warm"),
    "ww2_arm_sherman":     ((247, 146), "cannon",     0,    "warm"),
    "ww2_arty_hummel":     ((74, 92),   "big_cannon", 180,  "warm"),
    "ww2_fort_flak":       ((60, 78),   "big_cannon", -140, "warm"),
    "ww2_garand":          ((58, 40),   "rifle",      180,  "warm"),
    "ww2_inf_hellcat":     ((188, 117), "cannon",     0,    "warm"),
    "ww2_thompson":        ((84, 102),  "smg",        180,  "warm"),
    "cold_sam7":           ((228, 46),  "rocket",     -40,  "warm"),
    "fut_swarm":           ((58, 152),  "energy",     180,  "cyan"),
    "guardian_ww1_ironclad": ((50, 132), "cannon",    180,  "warm"),
}
FLASH_FRAMES = [2, 3, 4, 5]
FLASH_SCALE = [0.75, 1.0, 0.85, 0.6]

COL = {
    "warm":   {"core": (255, 246, 205), "mid": (255, 196, 92), "glow": (255, 128, 34), "smoke": (120, 112, 104)},
    "cyan":   {"core": (235, 252, 255), "mid": (150, 230, 255), "glow": (70, 160, 255), "smoke": (110, 130, 150)},
    "purple": {"core": (245, 235, 255), "mid": (205, 150, 255), "glow": (140, 80, 230), "smoke": (120, 105, 140)},
}


def anim_keys_from_dump():
    d = json.load(open(os.path.join(ROOT, "_anim_review", "card_anim_dump.json"), encoding="utf-8"))
    out = {}
    for sec in ("players", "enemies", "platforms", "captured"):
        for r in d.get(sec, []):
            if isinstance(r, dict) and r.get("anim_key"):
                out[r["id"]] = r["anim_key"]
    return out


def median_erase(frames):
    """逐像素中位数擦除：mask=与中位数差异大的像素，用中位数内容回填。"""
    arr = np.stack([np.asarray(f.convert("RGB"), dtype=np.int16) for f in frames])
    med = np.median(arr, axis=0)
    out = []
    for i, f in enumerate(frames):
        a = np.asarray(f.convert("RGB"), dtype=np.int16)
        diff = np.abs(a - med).sum(axis=2)
        mask = diff > 60  # 火光/高亮杂物
        # 连成片才算（孤立噪点保留）：简单膨胀一次
        m = mask.copy()
        m[1:, :] |= mask[:-1, :]; m[:-1, :] |= mask[1:, :]
        m[:, 1:] |= mask[:, :-1]; m[:, :-1] |= mask[:, 1:]
        res = np.asarray(f.convert("RGB")).copy()
        res[m] = np.asarray(med, dtype=np.uint8)[m]
        out.append(Image.fromarray(res).convert("RGBA"))
    return out


def _radial_glow(dr, x, y, r, col, a_max=110):
    for i in range(int(r), 0, -2):
        a = int(a_max * (1 - i / r) ** 1.6)
        dr.ellipse([x - i, y - i, x + i, y + i], fill=col["glow"] + (a,))


def _star(dr, x, y, r, col, rot, n=6):
    pts = []
    for k in range(n * 2):
        rr = r if k % 2 == 0 else r * 0.38
        ang = rot + math.pi * k / n
        pts.append((x + rr * math.cos(ang), y + rr * math.sin(ang)))
    dr.polygon(pts, fill=col["core"] + (235,))
    dr.ellipse([x - r * 0.45, y - r * 0.45, x + r * 0.45, y + r * 0.45], fill=col["mid"] + (255,))
    dr.ellipse([x - r * 0.22, y - r * 0.22, x + r * 0.22, y + r * 0.22], fill=(255, 255, 255, 255))


def draw_flash(fr, x, y, style, angle_deg, color, scale, rng):
    c = COL[color]
    ang = math.radians(angle_deg)
    dx, dy = math.cos(ang), math.sin(ang)
    rot = rng.uniform(0, 6.28)

    def P(t, s=0):  # 沿射击方向偏移 t 像素, 垂直偏移 s
        return (x + dx * t - dy * s, y + dy * t + dx * s)

    # 辉光层：单独画 + 高斯模糊，避免贴纸感
    glow = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)

    def G(t, s, r, a=110):
        gx, gy = P(t, s)
        for i in range(int(r), 0, -2):
            aa = int(a * (1 - i / r) ** 1.6)
            gd.ellipse([gx - i, gy - i, gx + i, gy + i], fill=c["glow"] + (aa,))

    ov = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)

    if style in ("rifle", "smg", "mg"):
        r = {"rifle": 13, "smg": 11, "mg": 15}[style] * scale
        G(0, 0, r * 2.0)
        # 锥形前焰
        L = r * 2.2
        w = r * 0.75
        p1, p2 = P(L * 0.2, -w), P(L, 0)
        p3 = P(L * 0.2, w)
        dr.polygon([p1, p2, p3], fill=c["mid"] + (220,))
        _star(dr, x, y, r, c, rot, n=5 if style != "mg" else 6)
        if style == "mg":  # 曳光点
            sp = P(L * 1.5)
            dr.ellipse([sp[0] - 2, sp[1] - 2, sp[0] + 2, sp[1] + 2], fill=c["mid"] + (200,))
    elif style in ("cannon", "big_cannon"):
        big = style == "big_cannon"
        r = (24 if big else 17) * scale
        L = (46 if big else 34) * scale
        G(0, 0, r * 2.2)
        # 主锥
        w = r * 0.9
        dr.polygon([P(L * 0.15, -w), P(L, -w * 0.25), P(L * 1.08, 0), P(L, w * 0.25), P(L * 0.15, w)],
                   fill=c["mid"] + (225,))
        # 侧瓣
        for s in (-1, 1):
            dr.polygon([P(r * 0.3, s * w * 0.5), P(L * 0.55, s * w * 1.25), P(r * 0.55, s * w * 0.9)],
                       fill=c["glow"] + (170,))
        _star(dr, x, y, r, c, rot, n=6)
        # 硝烟
        for k in range(3):
            t = L * (0.75 + 0.3 * k) + rng.uniform(-4, 4)
            s = rng.uniform(-w * 1.6, w * 1.6)
            cx, cy = P(t, s)
            rr = rng.uniform(4, 9) * scale
            dr.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c["smoke"] + (46,))
    elif style == "aaa":  # 双管高射：沿射向的双锥 + 共享核心星
        r = 13 * scale
        L = 34 * scale
        for off in (-6, 6):
            w = r * 0.55
            dr.polygon([P(L * 0.1, off - w), P(L * 0.55, off - w * 0.5), P(L, off),
                        P(L * 0.55, off + w * 0.5), P(L * 0.1, off + w)],
                       fill=c["mid"] + (215,))
        G(L * 0.25, 0, r * 2.4)
        _star(dr, *P(L * 0.18, 0), r, c, rot, n=6)
        for k in range(3):  # 高射炮性格：口部火花外溅
            a2 = ang + rng.uniform(-0.5, 0.5)
            rr = L * rng.uniform(0.8, 1.15)
            sx, sy = x + rr * math.cos(a2), y + rr * math.sin(a2)
            dr.ellipse([sx - 1.8, sy - 1.8, sx + 1.8, sy + 1.8], fill=c["core"] + (230,))
    elif style == "rocket":  # 尾焰长椭
        L = 44 * scale
        w = 9 * scale
        for t0, ww, col2, a in ((0, w * 1.5, c["mid"], 235), (L * 0.45, w, c["glow"], 200), (L * 0.8, w * 0.55, c["mid"], 150)):
            p1, p2 = P(t0, -ww), P(t0 + L * 0.35, ww)
            box = [min(p1[0], p2[0]) - 2, min(p1[1], p2[1]) - 2, max(p1[0], p2[0]) + 2, max(p1[1], p2[1]) + 2]
            dr.ellipse(box, fill=col2 + (a,))
        G(0, 0, 26 * scale)
        dr.ellipse([x - 5 * scale, y - 5 * scale, x + 5 * scale, y + 5 * scale], fill=c["core"] + (255,))
        for k in range(4):  # 火星
            t = L * rng.uniform(0.7, 1.3); s = rng.uniform(-w * 2.2, w * 2.2)
            sp = P(t, s)
            dr.ellipse([sp[0] - 1.6, sp[1] - 1.6, sp[0] + 1.6, sp[1] + 1.6], fill=c["mid"] + (220,))
    elif style == "mortar":  # 臼炮口爆，宽锥
        r = 20 * scale
        L = 34 * scale
        G(0, 0, r * 2.3)
        w = r * 1.15
        dr.polygon([P(2, -w), P(L, -w * 0.55), P(L * 1.12, 0), P(L, w * 0.55), P(2, w)],
                   fill=c["mid"] + (215,))
        _star(dr, x, y, r, c, rot, n=7)
    elif style == "energy":
        r = 20 * scale
        col = c["mid"]
        for k in range(3):
            rr = r * (1.5 - k * 0.42)
            a = 200 - k * 55
            dr.ellipse([x - rr, y - rr, x + rr, y + rr], outline=col + (a,), width=3)
        G(0, 0, r * 1.7)
        _star(dr, x, y, r * 0.8, c, rot, n=4)
        for k in range(5):  # 电弧点
            a2 = rng.uniform(0, 6.28); rr = r * rng.uniform(1.1, 1.9)
            sx, sy = x + rr * math.cos(a2), y + rr * math.sin(a2)
            dr.line([(x, y), (sx, sy)], fill=c["core"] + (160,), width=2)

    # 辉光模糊后合成
    glow = glow.filter(ImageFilter.GaussianBlur(4))
    fr = Image.alpha_composite(fr, glow)

    # 画框内收口：把 overlay 中越过 4px 边距的像素裁掉（防截断复发）
    pad = 4
    W = fr.size[0]
    px = np.asarray(ov).copy()
    if x < 30 or (W - x) < 30:  # 近边缘的火光整体向内压
        keep = (px[:, :, 3] > 0)
        ys, xs = np.where(keep)
        if len(xs):
            x0, x1 = xs.min(), xs.max()
            if x0 < pad:
                px[:, :pad, 3] = 0
            if x1 > W - 1 - pad:
                px[:, W - pad:, 3] = 0
    px[:pad, :, 3] = 0; px[fr.size[1] - pad:, :, 3] = 0; px[:, :pad, 3] = 0; px[:, W - pad:, 3] = 0
    ov = Image.fromarray(px)
    return Image.alpha_composite(fr, ov)


def process(key, spec, only):
    (x, y), style, angle, color = spec
    p = os.path.join(ROOT, "assets", "effects", "unit_anims", key, "sheet_attack.png")
    if not os.path.isfile(p):
        print("跳过(无sheet):", key); return False
    sh = Image.open(p).convert("RGBA")
    n = sh.width // 256
    frames = [sh.crop((i * 256, 0, (i + 1) * 256, 256)) for i in range(n)]
    frames = median_erase(frames)
    rng = random.Random(hash(key) & 0xffff)
    for i in FLASH_FRAMES:
        if i < n:
            s = FLASH_SCALE[i - FLASH_FRAMES[0]] if i - FLASH_FRAMES[0] < len(FLASH_SCALE) else 0.6
            jx = x + rng.randint(-2, 2); jy = y + rng.randint(-2, 2)
            frames[i] = draw_flash(frames[i], jx, jy, style, angle, color, s, rng)
    out = Image.new("RGBA", (256 * n, 256), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * 256, 0))
    bdir = os.path.join(BAK, key)
    os.makedirs(bdir, exist_ok=True)
    bp = os.path.join(bdir, "sheet_attack.png")
    if not os.path.isfile(bp):
        shutil.copy2(p, bp)
    out.save(p)
    print("OK", key, "frames=%d style=%s" % (n, style))
    return True


def main():
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
    keys = sorted(PATCH)
    ok = 0
    for k in keys:
        if only and k not in only:
            continue
        ok += bool(process(k, PATCH[k], only))
    print("done %d/%d" % (ok, len(keys)))


if __name__ == "__main__":
    main()
