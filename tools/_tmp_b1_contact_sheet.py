# -*- coding: utf-8 -*-
"""B1 24 单位攻击表会诊拼图：每行=一个单位 12 攻击帧，左侧标注 key + 锚点火点红圈。
红圈=锚点表换算到 256 帧坐标的枪口位置，供目验火光该画哪。"""
import json, re, io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WL = json.load(open(os.path.join(ROOT, "tools", "card_anim_redo_worklist.json"), encoding="utf-8"))
DUMP = json.load(open(os.path.join(ROOT, "_anim_review", "card_anim_dump.json"), encoding="utf-8"))

# anim_key 解析：dump players+enemies 按 id 找
KEY = {}
for sec in ("players", "enemies", "platforms", "captured"):
    for r in DUMP.get(sec, []):
        if isinstance(r, dict) and r.get("anim_key"):
            KEY[r["id"]] = (r["anim_key"], r.get("icon", ""))

# 锚点表解析（我方+敌方）
def parse_anchors(path):
    txt = open(path, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'"([a-z0-9_]+)":\s*\{[^}]*"fireX":\s*([\d.]+),\s*"fireY_pct":\s*([\d.]+),\s*"ff":\s*([\d.]+)', txt):
        out[m.group(1)] = (float(m.group(2)), float(m.group(3)), float(m.group(4)))
    return out
PA = parse_anchors(os.path.join(ROOT, "data", "player_muzzle_anchors.gd"))
EA = parse_anchors(os.path.join(ROOT, "data", "muzzle_anchors.gd"))

B1 = ["fam|cold_arm_t55", "fam|cold_arm_t72_e", "fam|cold_inf_btr60", "fam|cold_sup_bmp1_x",
      "fam|cold_sup_zsu23", "fam|fut_arm_hovertank_e", "fam|mod_arm_himars", "fam|mod_fort_citadel",
      "fam|mod_fort_phalanx", "fam|mod_sup_m6", "fam|ww1_arm_rolls_e", "fam|ww1_arty_m81",
      "fam|ww1_fort_pillbox", "fam|ww2_arm_sherman", "fam|ww2_arty_hummel", "fam|ww2_fort_flak",
      "fam|ww2_inf_garand", "fam|ww2_inf_hellcat", "fam|ww2_inf_para_e", "fam|ww2_inf_thompson",
      "fam|xeno_stalker", "ind|cold_sam7", "ind|fut_swarm", "ind|guardian_ww1_ironclad"]

FS = 64   # 每帧缩略
NCOL = 12
LBL = 150
rows = []
missing = []
for uid in B1:
    key = uid.split("|", 1)[1]
    akey, icon = KEY.get(key, (key, ""))
    adir = os.path.join(ROOT, "assets", "effects", "unit_anims", akey)
    p = os.path.join(adir, "sheet_attack.png")
    if not os.path.isfile(p):
        missing.append((uid, akey, "NO sheet"))
        continue
    sh = Image.open(p).convert("RGBA")
    n = sh.width // 256
    row = Image.new("RGBA", (LBL + FS * n, FS + 4), (24, 24, 28, 255))
    d = ImageDraw.Draw(row)
    anch = PA.get(key) or EA.get(key)
    for i in range(n):
        fr = sh.crop((i * 256, 0, (i + 1) * 256, 256)).resize((FS, FS))
        row.paste(fr, (LBL + i * FS, 2), fr)
        if anch and i in (0, 3, 6, 9):   # 抽样帧画火点红圈
            fx, fy, ff = anch
            cx = LBL + i * FS + fx * FS
            cy = 2 + (1 - ff - fy / 100.0) * FS
            d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], outline=(255, 40, 40, 255), width=2)
    d.text((4, FS // 2 - 12), uid.replace("fam|", "").replace("ind|", ""), fill=(255, 220, 120, 255))
    d.text((4, FS // 2 + 4), akey + ("" if anch else " 无锚点!"), fill=(150, 190, 255, 255) if anch else (255, 90, 90, 255))
    rows.append(row)

H = sum(r.height + 2 for r in rows)
W = max(r.width for r in rows)
sheet = Image.new("RGBA", (W, H), (16, 16, 20, 255))
y = 0
for r in rows:
    sheet.paste(r, (0, y)); y += r.height + 2
out = os.path.join(ROOT, ".godot", "b1_contact.png")
sheet.convert("RGB").save(out)
print("rows=%d -> %s" % (len(rows), out))
for m in missing:
    print("缺失:", m)
