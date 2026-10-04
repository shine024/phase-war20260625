# -*- coding: utf-8 -*-
"""B1 火光落点实测条：frame0 原分辨率 + 32px 网格（粗线=64px 带坐标标注）。
读每单位炮口/枪口像素坐标 (x,y)，写进补丁表。分 3 张，每张 8 行。"""
import json, io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = json.load(open(os.path.join(ROOT, "_anim_review", "card_anim_dump.json"), encoding="utf-8"))
KEY = {}
for sec in ("players", "enemies", "platforms", "captured"):
    for r in DUMP.get(sec, []):
        if isinstance(r, dict) and r.get("anim_key"):
            KEY[r["id"]] = r["anim_key"]

B1 = ["cold_arm_t55", "cold_arm_t72_e", "cold_inf_btr60", "cold_sup_bmp1_x",
      "cold_sup_zsu23", "fut_arm_hovertank_e", "mod_arm_himars", "mod_fort_citadel",
      "mod_fort_phalanx", "mod_sup_m6", "ww1_arm_rolls_e", "ww1_arty_m81",
      "ww1_fort_pillbox", "ww2_arm_sherman", "ww2_arty_hummel", "ww2_fort_flak",
      "ww2_inf_garand", "ww2_inf_hellcat", "ww2_inf_para_e", "ww2_inf_thompson",
      "xeno_stalker", "cold_sam7", "fut_swarm", "guardian_ww1_ironclad"]

LBL = 168
FS = 256
CHUNK = 8
for ci in range(0, len(B1), CHUNK):
    rows = []
    for key in B1[ci:ci + CHUNK]:
        akey = KEY.get(key, key)
        p = os.path.join(ROOT, "assets", "effects", "unit_anims", akey, "sheet_attack.png")
        if not os.path.isfile(p):
            print("缺 sheet:", key, akey); continue
        sh = Image.open(p).convert("RGBA")
        fr = sh.crop((0, 0, 256, 256))
        row = Image.new("RGBA", (LBL + FS + 14, FS + 14), (24, 24, 28, 255))
        row.paste(fr, (LBL, 1), fr)
        d = ImageDraw.Draw(row)
        for g in range(0, 257, 32):
            major = (g % 64 == 0)
            col = (90, 90, 110) if major else (52, 52, 64)
            d.line([(LBL + g, 0), (LBL + g, FS)], fill=col)
            d.line([(LBL, g), (LBL + FS, g)], fill=col)
            if major:
                d.text((LBL + g + 1, FS + 1), str(g), fill=(140, 140, 160))
                d.text((LBL - 16, g + 1), str(g), fill=(140, 140, 160))
        d.text((4, 100), key, fill=(255, 220, 120))
        d.text((4, 118), akey, fill=(150, 190, 255))
        rows.append(row)
    H = sum(r.height + 2 for r in rows)
    sheet = Image.new("RGBA", (LBL + FS + 14, H), (16, 16, 20))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y)); y += r.height + 2
    out = os.path.join(ROOT, ".godot", "b1_measure_%d.png" % (ci // CHUNK))
    sheet.convert("RGB").save(out)
    print(out)
