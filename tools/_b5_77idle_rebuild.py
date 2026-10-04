# -*- coding: utf-8 -*-
"""77mm 待机卷重建（2026-10-04）：用户重抠 anchor_raw（底透化+灰影手删）后，
按 _b5_gen_batch.build_idle 同配方从净版 anchor 重建 8 帧微呼吸 idle——
差异：跳过 detect_bg/chroma_key（已透明，convert("RGB") 会变黑底键黑暗件），
保留 depink（手抠边缘粉晕补刀）+ keep_main_bodies（残影小碎块一并丢弃）。
用法: python tools/_b5_77idle_rebuild.py
"""
import io
import os
import shutil
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_shadow_20261004")
os.makedirs(BK, exist_ok=True)


def load_mod(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load_mod("b5_ag77", os.path.join(ROOT, "tools", "img25_attack_gen.py"))

for fn in ("ww1_arty_77mm_idle_sheet_512.png", "ww1_arty_77mm_idle_grid_preview.png"):
    p = os.path.join(OUT, fn)
    if os.path.exists(p):
        shutil.move(p, os.path.join(BK, fn))

rgba = Image.open(os.path.join(OUT, "ww1_arty_77mm_anchor_raw.png")).convert("RGBA")
print("anchor_raw mode/size:", rgba.mode, rgba.size)
rgba = ag.depink(rgba)
rgba = ag.keep_main_bodies(rgba, 0.35)
box = ag.alpha_bbox(rgba)
if box is None:
    print("键控后空图！")
    sys.exit(1)
body = rgba.crop(box)
FS2 = 512
w, h = body.size
sc = min((FS2 - 40) / w, (FS2 - 40) / h, 1.6)
body = body.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
base = Image.new("RGBA", (FS2, FS2), (0, 0, 0, 0))
base.paste(body, ((FS2 - body.width) // 2, FS2 - 16 - body.height), body)
a0 = np.asarray(base).copy()
up = np.roll(a0, -2, axis=0)
up[-2:, :] = 0
loop = [a0, a0, up, up, a0, a0, a0, a0]
sheet = Image.new("RGBA", (8 * FS2, FS2), (0, 0, 0, 0))
for i, f in enumerate(loop):
    sheet.paste(Image.fromarray(f), (i * FS2, 0))
sheet.save(os.path.join(OUT, "ww1_arty_77mm_idle_sheet_512.png"))
g = Image.new("RGBA", (4 * 256, 2 * 256), (40, 44, 52, 255))
for i, f in enumerate(loop):
    fr = Image.fromarray(f).resize((256, 256), Image.LANCZOS)
    g.paste(fr, (i % 4 * 256, i // 4 * 256), fr)
g.convert("RGB").save(os.path.join(OUT, "ww1_arty_77mm_idle_grid_preview.png"))
print("[idle:ww1_arty_77mm] 重建 OK（净版 anchor，无影）", flush=True)
