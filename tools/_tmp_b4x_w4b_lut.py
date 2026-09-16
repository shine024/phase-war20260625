#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W4 步骤 2b 背景 B 档轻压冷 LUT（2026-09-14，用户批准"先小样再放量"）。

配方：r>b 像素 (r-b)×0.40 单轮（场景域轻压冷；cards/dream 用 0.62，场景叙事
光源需保留故减半）。样张模式输出到 .godot/agent_tools/w4b_lut_sample/（三组
before/after 并排 + 指标）；--apply 模式才回写 assets（放量需另行确认）。
样本：bg_level_02（era1 暖霞）/ 48（era3 夕阳暖金）/ 82（era5 暖霞+紫）。
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG_DIR = os.path.join(ROOT, "assets", "backgrounds")
SAMPLE_DIR = os.path.join(ROOT, ".godot", "agent_tools", "w4b_lut_sample")
RATIO = 0.40
BACKUP = r"F:\godot fair duet\_art_backup"

SAMPLES = ["bg_level_02", "bg_level_48", "bg_level_82"]


def cool_lut(img: Image.Image, ratio: float) -> Image.Image:
    """v2 场景域压冷：r 向 b 压 + g 同步下压（k_g=0.78），并保 r'≥g' 暖序防绿。
    v1 只压 r 会把橙霞穿成病绿（小样实测），此为修正。"""
    arr = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    m = r > b
    r2 = np.where(m, b + (r - b) * ratio, r)
    g2 = np.where(m & (g > b), np.minimum(b + (g - b) * 0.78, r2 - 2), g)
    arr[..., 0] = r2
    arr[..., 1] = g2
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def warm_ratio(arr):
    r, b = arr[..., 0].astype(np.int16), arr[..., 2].astype(np.int16)
    return float(((r > b + 30) & (r > 90)).mean())


def side_by_side(before, after, name):
    w, h = before.size
    canvas = Image.new("RGB", (w // 2 * 2, h // 2), (20, 20, 24))
    canvas.paste(before.resize((w // 2, h // 2)), (0, 0))
    canvas.paste(after.resize((w // 2, h // 2)), (w // 2, 0))
    return canvas


def main() -> int:
    os.makedirs(SAMPLE_DIR, exist_ok=True)
    apply_mode = "--apply" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("-")] or SAMPLES
    for name in names:
        src = os.path.join(BG_DIR, name + ".png")
        before = Image.open(src).convert("RGB")
        after = cool_lut(before, RATIO)
        ba = np.asarray(before).reshape(-1, 3).astype(np.int16)
        aa = np.asarray(after).reshape(-1, 3).astype(np.int16)
        wb, wa = warm_ratio(ba), warm_ratio(aa)
        print("%s 暖区 %.1f%% -> %.1f%% (相对降幅 %.0f%%)  RGB %s -> %s"
              % (name, wb * 100, wa * 100, (1 - wa / wb) * 100,
                 ba.mean(0).round(0).tolist(), aa.mean(0).round(0).tolist()))
        out = os.path.join(SAMPLE_DIR, name + "_after.png")
        after.save(out)
        side_by_side(before, after, name).save(
            os.path.join(SAMPLE_DIR, name + "_cmp.png"))
        if apply_mode:
            dst_bak = os.path.join(BACKUP, name + "-preW4B-2026-09-14.png")
            if not os.path.exists(dst_bak):
                before.save(dst_bak)
            after.save(src)
            print("  已回写 assets（原份备份 %s）" % os.path.basename(dst_bak))
    return 0


if __name__ == "__main__":
    sys.exit(main())
