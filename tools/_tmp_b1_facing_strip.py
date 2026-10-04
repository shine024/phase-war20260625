# -*- coding: utf-8 -*-
"""B1 朝向诊断条：frame0 放大 128px，红圈=锚点直读，青圈=镜像坐标。
哪个圈落在炮口上，朝向就定了（红=PA直读/EA直读按表，青=取反）。"""
import json, re, io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = json.load(open(os.path.join(ROOT, "_anim_review", "card_anim_dump.json"), encoding="utf-8"))
KEY = {}
for sec in ("players", "enemies", "platforms", "captured"):
    for r in DUMP.get(sec, []):
        if isinstance(r, dict) and r.get("anim_key"):
            KEY[r["id"]] = r["anim_key"]

def parse_anchors(path):
    txt = open(path, encoding="utf-8").read()
    out = {}
    # ff/hf 可选（EA 部分条目没有）
    for m in re.finditer(r'"([a-z0-9_]+)":\s*\{([^}]*)\}', txt):
        body = m.group(2)
        if "fireX" not in body:
            continue
        fx = re.search(r'"fireX":\s*([\d.]+)', body)
        fy = re.search(r'"fireY_pct":\s*([\d.]+)', body)
        ff = re.search(r'"ff":\s*([\d.]+)', body)
        if fx and fy:
            out[m.group(1)] = (float(fx.group(1)), float(fy.group(1)),
                               float(ff.group(1)) if ff else 0.35)
    return out

PA = parse_anchors(os.path.join(ROOT, "data", "player_muzzle_anchors.gd"))
EA = parse_anchors(os.path.join(ROOT, "data", "muzzle_anchors.gd"))

B1 = ["cold_arm_t55", "cold_arm_t72_e", "cold_inf_btr60", "cold_sup_bmp1_x",
      "cold_sup_zsu23", "fut_arm_hovertank_e", "mod_arm_himars", "mod_fort_citadel",
      "mod_fort_phalanx", "mod_sup_m6", "ww1_arm_rolls_e", "ww1_arty_m81",
      "ww1_fort_pillbox", "ww2_arm_sherman", "ww2_arty_hummel", "ww2_fort_flak",
      "ww2_inf_garand", "ww2_inf_hellcat", "ww2_inf_para_e", "ww2_inf_thompson",
      "xeno_stalker", "cold_sam7", "fut_swarm", "guardian_ww1_ironclad"]

def resolve(key):
    for k in (key, key[:-2] if key.endswith("_e") else key):
        if k in EA:
            return ("EA", EA[k])
        if k in PA:
            return ("PA", PA[k])
    return (None, None)

FS = 128
LBL = 190
rows = []
for key in B1:
    akey = KEY.get(key, key)
    p = os.path.join(ROOT, "assets", "effects", "unit_anims", akey, "sheet_attack.png")
    if not os.path.isfile(p):
        print("缺 sheet:", key, akey); continue
    sh = Image.open(p).convert("RGBA")
    fr = sh.crop((0, 0, 256, 256)).resize((FS, FS), Image.NEAREST)
    row = Image.new("RGBA", (LBL + FS, FS + 2), (24, 24, 28, 255))
    row.paste(fr, (LBL, 1), fr)
    d = ImageDraw.Draw(row)
    src, a = resolve(key)
    if a:
        fx, fy, ff = a
        y = (1 - ff - fy / 100.0) * FS
        xr, xm = fx * FS, (1 - fx) * FS
        d.ellipse([LBL + xr - 6, y - 6, LBL + xr + 6, y + 6], outline=(255, 50, 50), width=2)
        d.ellipse([LBL + xm - 6, y - 6, LBL + xm + 6, y + 6], outline=(60, 230, 230), width=2)
    d.text((4, 40), key, fill=(255, 220, 120))
    d.text((4, 58), "%s %s" % (akey, src or "!!无锚点"), fill=(150, 190, 255))
    if a:
        d.text((4, 76), "x=%.3f y=%.1f" % (a[0], y), fill=(200, 200, 200))
    rows.append(row)

H = sum(r.height + 2 for r in rows)
sheet = Image.new("RGBA", (LBL + FS, H), (16, 16, 20))
y = 0
for r in rows:
    sheet.paste(r, (0, y)); y += r.height + 2
out = os.path.join(ROOT, ".godot", "b1_facing.png")
sheet.convert("RGB").save(out)
print("rows=%d -> %s" % (len(rows), out))
