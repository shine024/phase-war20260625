# -*- coding: utf-8 -*-
"""
deploy_world_map_assets.py —— 世界地图生图后处理与部署
输入：docs/地图重设计/generated/*.jpeg
输出：assets/map/*.png
流程分四类：
  1. 整幅底图（BASES）：map_void_base / gate_near 原样转存；dawn_dusk_continent 放大 2560×1440
  2. 网格切片表（SLICES）：debris_sheet 4×2 → debris_1..8
  3. 连通域切片（COMPONENT_SHEETS）：wreck_sheet_land 白转透明后按连通域拆 8 件 → wreck_1..8
     （该图 8 件错落排布，非规整网格，固定网格切会切坏件）
  4. 圆形蒙版（CIRCLE_MASKS）：black_sun 深底不能用白转透明，按圆心+羽化半径出 alpha
  其余精灵：边缘泛洪白底→透明（保留内部高光）→ alpha 裁边
用法：python tools/deploy_world_map_assets.py
"""
import os
from collections import deque

from PIL import Image, ImageDraw, ImageFilter

SRC = r"docs/地图重设计/generated"
DST = r"assets/map"

# 不做透明处理的整幅底图（dawn_dusk_continent 额外放大到画布尺寸）
BASES = {"map_void_base", "gate_near", "dawn_dusk_continent"}
BASE_UPSCALE = {"dawn_dusk_continent": (2560, 1440)}
# 规整网格切片表
SLICES = {"debris_sheet": (4, 2)}  # (cols, rows)
# 连通域切片表（件数上限，取最大连通域）
COMPONENT_SHEETS = {"wreck_sheet_land": 8}
# 圆形蒙版表：{名: (圆心相对cx,cy, 半径占边长比, 羽化px[, auto_dark])}
# auto_dark=True：自动检测图内黑盘实测圆心/半径（黑盘主体常不满幅，固定比例会切进
# 盘外白底），×1.15 收进外晕；检测失败回退固定比例。
CIRCLE_MASKS = {"black_sun": (0.5, 0.5, 0.44, 14, True)}
# 工作文件忽略清单：generated/ 下的非部署素材（中间稿/候选图），不进 assets
# （前缀匹配：大地图* 为用户工作稿；candidates/工作子目录由扩展名过滤天然跳过）
IGNORE_PREFIXES = ("大地图",)
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


def component_split(im, max_items, prefix, min_area=900):
    """连通域拆件：白转透明图上按 alpha>8 做 4 邻接 BFS 标记，取面积最大的前 max_items 件。"""
    w, h = im.size
    a = im.getchannel("A")
    apx = a.load()
    label = bytearray(w * h)  # 0=未访问 1=已访问
    comps = []  # (area, x0,y0,x1,y1, 像素索引列表首)——大图存索引太费，改为二次收集
    heads = []
    for sy in range(h):
        for sx in range(w):
            if apx[sx, sy] > 8 and not label[sy * w + sx]:
                area = 0
                x0, y0, x1, y1 = sx, sy, sx, sy
                dq = deque([(sx, sy)])
                label[sy * w + sx] = 1
                while dq:
                    x, y = dq.popleft()
                    area += 1
                    if x < x0: x0 = x
                    if x > x1: x1 = x
                    if y < y0: y0 = y
                    if y > y1: y1 = y
                    for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                        if 0 <= nx < w and 0 <= ny < h:
                            j = ny * w + nx
                            if not label[j] and apx[nx, ny] > 8:
                                label[j] = 1
                                dq.append((nx, ny))
                if area >= min_area:
                    heads.append((area, x0, y0, x1, y1))
    heads.sort(reverse=True)
    n = 0
    for area, x0, y0, x1, y1 in heads[:max_items]:
        pad = 6
        box = (max(0, x0 - pad), max(0, y0 - pad),
               min(w, x1 + 1 + pad), min(h, y1 + 1 + pad))
        cell = im.crop(box)
        n += 1
        out_name = f"{prefix}_{n}.png"
        cell.save(os.path.join(DST, out_name))
        print(f"[comp ] {out_name:24s} {cell.size[0]}x{cell.size[1]}  area={area}")
    return n


