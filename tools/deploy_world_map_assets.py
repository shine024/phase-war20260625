# -*- coding: utf-8 -*-
"""
deploy_world_map_assets.py —— 百灯群岛世界地图生图后处理与部署
输入：docs/地图重设计/generated/*.jpeg（13 张：白底精灵 + 2 张整幅底图）
输出：assets/map/*.png
  - map_void_base  ：整幅不透明，宽 < 2560 时 LANCZOS 放大到 2560（平移画布余量）
  - gate_near      ：整幅不透明，原样转存
  - debris_sheet   ：白底→透明后按 4×2 网格切片 → debris_1..8.png（各片独立裁边）
  - 其余精灵       ：边缘泛洪白底→透明（保留内部高光）→ alpha 裁边
白底转透明流程与 deploy_bunker_v2.py 同源。
用法：python tools/deploy_world_map_assets.py
"""
import os
from collections import deque

from PIL import Image

SRC = r"docs/地图重设计/generated"
DST = r"assets/map"

# 不做透明处理的整幅底图
BASES = {"map_void_base", "gate_near"}
# 网格切片表
SLICES = {"debris_sheet": (4, 2)}  # (cols, rows)
VOID_TARGET_W = 2560


def flood_white_to_alpha(im, thresh=238):
    """从四边泛洪：与白色接近的连通区域 → 透明。物体内部的白色高光保留。"""
    im = im.convert("RGBA")
    w, h = im.size
    work = im.copy()
    px = work.load()

    def is_white(p):
        return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh

    seen = bytearray(w * h)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(px[x, y]):
                dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(px[x, y]):
                dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        if not is_white(px[x, y]):
            continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        dq.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return work


def autocrop(im, pad=4):
    bbox = im.getchannel("A").getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def slice_sheet(im, cols, rows, prefix):
    """按网格切片 → 各片独立裁边。切片基于原始像素网格（未 autocrop，保持等分有效）。"""
    cw = im.width // cols
    ch = im.height // rows
    n = 0
    for r in range(rows):
        for c in range(cols):
            cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            cell = autocrop(cell)
            out_name = f"{prefix}_{n + 1}.png"
            cell.save(os.path.join(DST, out_name))
            print(f"[slice] {out_name:24s} {cell.size[0]}x{cell.size[1]}")
            n += 1
    return n


def main():
    os.makedirs(DST, exist_ok=True)
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith((".jpeg", ".jpg", ".png")))
    sliced = 0
    for f in files:
        name, _ = os.path.splitext(f)
        im = Image.open(os.path.join(SRC, f))
        if name in BASES:
            out = im.convert("RGB")
            if name == "map_void_base" and out.width < VOID_TARGET_W:
                ratio = VOID_TARGET_W / out.width
                out = out.resize((VOID_TARGET_W, round(out.height * ratio)), Image.LANCZOS)
            out.save(os.path.join(DST, name + ".png"))
            print(f"[base ] {name:24s} {im.size[0]}x{im.size[1]} → {out.size[0]}x{out.size[1]}")
        elif name in SLICES:
            cols, rows = SLICES[name]
            transparent = flood_white_to_alpha(im)
            sliced = slice_sheet(transparent, cols, rows, "debris")
            print(f"[sheet] {name:24s} {im.size[0]}x{im.size[1]} → {sliced} 张切片")
        else:
            out = autocrop(flood_white_to_alpha(im))
            out.save(os.path.join(DST, name + ".png"))
            print(f"[sprite] {name:23s} {im.size[0]}x{im.size[1]} → {out.size[0]}x{out.size[1]} RGBA")
    print(f"\n部署完成 → {DST}（{len(files) - 1} 张输入：{len(BASES)} 底图 + {sliced} 切片 + 其余精灵直出）")


if __name__ == "__main__":
    main()
