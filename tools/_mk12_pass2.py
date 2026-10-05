# -*- coding: utf-8 -*-
"""MK12 部署稿第二遍手术（2026-10-05）。
起因：主手术表(_mk12_surgery.py)执行后逐帧目检发现——方向误判(77mm/mixed_company)、
a>8 阈值鬼影(stryker_m2/蜂后)、杀框边界差一线(av7/boss_av7)、原始自带垃圾
(gmc黑板/flak棕卷须/105mm f4反向残影/蜂后边缘断线)、品红楔块与描边(mp18_x/storm)。
铁律：
 - 不碰 _mk12_surgery.py 主表（镜像重复执行会翻回去）；
 - restore 只从 art_backup_mk12_sweep（第一遍手术前备份）取原始帧；
 - 本脚本自身改盘前再备份到 art_backup_mk12_pass2（backup_once）；
 - dry-run WARN-0 = 框/谓词错，禁止实跑。
用法:
  python tools/_mk12_pass2.py dry    # 只打印每 op 命中数
  python tools/_mk12_pass2.py run    # 备份+实跑+渲染 REPAIR2_*.png
"""
import io
import os
import sys
from collections import deque

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

import colorsys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
BK1 = os.path.join(ROOT, ".godot", "art_backup_mk12_sweep")          # 第一遍前
BK2 = os.path.join(ROOT, ".godot", "art_backup_mk12_pass2")          # 第二遍前
OUTD = os.path.join(ROOT, ".godot", "unit_review", "mk12_deploy_check")
FS = 256


# ---------- 谓词 ----------
def P_any(r, g, b, a):
    return a > 0

def P_white(r, g, b, a):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v > 0.60 and s < 0.25

def P_ghost(r, g, b, a):  # 主杀 a>8 留下的半透明残边
    return 0 < a <= 8

def P_dark18(r, g, b, a):  # 近黑（105mm f2 焰心黑洞）
    _, _, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v < 0.18

def P_brown(r, g, b, a):  # flak 棕卷须涂鸦（焰=高v 黄橙, 天然排除）
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 12 / 360 <= h <= 42 / 360 and 0.28 <= s <= 0.90 and v <= 0.62

def P_yg(r, g, b, a):  # 77mm 黄绿曳光残条（橄榄车身 v≤0.55 天然排除）
    h, _, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 70 / 360 <= h <= 100 / 360 and v > 0.55

def P_puff(r, g, b, a):  # 105mm f4 幻影烟团: 灰/粉烟(v>0.3), 保深色炮身+蓝紫rim(h195-255)
    h, _, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v > 0.3 and not (195 / 360 <= h <= 255 / 360)

def P_magpink(r, g, b, a):  # 品红楔块/描边（描边低饱和不受影响, 蓝电弧h200+安全）
    h, s, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 285 / 360 <= h <= 325 / 360 and s >= 0.38

PREDS = {"any": P_any, "white": P_white, "ghost": P_ghost,
         "dark18": P_dark18, "brown": P_brown, "yg": P_yg, "puff": P_puff}


# ---------- 基元 ----------
def load(key, base=ANIM):
    if base == ANIM:  # 现役目录式
        p = os.path.join(base, key, "sheet_attack.png")
    else:            # 备份平铺式 <key>_sheet_attack.png
        p = os.path.join(base, "%s_sheet_attack.png" % key)
    return Image.open(p).convert("RGBA")

def fr(im, f):  # f: 1-based
    return im.crop(((f - 1) * FS, 0, f * FS, FS))

def put(im, f, frame):
    im.paste(frame, ((f - 1) * FS, 0))

def backup_once(key):
    os.makedirs(BK2, exist_ok=True)
    dst = os.path.join(BK2, "%s_sheet_attack.png" % key)
    if not os.path.exists(dst):
        src = os.path.join(ANIM, key, "sheet_attack.png")
        Image.open(src).convert("RGBA").save(dst)
        return "backed-up"
    return "exists"

