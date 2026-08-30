#!/usr/bin/env python3
"""图片高倍质量放大：Lanczos + 分步逼近 + 轻锐化。

用法：
    python tools/upscale_4k.py <输入图> [输出目录]

输出（与输入同目录）：
    <名>_4K.png / _4K.jpg        3840×2160
    <名>_2560.png                2560×1440（游戏文档规格画布）
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

TARGETS = {"_4K": (3840, 2160), "_2560": (2560, 1440)}


def upscale_to(im: Image.Image, target: tuple) -> Image.Image:
    """分步 Lanczos（每步 ≤1.5×）+ 末端轻锐化，细节保持优于一步到位。"""
    out = im
    while out.size[0] * 1.5 < target[0]:
        out = out.resize((int(out.size[0] * 1.5), int(out.size[1] * 1.5)), Image.LANCZOS)
    out = out.resize(target, Image.LANCZOS)
    return out.filter(ImageFilter.UnsharpMask(radius=1.4, percent=48, threshold=2))


def main() -> int:
    src = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(src)
    base = os.path.splitext(os.path.basename(src))[0]

    im = Image.open(src).convert("RGB")
    print(f"输入 {im.size[0]}×{im.size[1]}", flush=True)
    for suffix, target in TARGETS.items():
        out = upscale_to(im, target)
        png = os.path.join(out_dir, f"{base}{suffix}.png")
        out.save(png)
        print(f"✓ {png} {out.size} ({os.path.getsize(png):,} B)", flush=True)
        if suffix == "_4K":
            jpg = os.path.join(out_dir, f"{base}{suffix}.jpg")
            out.save(jpg, quality=93)
            print(f"✓ {jpg} ({os.path.getsize(jpg):,} B)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
