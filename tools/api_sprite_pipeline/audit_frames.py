# -*- coding: utf-8 -*-
"""帧序审计: 质心/左右分布/顶部内容 + 高清分半目检条。"""
import os, sys
import numpy as np
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
U = "ww2_arm_garand_para"
OUT = os.path.abspath(os.path.join(OUT, "..", "..", ".godot", "unit_review", "api_" + U))
frames = [Image.open(os.path.join(OUT, "frames", "f%d.png" % i)).convert("RGBA") for i in range(1, 7)]
print("=== 程序化: 质心/分布（画布256, 左=0 右=255）===")
for i, fr in enumerate(frames, 1):
    a = np.asarray(fr)[:, :, 3]
    ys, xs = np.nonzero(a > 40)
    cx, cy = xs.mean(), ys.mean()
    left = int((xs < 128).sum()); right = int((xs >= 128).sum())
    top_xs = xs[ys < ys.min() + 20]
    print("f%d: 质心=(%d,%d) 左半=%d 右半=%d 顶部内容x=%d-%d" % (i, cx, cy, left, right, top_xs.min(), top_xs.max()))
h1 = Image.new("RGBA", (512 * 3, 520), (34, 34, 34, 255))
h2 = Image.new("RGBA", (512 * 3, 520), (34, 34, 34, 255))
for i in range(3):
    h1.alpha_composite(frames[i].resize((512, 512), Image.NEAREST), (i * 512, 4))
    h2.alpha_composite(frames[i + 3].resize((512, 512), Image.NEAREST), (i * 512, 4))
h1.convert("RGB").save(os.path.join(OUT, "audit_f123.png"))
h2.convert("RGB").save(os.path.join(OUT, "audit_f456.png"))
print("audit_f123.png / audit_f456.png saved")