def detect_dark_disc(im, dark_thresh=90):
    """检测白底图内的黑盘主体：暗像素(<thresh)包围盒 → (cx, cy, r)。无暗像素返回 None。"""
    gray = im.convert("L")
    mask = gray.point(lambda v: 255 if v < dark_thresh else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return None
    cx = (bbox[0] + bbox[2]) / 2.0
    cy = (bbox[1] + bbox[3]) / 2.0
    r = max(bbox[2] - bbox[0], bbox[3] - bbox[1]) / 2.0
    return cx, cy, r


def circle_mask(im, cx_r, cy_r, r_ratio, feather, auto_dark=False):
    """圆形 alpha 蒙版：圆内不透明、边缘羽化、圆外全透明（用于深底圆形主体）。
    auto_dark：黑盘实测范围优先于固定比例（避免把盘外白底圈进贴图）。"""
    im = im.convert("RGBA")
    w, h = im.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    r = r_ratio * max(w, h)
    cx, cy = w * cx_r, h * cy_r
    if auto_dark:
        det = detect_dark_disc(im)
        if det is not None:
            cx, cy, r = det[0], det[1], det[2] * 1.15
            print(f"        黑盘实测: 圆心({cx:.0f},{cy:.0f}) 半径{det[2]:.0f} → 蒙版半径{r:.0f}")
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather))
    im.putalpha(mask)
    return autocrop(im)


def main():
    os.makedirs(DST, exist_ok=True)
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith((".jpeg", ".jpg", ".png")))
    sliced = 0
    for f in files:
        name, _ = os.path.splitext(f)
        if any(name.startswith(p) for p in IGNORE_PREFIXES):
            continue
        im = Image.open(os.path.join(SRC, f))
        if name in BASES:
            out = im.convert("RGB")
            if name in BASE_UPSCALE:
                tw, th = BASE_UPSCALE[name]
                out = out.resize((tw, th), Image.LANCZOS)
            elif name == "map_void_base" and out.width < VOID_TARGET_W:
                ratio = VOID_TARGET_W / out.width
                out = out.resize((VOID_TARGET_W, round(out.height * ratio)), Image.LANCZOS)
            out.save(os.path.join(DST, name + ".png"))
            print(f"[base ] {name:24s} {im.size[0]}x{im.size[1]} → {out.size[0]}x{out.size[1]}")
        elif name in CIRCLE_MASKS:
            spec = CIRCLE_MASKS[name]
            out = circle_mask(im, spec[0], spec[1], spec[2], spec[3],
                              auto_dark=(len(spec) > 4 and bool(spec[4])))
            out.save(os.path.join(DST, name + ".png"))
            print(f"[circle] {name:23s} {im.size[0]}x{im.size[1]} → {out.size[0]}x{out.size[1]} RGBA")
        elif name in SLICES:
            cols, rows = SLICES[name]
            transparent = flood_white_to_alpha(im)
            sliced += slice_sheet(transparent, cols, rows, "debris")
            print(f"[sheet] {name:24s} {im.size[0]}x{im.size[1]} → {sliced} 张切片")
        elif name in COMPONENT_SHEETS:
            transparent = flood_white_to_alpha(im)
            n = component_split(transparent, COMPONENT_SHEETS[name], "wreck")
            print(f"[sheet] {name:24s} {im.size[0]}x{im.size[1]} → {n} 件连通域")
        else:
            out = autocrop(flood_white_to_alpha(im))
            out.save(os.path.join(DST, name + ".png"))
            print(f"[sprite] {name:23s} {im.size[0]}x{im.size[1]} → {out.size[0]}x{out.size[1]} RGBA")
    print(f"\n部署完成 → {DST}")


if __name__ == "__main__":
    main()
