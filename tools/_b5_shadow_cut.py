# -*- coding: utf-8 -*-
"""拍板 v3 备注「抠阴影」三案手术（2026-10-04）：
1) ww1_sup_mg_nest idle：三脚架间/后半透明灰影 → 底 45% 带 sat<15 v∈[100,225] CC≥400 清除。
2) ww2_air_bomber R2：机腹下不透明灰椭圆（3×2 格 832）→ 每格 sat<14 v∈[100,205] CC area≥2000 &
   w/h≥1.8 & y0>半格 清除（机身灰件竖小块不中）。
3) ww1_arty_77mm SF：边缘半透明灰晕+暗粉边 → 半透明灰（a<210, sat<16, v 70-235）清 +
   暗粉边补刀（r-g>18 & b-g>12 & r>105，边缘 2px 环带内）。
清除后 1px 羽化；重建派生品（cells_dark/gif/preview）。旧件先移备份。
用法: python tools/_b5_shadow_cut.py
"""
import io
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_shadow_20261004")
os.makedirs(BK, exist_ok=True)


def backup(fn):
    p = os.path.join(OUT, fn)
    if os.path.exists(p):
        shutil.move(p, os.path.join(BK, fn))


def feather_zero(rgba, kill):
    """kill 掩膜零 alpha + 1px 羽化。"""
    k = ndimage.binary_dilation(kill, iterations=1)
    rgba[:, :, 3][k] = 0
    return rgba


def grey_shadow_cut(rgba, satmax, vlo, vhi, min_area, band_lo=None, aspect_min=None, y0_min=None):
    """中性灰影 CC 清除。band_lo: 相对 subject bbox 的底部带宽(0-1)；aspect_min/y0_min: 组件几何门。"""
    a = rgba[:, :, 3]
    r, g, b = rgba[:, :, 0].astype(int), rgba[:, :, 1].astype(int), rgba[:, :, 2].astype(int)
    sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    v = np.maximum(np.maximum(r, g), b)
    m = (a > 8) & (sat < satmax) & (v > vlo) & (v < vhi)
    if band_lo is not None:
        ys, _xs = np.where(a > 8)
        y0, y1 = ys.min(), ys.max()
        cut = y1 - int((y1 - y0) * band_lo)
        m &= (np.arange(rgba.shape[0]) > cut)[:, None]
    lab, n = ndimage.label(m)
    kill = np.zeros_like(m)
    for i in range(1, n + 1):
        cys, cxs = np.where(lab == i)
        area = len(cys)
        if area < min_area:
            continue
        w = cxs.max() - cxs.min() + 1
        h = cys.max() - cys.min() + 1
        if aspect_min is not None and w / h < aspect_min:
            continue
        if y0_min is not None and cys.min() < y0_min:
            continue
        kill |= lab == i
    return kill