def do_kill(im, f, box, pred_name, thresh=0):
    x0, y0, x1, y1 = [int(round(c * FS)) for c in box]
    c = fr(im, f)
    px = c.load()
    pred = PREDS[pred_name]
    n = 0
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            r, g, b, a = px[xx, yy]
            if a > thresh and pred(r, g, b, a):
                px[xx, yy] = (0, 0, 0, 0)
                n += 1
    if n:
        put(im, f, c)  # PIL crop 是副本, 必须贴回
    return n

def do_mirror(im, f):
    put(im, f, fr(im, f).transpose(Image.FLIP_LEFT_RIGHT))
    return 1

def do_restore(im, f, key):
    orig = load(key, BK1)
    put(im, f, fr(orig, f))
    return 1

def do_magpink(im, f):  # 簇限品红杀: 簇>=6, 膨胀2
    c = fr(im, f)
    w, h = c.size
    px = c.load()
    seen = [[False] * w for _ in range(h)]
    kill = set()
    for yy in range(h):
        for xx in range(w):
            if seen[yy][xx]:
                continue
            r, g, b, a = px[xx, yy]
            if a <= 8 or not P_magpink(r, g, b, a):
                seen[yy][xx] = True
                continue
            q = deque([(xx, yy)])
            seen[yy][xx] = True
            pts = []
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                            seen[ny][nx] = True
                            r2, g2, b2, a2 = px[nx, ny]
                            if a2 > 8 and P_magpink(r2, g2, b2, a2):
                                q.append((nx, ny))
            if len(pts) >= 6:
                for (x, y) in pts:
                    for dx in (-2, -1, 0, 1, 2):
                        for dy in (-2, -1, 0, 1, 2):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < w and 0 <= ny < h:
                                kill.add((nx, ny))
    for (x, y) in kill:
        px[x, y] = (0, 0, 0, 0)
    if kill:
        put(im, f, c)  # PIL crop 是副本, 必须贴回
    return len(kill)


# ---------- 手术表 ----------
PASS2 = {
 "fe_frontier_mixed_company": [("restore_all",)],
 "ww1_arty_77mm": [
    # f3=第一遍误杀地影306px, 还原即愈; f6=还原镜像
    ("restore", [1, 2, 3, 6]),
    # f1: 黄绿曳光条 x2-23 y110-113 + x2列白点
    ("kill", 1, (0.0, 0.40, 0.10, 0.48), "yg"),
    ("kill", 1, (0.0, 0.40, 0.10, 0.48), "white"),
    # f2: 黄绿条 x14-24 y117-119 + x0-10 白点
    ("kill", 2, (0.04, 0.44, 0.11, 0.48), "yg"),
    ("kill", 2, (0.0, 0.40, 0.045, 0.50), "white")],
 "ww1_105mm": [
    # f2: 首遍暗杀造甜甜圈洞+角点误杀均系伤, 还原后镜像(ORIG f2 朝右)
    ("restore", [2]),
    ("mirror", [2]),
    # f4: 幻影炮残影 — 灰粉烟团(puff 保炮身/紫边) + 深色圆柱黑楔(any, 炮身止于x0.65)
    ("kill", 4, (0.60, 0.38, 0.945, 0.64), "puff"),
    ("kill", 4, (0.645, 0.38, 0.945, 0.64), "any"),
    ("kill", 4, (0.93, 0.38, 1.0, 0.55), "any"),
    ("kill", 4, (0.03, 0.35, 0.055, 0.62), "white")],
 "fe_aether_swarm_queen": [
    ("kill", 3, (0.955, 0.40, 1.0, 0.58), "any"),
    ("kill", 3, (0.0, 0.40, 0.055, 0.66), "ghost"),
    ("kill", 5, (0.0, 0.40, 0.04, 0.64), "any"),
    ("kill", 5, (0.04, 0.30, 0.11, 0.70), "ghost")],
 "mod_stryker_m2": [("kill", 5, (0.53, 0.32, 0.73, 0.55), "ghost")],
 "ww1_av7": [("kill", 2, (0.01, 0.70, 0.09, 0.87), "any")],
 "ww1_boss_av7": [
    ("kill", 2, (0.0, 0.20, 0.07, 0.72), "any"),
    ("kill", 4, (0.03, 0.42, 0.07, 0.62), "any"),
    ("kill", 5, (0.0, 0.32, 0.06, 0.62), "any")],
 "ww1_inf_mp18_x": [("magpink", f) for f in (1, 2, 3, 4, 5, 6)],
 "ww1_storm": [("magpink", f) for f in (1, 2, 3, 4, 5, 6)],
 "ww2_sup_gmc_truck": [
    ("kill", 3, (0.155, 0.64, 0.25, 0.745), "any"),
    ("kill", 6, (0.168, 0.475, 0.248, 0.605), "any")],
 "ww2_fort_flak": (
    [("kill", 3, (0.155, 0.16, 0.33, 0.44), "brown"),
     ("kill", 4, (0.06, 0.15, 0.33, 0.27), "brown"),
     ("kill", 4, (0.165, 0.16, 0.33, 0.44), "brown"),
     ("kill", 5, (0.06, 0.15, 0.34, 0.27), "brown"),
     ("kill", 5, (0.145, 0.16, 0.34, 0.42), "brown"),
     ("kill", 6, (0.185, 0.16, 0.33, 0.44), "brown")] +
    [("kill", f, (0.0, 0.78, 0.07, 0.95), "any") for f in (1, 2, 3, 4, 5, 6)]),
}


