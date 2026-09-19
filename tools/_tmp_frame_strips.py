# -*- coding: utf-8 -*-
"""v6.17 全量目视条带：每套动画一行（idle 全帧 + attack f0 + 散帧/attack_f0 目录），
8 套一张拼图 -> .godot/audit_sheets/strip_XX.png。目视抓"相连双主体/贴边裁切/白底残留"
等机审漏网项。可删探针。"""
import json, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
SHEETS = os.path.join(ROOT, ".godot", "audit_sheets")
os.makedirs(SHEETS, exist_ok=True)

CELL_H = 110     # 条带帧高
ROWS = 8         # 每张拼图行数
MAX_FRAMES = 9   # 每行最多帧数（idle 8 + attack f0 超出截断）


def fit_h(im, h):
    w = int(im.width * h / im.height)
    return im.convert("RGBA").resize((w, h))


rows = []  # (label, [PIL.Image], flag)
for d in sorted(os.listdir(ANIM)):
    p = os.path.join(ANIM, d)
    if not os.path.isdir(p):
        continue
    jp = os.path.join(p, "anim.json")
    meta = json.load(open(jp, encoding="utf-8")) if os.path.isfile(jp) else {}
    fs = int(meta.get("frame_size", 256))
    imgs, fl = [], []
    # 散帧 boss
    loose = sorted(f for f in os.listdir(p) if f.startswith("idle_f") and f.endswith(".png"))
    # 纯 attack_f0 目录（AttackPoseAnim 合法资产，单帧）
    attack_only = sorted(f for f in os.listdir(p) if f.startswith("attack_f") and f.endswith(".png"))
    if loose and not os.path.isfile(os.path.join(p, "sheet_idle.png")):
        for fn in loose[:MAX_FRAMES]:
            imgs.append(fit_h(Image.open(os.path.join(p, fn)), CELL_H))
        rows.append((d + f" [loose{len(loose)}]", imgs, fl))
        continue
    if not loose and not os.path.isfile(os.path.join(p, "sheet_idle.png")) \
            and attack_only and not os.path.isfile(jp):
        for fn in attack_only[:MAX_FRAMES]:
            imgs.append(fit_h(Image.open(os.path.join(p, fn)), CELL_H))
        rows.append((d + f" [pose{len(attack_only)}]", imgs, fl))
        continue
    sp = os.path.join(p, "sheet_idle.png")
    if os.path.isfile(sp):
        im = Image.open(sp).convert("RGBA")
        n = min(im.width // fs if im.height == fs else 0, MAX_FRAMES - 1)
        if n == 0:
            fl.append(f"H{im.height}!")
        for i in range(n):
            imgs.append(fit_h(im.crop((i * fs, 0, (i + 1) * fs, fs)), CELL_H))
    ap = os.path.join(p, "sheet_attack.png")
    if os.path.isfile(ap):
        aim = Image.open(ap).convert("RGBA")
        if aim.height == fs and aim.width >= fs:
            imgs.append(fit_h(aim.crop((0, 0, fs, fs)), CELL_H))
    rows.append((d, imgs, fl))

made = []
for s in range(0, len(rows), ROWS):
    chunk = rows[s:s + ROWS]
    max_cols = max(len(c[1]) for c in chunk) or 1
    W = 150 + max_cols * (CELL_H + 2)
    H = len(chunk) * (CELL_H + 18) + 10
    cv = Image.new("RGB", (W, H), (24, 26, 30))
    dr = ImageDraw.Draw(cv)
    for r, (label, imgs, fl) in enumerate(chunk):
        y = 5 + r * (CELL_H + 18)
        dr.text((6, y + CELL_H // 2 - 6), label[:20], fill=(120, 220, 255),
                font=None) if False else dr.text((6, y + 40), label[:19], fill=(120, 220, 255))
        x = 150
        for im in imgs:
            if im.width > CELL_H * 2 + 60:  # 超宽帧（比例失真）也贴，拼图允许横向压缩
                pass
            cv.paste(im, (x, y), im)
            x += im.width + 2
        if fl:
            dr.text((6, y + CELL_H + 2), " ".join(fl)[:24], fill=(255, 120, 80))
    op = os.path.join(SHEETS, f"strip_{s // ROWS + 1:02d}.png")
    cv.save(op)
    made.append(op)
print(f"rows={len(rows)} sheets={len(made)}")
for m in made:
    print(m)
