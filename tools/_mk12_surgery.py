# -*- coding: utf-8 -*-
"""MK12 部署稿目审修复手术（2026-10-05）：72 卷全目审后的 44 单位修复表。
帧号一律 1-based；kill 框为 256^2 帧内比例 (x0,y0,x1,y1)；先杀后镜像的单位已在表内按序排列。
用法: python tools/_mk12_surgery.py [--dry]
备份: .godot/art_backup_mk12_sweep/<key>_sheet_attack.png (仅首份, 不覆盖)
复核: .godot/unit_review/mk12_deploy_check/REPAIR_<key>.png (768^2 变更帧拼图)
"""
import colorsys
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
BACKUP = os.path.join(ROOT, ".godot", "art_backup_mk12_sweep")
OUTD = os.path.join(ROOT, ".godot", "unit_review", "mk12_deploy_check")
FS = 256
Z = 768
DRY = "--dry" in sys.argv

# ---- 谓词 (r,g,b,a 0-255 / h,s,v 0-1) ----
def P_any(r, g, b, a):
    return a > 8

def P_white(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s < 0.30 and v > 0.60

def P_pale(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s < 0.30 and v > 0.55

def P_dark(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v < 0.45

def P_smoke(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s < 0.35 and 0.30 <= v <= 0.85

def P_yellowgreen(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 55 <= h * 360 <= 95 and s > 0.30

def P_bluetube(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 200 <= h * 360 <= 250 and s > 0.40

def P_beam(r, g, b, a):  # nano_drone 青白光束(避机身灰)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return (165 <= h * 360 <= 235 and s > 0.28) or (s < 0.20 and v > 0.82)

def P_ring(r, g, b, a):  # sherman 黑烟环(保橙焰)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v < 0.55 and s < 0.45

def P_flakball(r, g, b, a):  # fort_flak 白球+棕卷(保 s>0.6 焰)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return (s < 0.30 and v > 0.65) or (15 <= h * 360 <= 45 and 0.25 <= s <= 0.70 and v < 0.60)

def P_pale2(r, g, b, a):  # spetsnaz 灰楔(暗色枪管保留)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s < 0.35 and v > 0.45

def P_donut(r, g, b, a):  # sam7 暗圈(橄榄筒身 s/v 更高, 保留)
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v < 0.32 and s < 0.45

PREDS = {"any": P_any, "white": P_white, "pale": P_pale, "pale2": P_pale2,
         "dark": P_dark, "smoke": P_smoke, "yellowgreen": P_yellowgreen,
         "bluetube": P_bluetube, "beam": P_beam, "ring": P_ring,
         "flakball": P_flakball, "donut": P_donut}

# ---- 手术表 (顺序即执行序; kill 在 mirror 前的单位已排好) ----
OPS = {
 "cold_arm_t55": [("copy", 3, 2), ("copy", 6, 1)],
 "fe_aether_hover_cavalry": [("recolor", 6, (0.05, 0.30, 0.35, 0.75), (80, 160), 185, 0.35)],
 "fe_aether_swarm_queen": [
    ("kill", 3, (0, 0.40, 0.055, 0.66), "any"),
    ("kill", 5, (0.04, 0.30, 0.11, 0.70), "any"),
    ("kill", 5, (0.92, 0.06, 1.0, 0.22), "any"),
    ("kill", 5, (0.92, 0.72, 1.0, 0.92), "any"),
    ("recolor", 5, (0, 0.25, 0.45, 0.85), (8, 45), 190, 0.35),
    ("kill", 6, (0.94, 0.40, 1.0, 0.68), "white")],
 "fe_frontier_mixed_company": [("mirror_strip",)],
 "fe_frontier_veteran": [("mirror_strip",)],
 "fe_iron_wall_juggernaut": [("mirror", [2, 5, 6])],
 "fe_quantum_mobile_base": [("copy", 1, 2)],
 "fut_space_fighter": [("mirror", [1])],
 "fut_inf_x9": [("mirror_strip",), ("magenta_all",)],
 "fut_nano_drone": [
    ("kill", 4, (0, 0.44, 0.34, 0.54), "any"),
    ("kill", 4, (0.34, 0.42, 0.46, 0.60), "beam"),
    ("mirror_strip",)],
 "fut_air_drone": [("mirror", [1, 4]), ("copy", 5, 6)],
 "fut_stealth_bomber": [("mirror_strip",)],
 "mod_ah64": [("mirror", [1, 4])],
 "mod_air_multirole": [("mirror_strip",)],
 "mod_sup_m4_carbine": [("mirror", [1, 2, 4, 6])],
 "mod_arm_himars": [("mirror", [3, 6])],
 "mod_arm_m1a2sep": [("mirror", [1])],
 "mod_stryker": [("mirror", [5])],
 "mod_stryker_m2": [("kill", 5, (0.575, 0.33, 0.68, 0.515), "any")],
 "ww1_105mm": [
    ("kill", 2, (0.86, 0.86, 1.0, 1.0), "any"),
    ("kill", 2, (0.68, 0.32, 0.90, 0.60), "dark"),
    ("mirror", [2]),
    ("kill", 4, (0.60, 0.02, 1.0, 0.42), "any"),
    ("kill", 4, (0, 0.35, 0.03, 0.65), "any"),
    ("kill", 5, (0, 0.25, 0.35, 0.75), "bluetube")],
 "ww1_arty_77mm": [
    ("kill", 1, (0, 0.35, 0.08, 0.65), "yellowgreen"),
    ("mirror", [1]),
    ("kill", 2, (0, 0.35, 0.08, 0.65), "yellowgreen"),
    ("kill", 3, (0, 0.25, 0.08, 0.55), "any"),
    ("mirror", [6])],
 "ww1_arty_m81": [("copy", 4, 3)],
 "ww1_av7": [("kill", 2, (0, 0.20, 0.07, 0.80), "any"), ("feather", 5, 10)],
 "ww1_boss_av7": [
    ("kill", 2, (0, 0.20, 0.05, 0.70), "any"),
    ("kill", 4, (0.02, 0.88, 0.14, 1.0), "any"),
    ("kill", 5, (0.80, 0.28, 1.0, 0.68), "smoke")],
 "ww1_a7v": [("copy", 4, 3)],
 "ww1_fort_artillery": [("mirror", [1]), ("copy", 3, 4)],
 "ww1_inf_mp18_x": [("mirror", [1, 2, 3, 4, 5])],
 "ww1_lanchest": [
    ("copy", 5, 6),
    ("kill", 3, (0, 0.52, 0.10, 0.66), "white"),
    ("kill", 3, (0.02, 0.88, 0.14, 1.0), "dark")],
 "ww1_mark4": [("copy", 4, 6), ("mirror_strip",)],
 "ww1_storm": [("mirror", [1, 4, 5])],
 "ww1_mauser": [("copy", 1, 2)],
 "ww2_arm_garand_para": [("mirror", [1])],
 "ww2_arty_m81": [("copy", 2, 3), ("copy", 6, 1)],
 "ww2_fort_bunker": [("copy", 2, 3)],
 "ww2_inf_bazooka": [("mirror", [3, 6])],
 "ww2_inf_hellcat": [("copy", 2, 4), ("copy", 3, 4)],
 "ww2_inf_kar98k": [("copy", 1, 3), ("copy", 4, 3)],
 "ww2_sup_gmc_truck": [
    ("kill", 2, (0, 0.08, 0.55, 0.45), "any"),
    ("copy", 4, 2),
    ("kill", 3, (0.16, 0.65, 0.24, 0.78), "any"),
    ("kill", 6, (0.17, 0.48, 0.24, 0.60), "any")],
 "ww2_arm_sherman": [
    ("kill", 3, (0.62, 0.08, 0.85, 0.45), "ring"),
    ("kill", 4, (0.75, 0.05, 1.0, 0.50), "ring"),
    ("kill", 5, (0.75, 0.05, 1.0, 0.50), "ring"),
    ("kill", 6, (0.80, 0.05, 1.0, 0.50), "ring")],
 "ww2_fort_flak": [("kill", f, (0.15, 0.0, 0.85, 0.60), "flakball") for f in (3, 4, 5, 6)],
 "cold_sam7": [("kill", f, (0.82, 0.10, 1.0, 0.31), "donut") for f in (3, 4, 5, 6)],
 "cold_spetsnaz": [("magenta", 2), ("kill", 4, (0.26, 0.29, 0.37, 0.44), "pale2")],
 "cold_bradley": [("magenta", 4), ("kill", 5, (0.50, 0.42, 0.80, 0.68), "pale")],
 "vis_xeno_adept": [("copy", 2, 1), ("copy", 3, 4)],
}


def load(key):
    return Image.open(os.path.join(ANIM, key, "sheet_attack.png")).convert("RGBA")


def frame(im, f1):
    i = f1 - 1
    return im.crop((i * FS, 0, (i + 1) * FS, FS))


def put(im, f1, fr):
    i = f1 - 1
    im.paste(fr, (i * FS, 0))


def magenta_kill(fr):
    """品红/紫地影: h195-250, s>=110/255, 簇>=120, 膨胀2 (已验证配方)."""
    px = fr.load()
    cand = set()
    for y in range(fr.height):
        for x in range(fr.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 195 <= h * 360 <= 250 and s >= 110 / 255:
                cand.add((x, y))
    seen, kill = set(), set()
    for p in cand:
        if p in seen:
            continue
        comp, stack = [], [p]
        seen.add(p)
        while stack:
            cx, cy = stack.pop()
            comp.append((cx, cy))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (cx + dx, cy + dy)
                    if q in cand and q not in seen:
                        seen.add(q)
                        stack.append(q)
        if len(comp) >= 120:
            kill.update(comp)
    dil = set()
    for (x, y) in kill:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                dil.add((x + dx, y + dy))
    n = 0
    for (x, y) in dil:
        if 0 <= x < fr.width and 0 <= y < fr.height:
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (r, g, b, 0)
                n += 1
    return n


def do_kill(fr, box, pred):
    x0, y0, x1, y1 = [int(round(v * FS)) for v in box]
    px = fr.load()
    n = 0
    for y in range(max(0, y0), min(fr.height, y1)):
        for x in range(max(0, x0), min(fr.width, x1)):
            r, g, b, a = px[x, y]
            if a > 0 and pred(r, g, b, a):
                px[x, y] = (r, g, b, 0)
                n += 1
    return n


def do_recolor(fr, box, hrange, htarget, smin):
    x0, y0, x1, y1 = [int(round(v * FS)) for v in box]
    px = fr.load()
    n = 0
    for y in range(max(0, y0), min(fr.height, y1)):
        for x in range(max(0, x0), min(fr.width, x1)):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > smin and hrange[0] <= h * 360 <= hrange[1]:
                r2, g2, b2 = colorsys.hsv_to_rgb(htarget / 360, s, v)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
                n += 1
    return n


def do_feather(fr, w):
    px = fr.load()
    n = 0
    for y in range(fr.height):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (r, g, b, int(a * (x + 1) / w))
                n += 1
    return n


def main():
    os.makedirs(OUTD, exist_ok=True)
    if not DRY:
        os.makedirs(BACKUP, exist_ok=True)
    report = []
    for key, ops in OPS.items():
        path = os.path.join(ANIM, key, "sheet_attack.png")
        im = load(key)
        n = im.width // FS
        bk = os.path.join(BACKUP, "%s_sheet_attack.png" % key)
        if not DRY and not os.path.exists(bk):
            im.save(bk)
        touched = []
        lines = []
        bad = False
        for op in ops:
            kind = op[0]
            if kind == "kill":
                _, f, box, pname = op
                fr = frame(im, f)
                cnt = do_kill(fr, box, PREDS[pname])
                put(im, f, fr)
                touched.append(f)
                flag = " <<WARN-0" if cnt == 0 else (" <<BIG" if cnt > 8000 else "")
                lines.append("  f%d kill %s %s -> %d%s" % (f, pname, box, cnt, flag))
                bad = bad or cnt == 0
            elif kind == "copy":
                _, dst, src = op
                put(im, dst, frame(im, src))
                touched += [dst]
                lines.append("  f%d <- f%d copy" % (dst, src))
            elif kind == "mirror":
                fs_ = op[1]
                for f in fs_:
                    put(im, f, frame(im, f).transpose(Image.FLIP_LEFT_RIGHT))
                touched += fs_
                lines.append("  mirror f%s" % ",".join(map(str, fs_)))
            elif kind == "mirror_strip":
                for f in range(1, n + 1):
                    put(im, f, frame(im, f).transpose(Image.FLIP_LEFT_RIGHT))
                touched += list(range(1, n + 1))
                lines.append("  mirror_strip all %d" % n)
            elif kind == "recolor":
                _, f, box, hrange, ht, smin = op
                fr = frame(im, f)
                cnt = do_recolor(fr, box, hrange, ht, smin)
                put(im, f, fr)
                touched.append(f)
                flag = " <<WARN-0" if cnt == 0 else (" <<BIG" if cnt > 8000 else "")
                lines.append("  f%d recolor h%s->%d -> %d%s" % (f, hrange, ht, cnt, flag))
                bad = bad or cnt == 0
            elif kind == "feather":
                _, f, w = op
                fr = frame(im, f)
                cnt = do_feather(fr, w)
                put(im, f, fr)
                touched.append(f)
                lines.append("  f%d feather %dpx -> %d" % (f, w, cnt))
            elif kind == "magenta":
                f = op[1]
                fr = frame(im, f)
                cnt = magenta_kill(fr)
                put(im, f, fr)
                touched.append(f)
                flag = " <<WARN-0" if cnt == 0 else (" <<BIG" if cnt > 8000 else "")
                lines.append("  f%d magenta_kill -> %d%s" % (f, cnt, flag))
                bad = bad or cnt == 0
            elif kind == "magenta_all":
                tot = 0
                for f in range(1, n + 1):
                    fr = frame(im, f)
                    tot += magenta_kill(fr)
                    put(im, f, fr)
                touched += list(range(1, n + 1))
                lines.append("  magenta_all %d frames -> %d" % (n, tot))
                bad = bad or tot == 0
        if not DRY:
            im.save(path)
        # 复核拼图 (dry 也出, 用内存态)
        tiles = []
        for f in sorted(set(touched)):
            tiles.append((f, frame(im, f).resize((Z, Z), Image.LANCZOS)))
        W = Z * len(tiles)
        out = Image.new("RGBA", (W, Z + 28), (24, 24, 28, 255))
        d = ImageDraw.Draw(out)
        for k, (f, t) in enumerate(tiles):
            out.paste(t, (k * Z, 28))
            d.rectangle([k * Z, 0, k * Z + 64, 26], fill=(20, 90, 30, 255))
            d.text((k * Z + 8, 4), "f%d" % f, fill=(255, 255, 255, 255))
        out.convert("RGB").save(os.path.join(OUTD, "REPAIR_%s.png" % key))
        report.append((key, bad))
        print("[%s] %s%s" % ("DRY" if DRY else "DONE", key, "  <<WARN-0-KILL!" if bad else ""))
        for ln in lines:
            print(ln)
    nwarn = sum(1 for _, b in report if b)
    print("\nSUMMARY units=%d warn0=%d %s" % (len(report), nwarn,
          "(见 <<WARN-0)" if nwarn else "all-ok"))


if __name__ == "__main__":
    main()