def run(dry):
    warn0 = []
    touched = {}
    for key, ops in PASS2.items():
        im = load(key)
        log = []
        for op in ops:
            kind = op[0]
            if kind == "restore_all":
                n = 0
                orig = load(key, BK1)
                for f in range(1, im.width // FS + 1):
                    put(im, f, fr(orig, f))
                    n += 1
                log.append("restore_all=%d" % n)
            elif kind == "restore":
                for f in op[1]:
                    do_restore(im, f, key)
                log.append("restore%s" % (op[1],))
            elif kind == "mirror":
                for f in op[1]:
                    do_mirror(im, f)
                log.append("mirror%s" % (op[1],))
            elif kind == "kill":
                n = do_kill(im, op[1], op[2], op[3])
                log.append("kill f%d %s %s=%d" % (op[1], op[2], op[3], n))
                if n == 0:
                    warn0.append((key, op))
            elif kind == "magpink":
                n = do_magpink(im, op[1])
                log.append("magpink f%d=%d" % (op[1], n))
                if n == 0:
                    warn0.append((key, op))
        touched[key] = (im, log)

    for key, (im, log) in touched.items():
        print("%-26s %s" % (key, " | ".join(log)))
    print("WARN-0: %d" % len(warn0))
    for key, op in warn0:
        print("  !! %s %s" % (key, op))
    if dry:
        print("DRY — 未写盘")
        return 1 if warn0 else 0

    for key, (im, log) in touched.items():
        st = backup_once(key)
        im.save(os.path.join(ANIM, key, "sheet_attack.png"))
        print("SAVED %s (%s)" % (key, st))
    return 0


def render():
    for key in PASS2:
        im = load(key)
        n = im.width // FS
        Z = 512
        tiles = [(f, fr(im, f).resize((Z, Z), Image.LANCZOS)) for f in range(1, n + 1)]
        out = Image.new("RGB", (Z * min(n, 6) + 8 * (min(n, 6) - 1), Z + 28), (24, 24, 28))
        d = ImageDraw.Draw(out)
        for k, (f, t) in enumerate(tiles[:6]):
            out.paste(t, (k * (Z + 8), 28))
            d.rectangle([k * (Z + 8), 0, k * (Z + 8) + 70, 26], fill=(20, 110, 60))
            d.text((k * (Z + 8) + 8, 4), "P2 %s f%d" % (key[:10], f), fill=(255, 255, 255))
        out.save(os.path.join(OUTD, "REPAIR2_%s.png" % key))
        print("OK REPAIR2_%s.png" % key)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "dry"
    rc = run(mode != "run")
    if mode == "run" and rc == 0:
        render()
    sys.exit(rc)
