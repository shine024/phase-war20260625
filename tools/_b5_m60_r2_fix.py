# -*- coding: utf-8 -*-
"""cold_inf_m60 R2 拍板修复（2026-10-04 用户拍板：R2 动图可用但左右不分，另两卷删除）。

- R1/R3 全部产物移入 staging/_b5_backup_cold_inf_m60_20261004/（不硬删，可回）。
- R2 雪碧图上排 f1-f3 朝右 → 原位水平翻转，全卷朝左（翻转前 sheet 先备份）。
- 按 img25_attack_gen.sheet_direct 同款配方重组 R2 的 cells/anim.gif/pal8/cells_dark。
用法: python tools/_b5_m60_r2_fix.py
"""
import io
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_cold_inf_m60_20261004")
os.makedirs(BK, exist_ok=True)

# 1) R1/R3 移入备份
moves = []
for n in ("R1", "R3"):
    moves.append("cold_inf_m60_attack_raw_%s.png" % n)
    for suf in ("%s_attack_sheet_832.png", "%s_attack_cells.png", "%s_attack_cells_dark.png",
                "%s_attack_anim.gif", "%s_attack_anim_pal8.gif"):
        moves.append("cold_inf_m60_" + suf % n)
for f in moves:
    src = os.path.join(OUT, f)
    if os.path.exists(src):
        shutil.move(src, os.path.join(BK, f))
        print("moved →", f)
    else:
        print("(缺)", f)

# 2) R2 上排翻转（先备份原 sheet）
p = os.path.join(OUT, "cold_inf_m60_R2_attack_sheet_832.png")
shutil.copy2(p, os.path.join(BK, "cold_inf_m60_R2_attack_sheet_832.pre_flip.png"))
sheet = Image.open(p).convert("RGBA")
F = 832
for c in range(3):
    cell = sheet.crop((c * F, 0, (c + 1) * F, F)).transpose(Image.FLIP_LEFT_RIGHT)
    sheet.paste(cell, (c * F, 0))
sheet.save(p)
print("上排 f1-f3 已翻转为朝左")

# 3) 重组派生产物（配方同 img25_attack_gen.sheet_direct）
FS2 = 256
frames = [sheet.crop((c * F, r * F, (c + 1) * F, (r + 1) * F)).resize((FS2, FS2), Image.LANCZOS)
          for r in range(2) for c in range(3)]
contact = Image.new("RGBA", (FS2 * len(frames) + 8 * (len(frames) + 1), FS2 + 16), (70, 70, 70, 255))
for i, f in enumerate(frames):
    contact.paste(f, (8 + i * (FS2 + 8), 8), f)
contact.convert("RGB").save(os.path.join(OUT, "cold_inf_m60_R2_attack_cells.png"))

bgc = Image.new("RGBA", (FS2, FS2), (60, 60, 60, 255))
comp = []
for f in frames:
    b = bgc.copy()
    b.paste(f, (0, 0), f)
    comp.append(b.convert("RGB"))
comp[0].save(os.path.join(OUT, "cold_inf_m60_R2_attack_anim.gif"), save_all=True,
             append_images=comp[1:], duration=125, loop=0)
pal = [frames[i] for i in (0, 1, 2, 3, 5, 3, 2, 1)]
comp2 = []
for f in pal:
    b = bgc.copy()
    b.paste(f, (0, 0), f)
    comp2.append(b.convert("RGB"))
comp2[0].save(os.path.join(OUT, "cold_inf_m60_R2_attack_anim_pal8.gif"), save_all=True,
              append_images=comp2[1:], duration=125, loop=0)

cell = 212
g = Image.new("RGB", (3 * cell, 2 * cell), (40, 44, 52))
for i, f in enumerate(frames):
    fr = f.convert("RGBA").resize((cell, cell), Image.LANCZOS)
    g.paste(fr, (i % 3 * cell, i // 3 * cell), fr)
g.save(os.path.join(OUT, "cold_inf_m60_R2_attack_cells_dark.png"))
print("R2 派生产物重组完成（cells/anim/pal8/cells_dark）")
