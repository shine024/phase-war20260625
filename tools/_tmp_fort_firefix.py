# -*- coding: utf-8 -*-
"""WW1 双堡开火帧火光切边修补（staging 迭代版）。
切边=火光超出源生成画布被裁出的硬直切线（x=8 处垂直切）。
修法=对切线侧做 smoothstep alpha 羽化：
  - 区A [x_cut, x_base]：基线帧内容左缘之前=纯火光悬浮区，全像素羽化；
  - 区B [x_base, x_base+EXT]：与建筑/枪管/士兵可能重叠，仅对"火焰色"像素
    (HSV: 橙黄高饱和高亮) 羽化，其余像素位级保留。
产出 → .godot/fort_firefix_staging/（不动源帧），before/after 拼图供目视迭代。
"""
import os
import numpy as np
import cv2
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, '资料', '单位分帧动画')
STAGE = os.path.join(ROOT, '.godot', 'fort_firefix_staging')
SHEET = os.path.join(ROOT, '.godot', 'audit_sheets')
os.makedirs(STAGE, exist_ok=True)

X_CUT = 8          # 两家切线同在此处（生成画布贴入偏移）
ZERO_MARGIN = 12   # 真零区宽：alpha 必须在切线前归零并留白 > 描边烘焙 4px@256（=8px@512）
FEATHER_A = 46     # 区A 宽：纯火区羽化长度（含真零区）
FEATHER_B = 72     # 区B 宽：重叠区火焰色羽化长度

# HSV 火焰色判定：橙黄/亮黄白（OpenCV H∈[0,180]）
H_LO, H_HI = 2, 48
S_MIN = 110        # 0-255
V_MIN = 120

JOBS = [
    # (目录, 帧号, x_base=该单位无火基线内容左缘)
    ('073_ww1_fort_artillery_要塞炮台', [2], 40),
    ('072_ww1_fort_pillbox_混凝土机枪碉堡', [2, 3, 4, 5, 6], 54),
]


def flame_mask(hsv):
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    return (h >= H_LO) & (h <= H_HI) & (s >= S_MIN) & (v >= V_MIN)


def repair_frame(im, x_base):
    """对单帧做切边羽化，返回新 Image。"""
    arr = np.asarray(im).copy()
    hsv = cv2.cvtColor(arr[..., :3], cv2.COLOR_RGB2HSV)
    fm = flame_mask(hsv)
    a = arr[..., 3].astype(np.float32)
    xs = np.arange(arr.shape[1], dtype=np.float32)[None, :].repeat(arr.shape[0], axis=0)
    # 区A：真零区 + smoothstep（0 在 X_CUT+ZERO_MARGIN，1 在 X_CUT+FEATHER_A）
    t_a = np.clip((xs - (X_CUT + ZERO_MARGIN)) / (FEATHER_A - ZERO_MARGIN), 0, 1)
    ramp_a = t_a * t_a * (3 - 2 * t_a)
    ramp_a = np.where(xs <= X_CUT + ZERO_MARGIN, 0.0, ramp_a)
    # 区B：延伸段，仅火焰色像素（从 x_base 到 x_base+FEATHER_B 收到满 alpha）
    t_b = np.clip((xs - x_base) / FEATHER_B, 0, 1)
    ramp_b = t_b * t_b * (3 - 2 * t_b)
    zone_b = (xs >= x_base) & (xs < x_base + FEATHER_B)
    ramp = np.where(xs < x_base, ramp_a, np.where(zone_b, np.maximum(ramp_a, ramp_b), 1.0))
    mult = np.where(fm & (xs < x_base + FEATHER_B) & (xs >= X_CUT), ramp, 1.0)
    # 区A 内非火焰色像素（理论上没有）也按 ramp 收，保证切线必消
    mult = np.where((xs >= X_CUT) & (xs < x_base), ramp, mult)
    arr[..., 3] = np.clip(a * mult, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


before_after = []
for d, frames, x_base in JOBS:
    dp = os.path.join(SRC, d)
    outd = os.path.join(STAGE, d, 'attack')
    os.makedirs(outd, exist_ok=True)
    for i in frames:
        p = os.path.join(dp, 'attack', 'f%02d.png' % i)
        im = Image.open(p).convert('RGBA')
        fixed = repair_frame(im, x_base)
        fixed.save(os.path.join(outd, 'f%02d.png' % i))
        before_after.append((d.split('_')[1], i, im, fixed))
        # 修后左缘验证
        a = np.asarray(fixed)[:, :, 3] > 40
        ys, xxs = np.where(a)
        print(d.split('_')[1], 'f%02d' % i, 'new x0=', xxs.min(), '(was 8)')

# before/after 拼图（左缘 240px 条带）
rowh = 240
cv = Image.new('RGB', (4 * 500 + 20, rowh * len(before_after) + 10), (24, 26, 30))
dr = ImageDraw.Draw(cv)
for r, (name, i, b, f) in enumerate(before_after):
    y = r * rowh + 5
    for c, (tag, img) in enumerate([('BEFORE', b), ('AFTER', f)]):
        strip = img.crop((0, 60, 480, 512)).resize((480, rowh - 28))
        bg = Image.new('RGBA', strip.size, (60, 62, 68, 255)); bg.paste(strip, (0, 0), strip)
        cv.paste(bg.convert('RGB'), (10 + c * 490, y + 18))
        dr.text((10 + c * 490, y + 2), f'{name} f{i:02d} {tag}', fill=(255,210,80) if tag == 'AFTER' else (160,160,160))
op = os.path.join(SHEET, 'fort_firefix_preview.png')
cv.save(op)
print('made', op)
