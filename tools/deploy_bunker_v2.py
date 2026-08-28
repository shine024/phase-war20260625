# -*- coding: utf-8 -*-
"""
deploy_bunker_v2.py —— 基地 v2 生图后处理与部署
输入：docs/基地重设计/generated/*.jpeg（25 张，白底 JPEG）
输出：assets/bunker/v2/*.png（透明底 PNG，2x 逻辑尺寸，已裁边）
       + bg_sky / bg_rock 原样转存 PNG
流程：边缘泛洪白底→透明（保留物体内部白色高光）→ alpha 裁边 → 存 PNG
用法：python tools/deploy_bunker_v2.py
"""
import os
from PIL import Image, ImageDraw

SRC = r"docs/基地重设计/generated"
DST = r"assets/bunker/v2"
# 不做透明处理的整幅底图
BASES = {"bg_sky", "bg_rock"}

def flood_white_to_alpha(im, thresh=238):
    """从四边泛洪：与白色接近的连通区域 → 透明。物体内部的白色高光保留。"""
    im = im.convert("RGBA")
    w, h = im.size
    marker = (255, 0, 255, 255)  # 洋红标记
    work = im.copy()
    px = work.load()
    def is_white(p):
        return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh
    from collections import deque
    seen = bytearray(w * h)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(px[x, y]): dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(px[x, y]): dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h: continue
        i = y * w + x
        if seen[i]: continue
        p = px[x, y]
        if not (p[0] >= thresh and p[1] >= thresh and p[2] >= thresh): continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        dq.append((x+1,y)); dq.append((x-1,y)); dq.append((x,y+1)); dq.append((x,y-1))
    return work

def autocrop(im, pad=4):
    bbox = im.getchannel("A").getbbox()
    if not bbox: return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad); y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))

def main():
    os.makedirs(DST, exist_ok=True)
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith((".jpeg", ".jpg", ".png")))
    for f in files:
        name, _ = os.path.splitext(f)
        im = Image.open(os.path.join(SRC, f))
        if name in BASES:
            out = im.convert("RGB")
            print(f"[base ] {name:28s} {im.size[0]}x{im.size[1]} → 原样转存")
        else:
            out = autocrop(flood_white_to_alpha(im))
            print(f"[sprite] {name:27s} {im.size[0]}x{im.size[1]} → {out.size[0]}x{out.size[1]} RGBA")
        out.save(os.path.join(DST, name + ".png"))
    print(f"\n部署完成 → {DST}（{len(files)} 张）")

if __name__ == "__main__":
    main()
