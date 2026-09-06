#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""修复星冥动画雪碧条的 AI 背景污染帧(v27.x)。

背景污染根因:generate 管线的去底是"白转透",部分视频帧的 AI 背景是灰/黑/深青
(非白),白转透无效——整块带背景方图(约 224×224 居中)残留高不透明 alpha,
游戏内 ping-pong 播放时闪现深色矩形。

修复算法(逐帧自适应,零新美术):
  1. 背景参考色 ref = 帧内圈环带(16-32px)不透明像素中值色
  2. 全帧 RGB 色距图 dist(px, ref)
  3. scipy.ndimage.label 连通域:凡与环带连通(环带像素做种子)且 dist < T 的
     连通区域判为背景 → alpha=0。主体装甲暗部即使色近,被亮边/发光轮廓包围,
     泛洪进不去(空间条件兜底色度分割的误切)。
  4. 背景区边界 1px 羽化(alpha 线性衰减),防硬边锯齿。

跑法: python tools/fix_xeno_anim_bg_frames.py [--dry]
  --dry 只出前后对比图到 .godot/xeno_audit/ 不写回。
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (单位, 动画, 脏帧号) —— 2026-09-06 alpha 占比检测(>55% 不透明)实测清单
DIRTY = [
    ("vis_xeno_stalker", "idle", [2, 3, 4, 5]),
    ("vis_xeno_tripod", "attack", [1, 2, 3, 4, 5, 6, 7]),
]
FS = 256
T_DIST = 70.0     # 背景色距阈值(RGB 欧氏)
RING_A, RING_B = 16, 32  # 内圈环带(背景参考色采样区)


def fix_frame(fr: np.ndarray) -> np.ndarray:
    """fr: (256,256,4) 单帧。返回修复后的副本。"""
    out = fr.copy()
    a = fr[:, :, 3]
    opaque = a > 0
    # 环带不透明像素 → 背景参考色
    ring_mask = np.zeros((FS, FS), bool)
    ring_mask[RING_A:RING_B, RING_A:FS - RING_A] = True
    ring_mask[FS - RING_B:FS - RING_A, RING_A:FS - RING_A] = True
    ring_mask[:, :RING_A + 8] = False
    ring_mask[:, FS - RING_A - 8:] = False
    ring_px = fr[ring_mask & opaque]
    if len(ring_px) < 50:
        return out  # 环带几乎无内容(非中心块污染帧),跳过
    ref = np.median(ring_px[:, :3].astype(float), axis=0)
    # 色距图(全像素,含半透明)
    diff = fr[:, :, :3].astype(float) - ref[None, None, :]
    dist = np.sqrt((diff ** 2).sum(axis=2))
    near = dist < T_DIST
    # 连通域:种子=环带不透明且 near;扩散条件=near
    seeds = ring_mask & opaque & near
    lbl, n = ndimage.label(near)
    seed_labels = np.unique(lbl[seeds])
    seed_labels = seed_labels[seed_labels > 0]
    if len(seed_labels) == 0:
        return out
    bg = np.isin(lbl, seed_labels) & opaque
    # 羽化:背景边界 1px 渐变(对 bg 做腐蚀差集)
    er = ndimage.binary_erosion(bg, iterations=1)
    edge = bg & ~er
    out[edge, 3] = (out[edge, 3] * 0.45).astype(np.uint8)
    out[er, 3] = 0
    return out


def main():
    dry = "--dry" in sys.argv
    for key, anim, frames in DIRTY:
        sheet_path = os.path.join(ROOT, "assets/effects/unit_anims", key, "sheet_%s.png" % anim)
        sheet = np.array(Image.open(sheet_path).convert("RGBA"))
        before = sheet.copy()
        n_fixed = 0
        for i in frames:
            fr = sheet[:, i * FS:(i + 1) * FS, :]
            fixed = fix_frame(fr)
            # 修复量统计:被清掉的强不透明像素数
            cleared = int(((fr[:, :, 3] > 200) & (fixed[:, :, 3] == 0)).sum())
            sheet[:, i * FS:(i + 1) * FS, :] = fixed
            n_fixed += 1
            print("%s/%s f%d: cleared %d px" % (key, anim, i, cleared))
        # 前后对比图(脏帧并排:修复前 | 修复后)
        rows = []
        for i in frames:
            pair = np.concatenate([before[:, i * FS:(i + 1) * FS, :], sheet[:, i * FS:(i + 1) * FS, :]], axis=1)
            rows.append(pair)
        comp = np.concatenate(rows, axis=0)
        bg = Image.new("RGBA", (FS * 2, FS * len(rows)), (200, 180, 150, 255))
        bg.alpha_composite(Image.fromarray(comp))
        out_png = os.path.join(ROOT, ".godot/xeno_audit/fix_%s_%s.png" % (key, anim))
        bg.convert("RGB").save(out_png)
        print("  compare -> %s" % out_png)
        if not dry:
            Image.fromarray(sheet).save(sheet_path)
            print("  saved %s" % sheet_path)


if __name__ == "__main__":
    main()