print("==== 1) ww1_sup_mg_nest idle ====", flush=True)
fn = "ww1_sup_mg_nest_idle_sheet_512.png"
backup(fn)
backup("ww1_sup_mg_nest_idle_grid_preview.png")
im = np.array(Image.open(os.path.join(BK, fn)).convert("RGBA"))
kill = grey_shadow_cut(im, satmax=15, vlo=100, vhi=225, min_area=400, band_lo=0.45)
print("  kill px:", int(kill.sum()), flush=True)
im = feather_zero(im, kill)
Image.fromarray(im).save(os.path.join(OUT, fn))
# 重建 8 格 preview
sheet = Image.open(os.path.join(OUT, fn)).convert("RGBA")
cell = 250
g = Image.new("RGB", (4 * cell, 2 * cell), (40, 44, 52))
for i in range(8):
    fr = sheet.crop((i * 512, 0, (i + 1) * 512, 512)).resize((cell, cell), Image.LANCZOS)
    g.paste(fr, (i % 4 * cell, i // 4 * cell), fr)
g.save(os.path.join(OUT, "ww1_sup_mg_nest_idle_grid_preview.png"))

print("==== 2) ww2_air_bomber R2 ====", flush=True)
fn = "ww2_air_bomber_R2_attack_sheet_832.png"
for suf in ("_attack_sheet_832.png", "_attack_cells_dark.png", "_attack_cells.png",
            "_attack_anim.gif", "_attack_anim_pal8.gif"):
    backup("ww2_air_bomber_R2" + suf)
sheet = np.array(Image.open(os.path.join(BK, fn)).convert("RGBA"))
FS = 832
total = 0
for row in range(2):
    for col in range(3):
        y0, x0 = row * FS, col * FS
        cellimg = sheet[y0:y0 + FS, x0:x0 + FS]
        kill = grey_shadow_cut(cellimg, satmax=14, vlo=100, vhi=205, min_area=2000,
                               aspect_min=1.8, y0_min=FS // 2)
        total += int(kill.sum())
        if kill.sum():
            cellimg = feather_zero(cellimg, kill)
            sheet[y0:y0 + FS, x0:x0 + FS] = cellimg
print("  kill px total:", total, flush=True)
Image.fromarray(sheet).save(os.path.join(OUT, fn))
# 重建派生：cells_dark（3×2, 400px 格）+ 两版 gif
simg = Image.open(os.path.join(OUT, fn)).convert("RGBA")
frames = [simg.crop((c * FS, r * FS, (c + 1) * FS, (r + 1) * FS)) for r in range(2) for c in range(3)]
g = Image.new("RGB", (3 * 400, 2 * 400), (40, 44, 52))
for i, fr in enumerate(frames):
    f2 = fr.resize((400, 400), Image.LANCZOS)
    g.paste(f2, (i % 3 * 400, i // 3 * 400), f2)
g.save(os.path.join(OUT, "ww2_air_bomber_R2_attack_cells_dark.png"))
g.save(os.path.join(OUT, "ww2_air_bomber_R2_attack_cells.png"))
bgc = Image.new("RGBA", (FS, FS), (60, 60, 60, 255))
comp = []
for fr in frames:
    b2 = bgc.copy()
    b2.paste(fr, (0, 0), fr)
    comp.append(b2.convert("RGB"))
comp[0].save(os.path.join(OUT, "ww2_air_bomber_R2_attack_anim.gif"), save_all=True,
             append_images=comp[1:], duration=110, loop=0)
q = [f.convert("P", palette=Image.ADAPTIVE, colors=128) for f in comp]
q[0].save(os.path.join(OUT, "ww2_air_bomber_R2_attack_anim_pal8.gif"), save_all=True,
          append_images=q[1:], duration=110, loop=0)

print("==== 3) ww1_arty_77mm SF 边缘净化 ====", flush=True)
fn = "ww1_arty_77mm_SF_attack_sheet_512.png"
for suf in ("_SF_attack_sheet_512.png", "_SF_attack_cells_dark.png", "_SF_attack_anim.gif"):
    backup("ww1_arty_77mm" + suf)
sheet = np.array(Image.open(os.path.join(BK, fn)).convert("RGBA"))
r, g, b = sheet[:, :, 0].astype(int), sheet[:, :, 1].astype(int), sheet[:, :, 2].astype(int)
a = sheet[:, :, 3]
sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
v = np.maximum(np.maximum(r, g), b)
# 3a) 半透明灰晕：半 alpha 且中性灰
fringe = (a > 0) & (a < 210) & (sat < 16) & (v > 70) & (v < 235)
# 3b) 暗粉边：r-g>18 & b-g>12 & r>105（depink 后残余的暗品红边）
pinkish = (r - g > 18) & (b - g > 12) & (r > 105)
kill = fringe | pinkish
print("  fringe=%d pinkish=%d" % (int(fringe.sum()), int(pinkish.sum())), flush=True)
sheet = feather_zero(sheet, kill)
Image.fromarray(sheet).save(os.path.join(OUT, fn))
# 重建派生
simg = Image.open(os.path.join(OUT, fn)).convert("RGBA")
frames = [simg.crop((i * 512, 0, (i + 1) * 512, 512)) for i in range(6)]
celln = 212
g2 = Image.new("RGB", (3 * celln, 2 * celln), (40, 44, 52))
for i, fr in enumerate(frames):
    f2 = fr.resize((celln, celln), Image.LANCZOS)
    g2.paste(f2, (i % 3 * celln, i // 3 * celln), f2)
g2.save(os.path.join(OUT, "ww1_arty_77mm_SF_attack_cells_dark.png"))
bgc = Image.new("RGBA", (512, 512), (60, 60, 60, 255))
comp = []
for fr in frames:
    b2 = bgc.copy()
    b2.paste(fr, (0, 0), fr)
    comp.append(b2.convert("RGB"))
comp[0].save(os.path.join(OUT, "ww1_arty_77mm_SF_attack_anim.gif"), save_all=True,
             append_images=comp[1:], duration=100, loop=0)
print("阴影手术完成", flush=True)
