# -*- coding: utf-8 -*-
"""转换目验缺陷修图批(2026-10-16,用户拍板:078/缺拍重来,其余表中修复)。

拍层(改 poses 源拍,修完重转换):
- 012 四拍品红烟 → 灰白化(掩膜 r>g+22&b>g+8&r>120,luma 混合)
- 113 TR 地面红晕泄漏 → 品红族掩膜填四角背景色(转换时键掉)

sheet 层(直接改 .godot/unit_review/attk4):
- 011/068/149 BR 整帧噪点 → 该帧 α<200 全清(主体实心 255 保留,半透明噪粒灭)
- 019 TR 爆闪过大 → 焰核掩膜(r>210&g<210&b<130)杀透明

用法:python -I -u -X utf8 tools/_tmp_frame_fix_20261016.py
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "raw")
ATT = os.path.join(ROOT, ".godot", "unit_review", "attk4")


def corners_bg(img):
    c = np.concatenate([img[:12, :12].reshape(-1, 3), img[:12, -12:].reshape(-1, 3),
                        img[-12:, :12].reshape(-1, 3), img[-12:, -12:].reshape(-1, 3)])
    return c.mean(axis=0)


def dil(mask, n):
    m = mask.copy()
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m


# ── 拍层:012 四拍品红烟灰白化 ──
for p in sorted(glob.glob(os.path.join(RAW, "poses", "012*_*.png"))):
    img = np.asarray(Image.open(p).convert("RGB")).astype(float)
    r, g, b = img[:, :, 0], img[:, :, 1], img[:, :, 2]
    m = dil((r > g + 22) & (b > g + 8) & (r > 120), 2)
    luma = (r + g + b) / 3
    new = np.clip(luma * 0.35 + 178 * 0.65, 0, 255)
    out = img.copy()
    for ch in range(3):
        out[:, :, ch] = np.where(m, new, img[:, :, ch])
    Image.fromarray(out.astype(np.uint8)).save(p)
    print("012 烟灰白化", os.path.basename(p), int(m.sum()), flush=True)

# ── 拍层:113 TR 红晕填背景 ──
p = os.path.join(RAW, "poses", "113·防空炮_TR.png")
hits = glob.glob(os.path.join(RAW, "poses", "113*_TR.png"))
if hits:
    img = np.asarray(Image.open(hits[0]).convert("RGB")).astype(float)
    r, g, b = img[:, :, 0], img[:, :, 1], img[:, :, 2]
    m = dil((r > g + 40) & (b > g + 15) & (r > 55) & (b > 35), 3)
    bg = corners_bg(img)
    out = img.copy()
    for ch in range(3):
        out[:, :, ch] = np.where(m, bg[ch], img[:, :, ch])
    Image.fromarray(out.astype(np.uint8)).save(hits[0])
    print("113 TR 红晕填背景", int(m.sum()), flush=True)

# ── sheet 层:011/068/149 BR 噪点清 ──
for uid in ("ww2_arty_m81", "fut_inf_spectre_e", "ww2_mg42"):
    p = os.path.join(ATT, uid, "sheet_attack.png")
    a = np.asarray(Image.open(p).convert("RGBA")).copy()
    br = a[:, 768:1024, 3]
    n = int(((br > 0) & (br < 200)).sum())
    br[(br > 0) & (br < 200)] = 0
    Image.fromarray(a, "RGBA").save(p)
    print("BR 噪点清", uid, n, flush=True)

# ── sheet 层:019 TR 焰核杀 ──
p = os.path.join(ATT, "mod_arm_m1a1", "sheet_attack.png")
a = np.asarray(Image.open(p).convert("RGBA")).copy()
tr = a[:, 256:512]
r, g, b = tr[:, :, 0].astype(int), tr[:, :, 1].astype(int), tr[:, :, 2].astype(int)
m = dil((r > 210) & (g < 210) & (b < 130) & (tr[:, :, 3] > 60), 2)
n = int(m.sum())
for ch in range(4):
    tr[:, :, ch][m] = 0
Image.fromarray(a, "RGBA").save(p)
print("019 TR 焰核杀", n, flush=True)
