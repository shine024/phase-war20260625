# -*- coding: utf-8 -*-
"""B5 品红残底洗涤（2026-10-04）：WaveB 十三键 idle 512 表 + 攻击 832 表。
锚定帧 raw 本身就是品红底，绝不碰。暗品红阴影（chroma tol=85 吃不掉的）按色域摘除：
r>90 且 b>90 且 g < 0.62*min(r,b)，再 1px 膨胀吃掉过渡边。
洗完重建 idle 网格预览，并给每个攻击掷补一张深底 3x2 cells 网格。
用法: python tools/_b5_scrub_pink.py
"""
import glob
import io
import os
import sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
PROBE = os.path.join(ROOT, ".godot", "unit_review", "b5_probe")

B5_KEYS = [
    "cold_inf_m60", "fut_arm_mech_e", "ww1_sup_mg_nest", "ww2_sup_mg42",
    "ww2_boss_kingtiger", "ww2_air_bomber", "ww1_arty_mortar", "ww1_a7v",
    "ww1_lanchest", "ww1_mark4", "mod_arm_m1a2sep", "mod_air_technical_e",
    "ww1_arty_77mm",
]


def mag_mask(a):
    r, g, b, al = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int), a[..., 3]
    # 亮品红（r,b 双高 g 低）+ 暗品红/深红系（比例制无亮度下限：96,32,64 一类地面残线）
    # 木色(160,128,96)/鞣革(80,50,35)/真红(150,40,50) 均不满足 r>g*1.9 且 b>g*1.4
    m = ((r > 90) & (b > 90) & (g < 0.62 * np.minimum(r, b))) | \
        ((r > 40) & (r > g * 1.9) & (b > g * 1.4) & (g < 70))
    m &= al > 0
    if not m.any():
        return m
    grow = m.copy()
    grow[:, :-1] |= m[:, 1:]
    grow[:, 1:] |= m[:, :-1]
    grow[:-1, :] |= m[1:, :]
    grow[1:, :] |= m[:-1, :]
    return grow


def scrub(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    m = mag_mask(a)
    n = int(m.sum())
    if n:
        a[m] = (0, 0, 0, 0)
        Image.fromarray(a).save(path)
    return n


def idle_grid(path):
    im = Image.open(path).convert("RGBA")
    fs = im.height
    n = im.width // fs
    g = Image.new("RGB", (4 * 256, 2 * 256), (40, 44, 52))
    for i in range(n):
        fr = im.crop((i * fs, 0, (i + 1) * fs, fs)).resize((256, 256), Image.LANCZOS)
        g.paste(fr, (i % 4 * 256, i // 4 * 256), fr)
    key = os.path.basename(path).replace("_idle_sheet_512.png", "")
    g.save(os.path.join(OUT, "%s_idle_grid_preview.png" % key))


def att_grid(path):
    im = Image.open(path).convert("RGBA")
    cw, ch = 832, 832
    g = Image.new("RGB", (3 * 400, 2 * 400), (40, 44, 52))
    for i in range(6):
        fr = im.crop((i % 3 * cw, i // 3 * ch, (i % 3 + 1) * cw, (i // 3 + 1) * ch))
        fr = fr.resize((400, 400), Image.LANCZOS)
        g.paste(fr, (i % 3 * 400, i // 3 * 400), fr)
    base = os.path.basename(path).replace("_attack_sheet_832.png", "")
    g.save(os.path.join(OUT, "%s_attack_cells_dark.png" % base))


def main():
    total_files, total_px = 0, 0
    for key in B5_KEYS:
        files = [os.path.join(OUT, "%s_idle_sheet_512.png" % key)]
        files += sorted(glob.glob(os.path.join(OUT, "%s_R*_attack_sheet_832.png" % key)))
        files.append(os.path.join(OUT, "%s_attack_sheet_832.png" % key))
        for f in files:
            if not os.path.isfile(f):
                continue
            n = scrub(f)
            total_files += 1
            total_px += n
            tag = "洗%dpx" % n if n else "净"
            print("%-46s %s" % (os.path.basename(f), tag), flush=True)
        idle = os.path.join(OUT, "%s_idle_sheet_512.png" % key)
        if os.path.isfile(idle):
            idle_grid(idle)
        for f in sorted(glob.glob(os.path.join(OUT, "%s_R*_attack_sheet_832.png" % key))):
            att_grid(f)
    # 复扫确认（同一谓词）
    left = 0
    for key in B5_KEYS:
        for f in glob.glob(os.path.join(OUT, "%s_*sheet*.png" % key)):
            a = np.asarray(Image.open(f).convert("RGBA"))
            left += int(mag_mask(a).sum())
    print("共 %d 文件洗 %d px，复扫残留 %d px" % (total_files, total_px, left))


if __name__ == "__main__":
    main()
