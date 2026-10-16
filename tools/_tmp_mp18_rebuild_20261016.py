# -*- coding: utf-8 -*-
"""mp18_x 重拼 6 帧 sheet(2026-10-16,交接文档 §四.075):
1. 底=.godot/unit_review/api_ww1_inf_mp18_x/sheet_attack_api.png(1536×256 格池法 6 帧)
2. f5 替换为 raw 原图内容(cut 075 512² 透明底)——用户拍板「最后一帧换原图」
   对齐:主体缩放至 f4 主体高,底缘对齐 f4(y244),水平中心对齐 f4(x140)
3. 存 assets/effects/unit_anims/ww1_inf_mp18_x/sheet_attack.png
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = os.path.join(ROOT, ".godot", "unit_review", "api_ww1_inf_mp18_x", "sheet_attack_api.png")
CUT = os.path.join(ROOT, "docs", "卡图API重生成_20261014", "cut", "075·MP18 突击队.png")
DST = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww1_inf_mp18_x", "sheet_attack.png")

sh = np.asarray(Image.open(API).convert("RGBA")).copy()

# f4 度量(对齐基准)
f4a = sh[:, 4 * 256:5 * 256, 3]
ys, xs = np.where(f4a > 60)
f4_h = int(ys.max() - ys.min() + 1)
f4_cx = float(xs.min() + xs.max()) / 2.0
f4_by = int(ys.max())

# cut 主体
cut = np.asarray(Image.open(CUT).convert("RGBA"))
ca = cut[:, :, 3]
cys, cxs = np.where(ca > 60)
c_h = int(cys.max() - cys.min() + 1)
c_cx = float(cxs.min() + cxs.max()) / 2.0
c_by = int(cys.max())

scale = f4_h / float(c_h)
new_sz = max(1, int(round(cut.shape[0] * scale)))
cut_im = Image.fromarray(cut).resize((new_sz, new_sz), Image.LANCZOS)
cn = np.asarray(cut_im).copy()

# 缩后主体位置
c_by2 = c_by * scale
c_cx2 = c_cx * scale
dy = int(round(f4_by - c_by2))   # 底缘对齐
dx = int(round(f4_cx - c_cx2))   # 中心对齐

# f5 清空后贴入(边界裁剪)
f5 = sh[:, 5 * 256:6 * 256, :]
f5[:, :, :] = 0
h, w = cn.shape[:2]
sy0, sx0 = max(0, -dy), max(0, -dx)
ty0, tx0 = max(0, dy), max(0, dx)
hh = min(h - sy0, 256 - ty0)
ww = min(w - sx0, 256 - tx0)
f5[ty0:ty0 + hh, tx0:tx0 + ww] = cn[sy0:sy0 + hh, sx0:sx0 + ww]

Image.fromarray(sh).save(DST)
print("f5 替换: scale=%.3f dx=%d dy=%d -> %s" % (scale, dx, dy, DST))

# 复验
chk = np.asarray(Image.open(DST))
for i in range(6):
    fa = chk[:, i * 256:(i + 1) * 256, 3]
    yy, xx = np.where(fa > 60)
    print("  f%d bbox x%d-%d y%d-%d" % (i, xx.min(), xx.max(), yy.min(), yy.max()))
