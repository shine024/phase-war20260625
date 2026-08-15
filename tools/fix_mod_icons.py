#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复改造模块图标：
- 白底转透明（85 张全部是白底不透明 → 深色 UI 里是白色方块）
- 尺寸归一 512×512（3 张 1024）
- 图标内容保持原比例居中（不裁切：白转透明后按内容 bbox 居中放置，留 8% 边）
"""
import os
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")


def white_to_alpha(img: Image.Image) -> Image.Image:
    arr = np.array(img.convert("RGB"), dtype=np.int16)
    brightness = arr.sum(axis=2) / 3.0
    alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([
        arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
        arr[:, :, 2].astype(np.uint8), alpha]), "RGBA")


def recenter(img: Image.Image, size: int = 512, fill: float = 0.84) -> Image.Image:
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * fill
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def main() -> None:
    ok = 0
    for f in sorted(os.listdir(D)):
        if not f.endswith(".png"):
            continue
        p = os.path.join(D, f)
        img = white_to_alpha(Image.open(p))
        img = recenter(img)
        img.save(p, "PNG")
        ok += 1
    print(f"processed {ok} mod icons")


if __name__ == "__main__":
    main()
