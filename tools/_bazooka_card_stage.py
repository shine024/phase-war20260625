# -*- coding: utf-8 -*-
"""bazooka 候选卡 → B4 部署配方预览（flood_white_to_alpha 238 → grow_alpha 215 →
fit_square 512,0.88），产 512 RGBA 暂存 + 暗/白双底审查拼图（含游戏内 ww2 参考行）。
只落 staging，不写 assets/。用法: python tools/_bazooka_card_stage.py"""
import io
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "bazooka_card_staging")


def load(name, path):
    lines = open(path, encoding="utf-8").read().split("\n")
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


img25 = load("bzk_img25", os.path.join(ROOT, "tools", "img25_card_sideview_redo.py"))

CANDS = ["cand_a", "cand_b", "cand_b_flip", "cand_c", "cand_c_flip"]

for cid in CANDS:
    src = os.path.join(STAGE, "%s_raw.png" % cid)
    if not os.path.exists(src):
        base = cid.replace("_flip", "")
        sp = os.path.join(STAGE, "%s_raw.png" % base)
        if not os.path.exists(sp):
            print("[skip] %s 无源" % cid)
            continue
        im = Image.open(sp)
        if cid.endswith("_flip"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(src)
    im = Image.open(src).convert("RGB")
    rgba = img25.flood_white_to_alpha(im, 238)
    rgba = img25.grow_alpha(rgba, 215, max_iter=30)
    out = img25.fit_square(rgba, 512, 0.88)
    out.save(os.path.join(STAGE, "%s_512.png" % cid))
    print("[512] %s %s" % (cid, out.size))

# 审查拼图：上排候选（暗底=游戏内观感，白底=卡面观感），下排参考
refs = [("ref_garand_para", "assets/card_icons/player/ww2_arm_garand_para.png"),
        ("ref_kar98k", "assets/card_icons/player/ww2_inf_kar98k.png"),
        ("ref_vis009_现病", "assets/card_icons/player/vis_player_009.png")]
T = 360
rows = len(CANDS)
p = Image.new("RGB", (T * 3 + 8, (T + 18) * len(CANDS) + (T + 18) * len(refs) + 10), (26, 28, 33))
d = ImageDraw.Draw(p)
y = 0
for cid in CANDS:
    fp = os.path.join(STAGE, "%s_512.png" % cid)
    if not os.path.exists(fp):
        continue
    im = Image.open(fp).convert("RGBA").resize((T, T), Image.LANCZOS)
    for j, bgc in enumerate(((24, 24, 28, 255), (240, 240, 238, 255), (90, 110, 90, 255))):
        bg = Image.new("RGBA", im.size, bgc)
        bg.alpha_composite(im)
        p.paste(bg.convert("RGB"), (j * (T + 4), y))
    d.text((4, y + T + 2), "%s  (左暗底/中白底/右草绿底)" % cid, fill=(255, 220, 120))
    y += T + 18
for n, rp in refs:
    im = Image.open(os.path.join(ROOT, rp)).convert("RGBA").resize((T, T), Image.LANCZOS)
    bg = Image.new("RGBA", im.size, (24, 24, 28, 255))
    bg.alpha_composite(im)
    p.paste(bg.convert("RGB"), (0, y))
    d.text((4, y + T + 2), n + "  (游戏内暗底观感)", fill=(160, 200, 255))
    y += T + 18
out = os.path.join(STAGE, "_review_montage.png")
p.save(out)
print("wrote", out)
