# -*- coding: utf-8 -*-
"""单帧修补: 用体高(行密度法)归一一张单掷 i2i 原图并替换指定帧。
用法: python splice_frame.py <frame_tag> <raw_png> [target_body_h]
"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
UNIT = sys.argv[1] if len(sys.argv) > 4 else None
# argv: <unit> <tag> <raw_png> [target_body_h]
UNIT, TAG, RAW_PNG = sys.argv[1], sys.argv[2], sys.argv[3]
TARGET = float(sys.argv[4]) if len(sys.argv) > 4 else 227.0
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
sys.path.insert(0, HERE)
from generate_attack_api import key_magenta, label_components, FS, FOOT_FRAC

im = Image.open(RAW_PNG).convert("RGB")
a = key_magenta(np.asarray(im))
alpha = a[:, :, 3]
comps, labels = label_components(alpha, want_labels=True)
comps = [c for c in comps if c[0] > 3000]
print("comps:", [(c[0], c[1]) for c in comps])
assert len(comps) == 1, "期望单一主体"
npx, bbox, cid = comps[0]
x0, y0, x1, y1 = bbox
mask = labels[y0:y1 + 1, x0:x1 + 1] == cid
rgba = np.dstack([np.asarray(im)[y0:y1 + 1, x0:x1 + 1],
                  np.where(mask, alpha[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)])

# 体高估计: 行密度 > 25% 峰值的最上行 = 头盔顶（竖枪细条/枪口焰低密度被排除）
row_density = (rgba[:, :, 3] > 20).sum(axis=1)
peak = row_density.max()
body_rows = np.where(row_density > 0.25 * peak)[0]
body_h = int(body_rows[-1] - body_rows[0] + 1)
print("bbox h:", rgba.shape[0], "body h:", body_h, "→ scale", TARGET / body_h)
scale = TARGET / body_h
cw, ch = int(round(rgba.shape[1] * scale)), int(round(rgba.shape[0] * scale))
crop = Image.fromarray(rgba).resize((cw, ch), Image.LANCZOS)
canvas = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
canvas.paste(crop, ((FS - cw) // 2, FS - ch - int(round(FOOT_FRAC * FS))), crop)
fp = os.path.join(OUT, "frames", "%s.png" % TAG)
canvas.save(fp)
b = canvas.getchannel("A").getbbox()
print("saved %s: w=%d h=%d 底=%d" % (fp, b[2] - b[0], b[3] - b[1], b[3]))

# 重建 sheet + strip + gif
frames = [Image.open(os.path.join(OUT, "frames", "f%d.png" % i)).convert("RGBA") for i in range(1, 7)]
sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
for i, fr in enumerate(frames):
    sheet.paste(fr, (i * FS, 0))
sheet.save(os.path.join(OUT, "sheet_attack_api.png"))
strip = Image.new("RGBA", (512 * 6, 520), (34, 34, 34, 255))
for i in range(6):
    strip.alpha_composite(frames[i].resize((512, 512), Image.NEAREST), (i * 512, 4))
strip.convert("RGB").resize((1536, 260), Image.LANCZOS).save(os.path.join(OUT, "strip_new_small.png"))
gf = []
for fr in frames:
    fr2 = fr.resize((512, 512), Image.NEAREST)
    bg = Image.new("RGBA", fr2.size, (34, 34, 34, 255)); bg.alpha_composite(fr2)
    gf.append(bg.convert("RGB").convert("P", palette=Image.ADAPTIVE))
gf[0].save(os.path.join(OUT, "preview_api.gif"), save_all=True, append_images=gf[1:],
           duration=125, loop=0, disposal=2)
print("rebuilt sheet/strip/gif")
