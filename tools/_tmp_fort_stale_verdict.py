# -*- coding: utf-8 -*-
"""判决实验：用当前源帧按 deploy 管线原样重建 sheet，与已发布 sheet 逐帧 XOR。
一致=发布没过期（切边另有原因）；不一致=发布过期（需重新部署）。"""
import glob, json, os, re, sys
import numpy as np
import cv2
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, '资料', '单位分帧动画')
DST = os.path.join(ROOT, 'assets', 'effects', 'unit_anims')
FRAME = 256
OUTLINE_WIDTH_PX = 4
OUTLINE_COLOR = (13, 18, 28, 217)
OUTLINE_FEATHER = 0.6


def bake_outline_on_sheet(sheet, frame=FRAME, w_px=OUTLINE_WIDTH_PX,
                          color=OUTLINE_COLOR, feather=OUTLINE_FEATHER):
    arr = np.asarray(sheet).copy()
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * w_px + 1, 2 * w_px + 1))
    for i in range(arr.shape[1] // frame):
        x0, x1 = i * frame, (i + 1) * frame
        cell = arr[:, x0:x1]
        a = cell[..., 3]
        dil = cv2.dilate(a, k)
        zone = (dil > 0) & (a < 16)
        if not zone.any():
            continue
        layer = np.zeros_like(cell)
        layer[..., 0], layer[..., 1], layer[..., 2] = color[0], color[1], color[2]
        layer[..., 3] = np.where(zone, color[3], 0)
        layer[..., 3] = cv2.GaussianBlur(layer[..., 3], (0, 0), feather)
        lf = layer.astype(np.float32)
        cf = cell.astype(np.float32)
        la = lf[..., 3:4] / 255.0
        ca = cf[..., 3:4] / 255.0
        t = np.clip((ca - 0.02) / (0.38 - 0.02), 0.0, 1.0)
        la = la * (1.0 - t * t * (3.0 - 2.0 * t))
        oa = la + ca * (1.0 - la)
        mixed = np.where(oa > 0, (lf * la + cf * ca * (1.0 - la)) / np.maximum(oa, 1e-6), 0.0)
        out = np.where(la > 0, mixed, cf)
        arr[:, x0:x1] = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


FORT_SRC = {
    '073_ww1_fort_artillery_要塞炮台': 'ww1_fort_artillery',
    '072_ww1_fort_pillbox_混凝土机枪碉堡': 'ww1_fort_pillbox',
    '074_ww2_fort_bunker_混凝土碉堡': 'ww2_fort_bunker',
    '076_cold_fort_missile_导弹发射井': 'cold_fort_missile',
    '078_mod_fort_citadel_要塞核心': 'mod_fort_citadel',
    '079_mod_fort_phalanx_近防炮系统': 'mod_fort_phalanx',
    '080_fut_fort_ion_离子炮台': 'fut_fort_ion',
}

for d, key in sorted(FORT_SRC.items()):
    dp = os.path.join(SRC, d)
    out_dir = os.path.join(DST, key)
    for anim in ('idle', 'attack'):
        frames = sorted(glob.glob(os.path.join(dp, anim, 'f*.png')))
        dep_path = os.path.join(out_dir, 'sheet_%s.png' % anim)
        if not frames or not os.path.isfile(dep_path):
            print(key, anim, 'SKIP (no frames or no deployed sheet)')
            continue
        sheet = Image.new('RGBA', (FRAME * len(frames), FRAME), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            im = Image.open(f).convert('RGBA')
            if im.size != (FRAME, FRAME):
                im = im.resize((FRAME, FRAME), Image.LANCZOS)
            sheet.paste(im, (i * FRAME, 0))
        sheet = bake_outline_on_sheet(sheet)
        dep = Image.open(dep_path).convert('RGBA')
        if dep.size != sheet.size:
            print(key, anim, 'SIZE DIFF', dep.size, sheet.size)
            continue
        a = np.asarray(sheet); b = np.asarray(dep)
        # 比 RGB（alpha 通道羽化可能有 ±1 抖动，先看整体）
        rgb_diff = (np.abs(a[..., :3].astype(int) - b[..., :3].astype(int)).max(axis=2) > 24)
        n = rgb_diff.sum()
        per_frame = [int(rgb_diff[:, i*FRAME:(i+1)*FRAME].sum()) for i in range(len(frames))]
        print(key, anim, 'diffpx=%d' % n, 'per-frame:', per_frame)
