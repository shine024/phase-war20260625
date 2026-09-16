# -*- coding: utf-8 -*-
"""审计第2步：帧距检测 + 目视拼图生成（可删探针）"""
import json, os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
ICONS = os.path.join(ROOT, "assets", "card_icons")
SHEETS = os.path.join(ROOT, ".godot", "audit_sheets")
os.makedirs(SHEETS, exist_ok=True)
CELL, COLS = 200, 6

def col_gaps(a_mask, min_gap=6):
    """内容列占用里的空隙段 -> (段列表, 内容簇数)"""
    occ = a_mask.any(axis=0)
    runs, s = [], None
    for x, v in enumerate(occ):
        if not v and s is None: s = x
        if v and s is not None:
            runs.append((s, x - s)); s = None
    if s is not None: runs.append((s, len(occ) - s))
    big = [r for r in runs if r[1] >= min_gap]
    # 内容簇 = big 空隙数 + 1（若首尾有隙则不+）——简化：big 内部隙才算分割
    inner = [r for r in big if r[0] > 0 and r[0] + r[1] < len(occ)]
    return inner, len(inner) + 1

def frame_pitch(path, fs_decl):
    """检测雪碧图实际帧距：返回 (declared 切格下每格内容簇数, 实际帧距 or 0)"""
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    a = np.asarray(im.getchannel("A")) > 40
    inner, _ = col_gaps(a, min_gap=H // 40)
    n_decl = max(1, W // fs_decl)
    per_cell = []
    for i in range(min(n_decl, 3)):  # 抽前3格
        sub = a[:, i*fs_decl:(i+1)*fs_decl]
        _, cl = col_gaps(sub, min_gap=H // 40)
        per_cell.append(cl)
    return im.size, per_cell, inner

def fit(im, cell):
    im = im.convert("RGBA")
    im.thumbnail((cell - 4, cell - 4))
    bg = Image.new("RGBA", (cell, cell), (60, 62, 68, 255))
    bg.paste(im, ((cell - im.width)//2, (cell - im.height)//2), im)
    return bg.convert("RGB")

def make_sheet(items, out_prefix):
    """items: [(img_or_path, label, flag_str)]"""
    per = COLS * 5
    made = []
    for s in range(0, len(items), per):
        chunk = items[s:s+per]
        H = 5 * (CELL + 22)
        cv = Image.new("RGB", (COLS * CELL, H), (24, 26, 30))
        dr = ImageDraw.Draw(cv)
        for i, (im, lb, fl) in enumerate(chunk):
            cx, cy = (i % COLS) * CELL, (i // COLS) * (CELL + 22)
            try:
                cv.paste(fit(im, CELL) if isinstance(im, Image.Image) else fit(Image.open(im), CELL), (cx, cy))
            except Exception as e:
                dr.text((cx+4, cy+CELL//2), f"ERR {e}", fill=(255,80,80))
            dr.text((cx+4, cy+CELL+4), f"{lb} {fl}".strip()[:44], fill=(255,210,80) if fl else (200,200,200))
        op = os.path.join(SHEETS, f"{out_prefix}_{s//(per)+1:02d}.png")
        cv.save(op); made.append(op)
    print("made", op, f"({len(made)} sheets)")
    return made

suspects = {}

# ── 1. 全部雪碧图逐帧分析（按实际可切帧数）──
anim_items = []      # 拼图项
anim_flags = {}
for d in sorted(os.listdir(ANIM)):
    p = os.path.join(ANIM, d)
    if not os.path.isdir(p): continue
    loose = sorted([f for f in os.listdir(p) if f.startswith("idle_f") and f.endswith(".png")])
    jp = os.path.join(p, "anim.json")
    meta = json.load(open(jp, encoding="utf-8")) if os.path.isfile(jp) else {}
    fs = int(meta.get("frame_size", 256))
    if loose:  # boss 散帧
        flags = []
        if len(loose) < 4: flags.append("FEW")
        ip = os.path.join(p, loose[len(loose)//2])
        anim_items.append((ip, d, " ".join(flags)))
        anim_flags[d] = flags
        continue
    sp = os.path.join(p, "sheet_idle.png")
    if not os.path.isfile(sp): 
        anim_items.append((None, d, "NOSHEET")); anim_flags[d] = ["NOSHEET"]
        continue
    (W, H), per_cell, inner = frame_pitch(sp, fs)
    n_real = W // fs
    declared = int(meta.get("counts", {}).get("idle", 0))
    flags = []
    if H != fs: flags.append(f"H{H}")
    if W != fs * declared:
        if W == (fs//2) * declared and fs % 2 == 0:
            flags.append(f"FS!{fs//2}")   # 帧距减半 → 双主体
        else:
            flags.append(f"W{W}/{fs*declared}")
    if any(c >= 2 for c in per_cell): flags.append(f"MULTI{max(per_cell)}")
    anim_flags[d] = flags
    mid = Image.open(sp).crop((0, 0, fs, H)) if "FS!" in " ".join(flags) else \
          Image.open(sp).crop(((min(declared, n_real)//2) * fs, 0, (min(declared, n_real)//2 + 1) * fs, H))
    anim_items.append((mid, d, " ".join(flags)))

make_sheet(anim_items, "anim_rep")

# ── 2. 卡图嫌疑检测（列隙分割，512px 原图）──
icon_items, icon_flags = [], {}
for side in ("enemy", "player"):
    sd = os.path.join(ICONS, side)
    for fn in sorted(os.listdir(sd)):
        if not fn.endswith(".png"): continue
        ip = os.path.join(sd, fn)
        im = Image.open(ip).convert("RGBA")
        a = np.asarray(im.getchannel("A")) > 40
        if not a.any():
            icon_flags[f"{side}/{fn[:-4]}"] = ["EMPTY"]
            icon_items.append((im, f"{side}/{fn[:-4]}", "EMPTY")); continue
        inner, clusters = col_gaps(a, min_gap=8)
        fl = ""
        if clusters >= 3: fl = f"CL{clusters}"
        icon_flags[f"{side}/{fn[:-4]}"] = ([fl] if fl else [])
        icon_items.append((im, f"{side}/{fn[:-4]}", fl))

make_sheet(icon_items, "icons")

json.dump({"anim": anim_flags, "icons": icon_flags},
          open(os.path.join(ROOT, ".godot", "sheet_flags.json"), "w", encoding="utf-8"),
          ensure_ascii=False)
print("flags -> .godot/sheet_flags.json")
