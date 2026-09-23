# -*- coding: utf-8 -*-
"""一次性修复 ww1_arm_rolls 雪碧图（v6.14.7，可删）：
存量 sheet 是 128px/帧错距（anim.json 声明 frame_size=256 → 战场每格显示 2 辆车）。
用工作区 039 源帧（idle 8 + attack 12，512²）按 tools/deploy_unit_anims.py 同一管线
（LANCZOS 256 缩放 + cv2 逐帧切片描边烘焙）只重部署该单位。旧资产备份 .godot/。
"""
import datetime
import glob
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "_anim_review", "资料", "单位分帧动画",
                   "039_ww1_arm_rolls_罗尔斯装甲车")
DST = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww1_arm_rolls")
BAK = os.path.join(ROOT, ".godot", "art_backup_rolls_fix_" + datetime.date.today().isoformat())
FRAME = 256
FPS = 8
OUTLINE_WIDTH_PX = 4
OUTLINE_COLOR = (13, 18, 28, 217)
OUTLINE_FEATHER = 0.6


def bake_outline_on_sheet(sheet, frame=FRAME, w_px=OUTLINE_WIDTH_PX,
                          color=OUTLINE_COLOR, feather=OUTLINE_FEATHER):
    """与 tools/deploy_unit_anims.py 逐字同款：按帧切片独立 alpha 膨胀烘焙描边。"""
    import cv2
    if sheet.width % frame != 0:
        raise ValueError("sheet 宽 %d 不是帧宽 %d 的整数倍" % (sheet.width, frame))
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


def outline_meta(frame_basis=FRAME, w_px=OUTLINE_WIDTH_PX):
    return {"baked": True, "width_px": w_px,
            "color": list(OUTLINE_COLOR), "frame_basis": frame_basis}


def main():
    os.makedirs(BAK, exist_ok=True)
    # 1. 备份旧资产（sheet/anim.json/散帧 f*.png 一并）
    for f in glob.glob(os.path.join(DST, "*.png")) + glob.glob(os.path.join(DST, "anim.json")):
        shutil.copy2(f, os.path.join(BAK, os.path.basename(f)))
    print("backup ->", BAK)

    # 2. 源帧 → 256 横条 + 描边烘焙
    counts = {}
    for anim in ("idle", "attack"):
        frames = sorted(glob.glob(os.path.join(SRC, anim, "f*.png")))
        if len(frames) < 4:
            print("!! skip %s: only %d frames" % (anim, len(frames)))
            continue
        sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            im = Image.open(f).convert("RGBA")
            if im.size != (FRAME, FRAME):
                im = im.resize((FRAME, FRAME), Image.LANCZOS)
            sheet.paste(im, (i * FRAME, 0))
        sheet = bake_outline_on_sheet(sheet)
        sheet.save(os.path.join(DST, "sheet_%s.png" % anim))
        counts[anim] = len(frames)
        print("sheet_%s: %d frames -> %d×%d" % (anim, len(frames), sheet.width, sheet.height))

    # 3. anim.json（与工具写盘同构）
    meta = {"fps": FPS, "frame_size": FRAME, "counts": counts}
    if counts:
        meta["outline"] = outline_meta()
    json.dump(meta, open(os.path.join(DST, "anim.json"), "w", encoding="utf-8"))
    print("anim.json:", meta)

    # 4. 移走 assets 里遗留的散帧 f*.png（无任何加载方引用，疑似错距 sheet 的产物）
    for f in glob.glob(os.path.join(DST, "f*.png")):
        shutil.move(f, os.path.join(BAK, os.path.basename(f)))
    print("stale loose frames moved to backup")
    sys.exit(0)


if __name__ == "__main__":
    main()
