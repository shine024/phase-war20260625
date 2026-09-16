#!/usr/bin/env python3
"""B6（2026-09-14）：基地车剖面图 truck_cut1..5 白残留清除。
根因：agnes 白底图 flood_white_to_alpha 只清与图边连通的白区——轮组之间/底盘下方的
封闭白袋、贴边抠图渣点全部残留（cut3 底部最大，深底放大目视确认为成片白块）。

清除规则（保守，两层）：
  A. 与透明背景相邻的不透明白色连通块（≥238 纯白）且面积 ≤ 4000px → 清透明（贴边渣/毛边）
  B. 指定封闭白袋区（目前仅 cut3 底带 y>0.86 × x∈[0.03,0.92]）内的不透明白块 → 清透明
  车内合法白色内容（医疗箱白面/纸条/床单等，被彩色内容包围且不在 B 区）一律不动。

用法：默认 dry-run（输出 _anim_review/b6_previews/ 前后对比图 + 统计）；--apply 落盘。
原图备份 _art_backup/truck_cutN-preB6-2026-09-14.png（apply 时）。
"""
import os
import shutil
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = [os.path.join(ROOT, "assets", "ui", "truck_base", "truck_cut%d.png" % n) for n in range(1, 6)]
BAK_DIR = os.path.join(ROOT, "_art_backup")
PREVIEW_DIR = os.path.join(ROOT, "_anim_review", "b6_previews")

# 规则 B 的封闭白袋区（相对坐标 (x0, y0, x1, y1)；来源=2026-09-14 网格密度扫描+深底目视）
ENCLOSED_ZONES = {
    "truck_cut3.png": [(0.03, 0.86, 0.92, 1.00)],
}

WHITE_T = 238          # 近白阈值（与 flood_white_to_alpha 同口径）
ADJ_AREA_MAX = 4000    # 规则 A 的面积上限（贴边渣/毛边；大块 enclosed 内容不碰）


def near_white(p):
    return p[0] >= WHITE_T and p[1] >= WHITE_T and p[2] >= WHITE_T


def components(im):
    """不透明白色像素的连通块：[(area, set_of_(x,y))]（4 邻接）"""
    w, h = im.size
    px = im.load()
    mask = {}
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] > 200 and near_white(p):
                mask[(x, y)] = True
    seen = set()
    comps = []
    for start in mask:
        if start in seen:
            continue
        dq = deque([start])
        seen.add(start)
        pts = []
        while dq:
            x, y = dq.popleft()
            pts.append((x, y))
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in mask and (nx, ny) not in seen:
                    seen.add((nx, ny))
                    dq.append((nx, ny))
        comps.append((len(pts), pts))
    return comps, px, w, h


def touches_transparent(pts, px, w, h):
    for x, y in pts:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or nx >= w or ny < 0 or ny >= h:
                return True
            if px[nx, ny][3] < 10:
                return True
    return False


def in_zone(name, pts, w, h):
    zones = ENCLOSED_ZONES.get(name, [])
    if not zones:
        return False
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bx0, by0 = min(xs) / w, min(ys) / h
    bx1, by1 = max(xs) / w, max(ys) / h
    for zx0, zy0, zx1, zy1 in zones:
        if bx0 < zx1 and bx1 > zx0 and by0 < zy1 and by1 > zy0:
            return True
    return False


def flat_white(pts, px):
    """纯平白块（未抠白底的典型形态）：逐像素 RGB 通道极差 ≤ 10。
    车内合法白色（灯管/纸条/床单）都有 shading 或形态差异，用此判别 + 位置/形状双保险。"""
    for x, y in pts:
        p = px[x, y]
        if max(p[0], p[1], p[2]) - min(p[0], p[1], p[2]) > 10:
            return False
    return True


def dark_bg(im):
    bg = Image.new("RGBA", im.size, (40, 44, 52, 255))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def main():
    apply = "--apply" in sys.argv
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    total_removed = 0
    for path in SRC:
        name = os.path.basename(path)
        im = Image.open(path).convert("RGBA")
        comps, px, w, h = components(im)
        removed_pts = []
        for area, pts in comps:
            if area <= 2:
                continue
            if (touches_transparent(pts, px, w, h) and area <= ADJ_AREA_MAX) or in_zone(name, pts, w, h):
                removed_pts += pts
                continue
            # 规则 C（v2）：底部带（y≥0.70）的封闭平坦白块 = 轮组/尾架线缆间未抠净的白底。
            # 双保险排除合法白色：①车顶灯管形态（细长条 h≤6 且 w≥40，虽在 y0.19 不入本规则）；
            # ②上部车身内容（y<0.70 不入本规则）；③非纯平（有 shading）不删。
            ys_c = [p[1] for p in pts]
            xs_c = [p[0] for p in pts]
            bh = max(ys_c) - min(ys_c)
            bw = max(xs_c) - min(xs_c)
            if min(ys_c) / h >= 0.70 and area >= 60 and not (bh <= 6 and bw >= 40) \
                    and flat_white(pts, px):
                removed_pts += pts
        if not removed_pts:
            print("%s: 无残留（0 连通块命中）" % name)
            continue
        # 变更区域 bbox（外扩 12px）出前后对比图
        xs = [p[0] for p in removed_pts]
        ys = [p[1] for p in removed_pts]
        bx0 = max(0, min(xs) - 12); by0 = max(0, min(ys) - 12)
        bx1 = min(w, max(xs) + 12); by1 = min(h, max(ys) + 12)
        before = dark_bg(im.crop((bx0, by0, bx1, by1)))
        if apply:
            bak = os.path.join(BAK_DIR, name.replace(".png", "-preB6-2026-09-14.png"))
            if not os.path.exists(bak):
                shutil.copy2(path, bak)
                print("  [bak]", bak)
            upx = im.load()
            for x, y in removed_pts:
                upx[x, y] = (0, 0, 0, 0)
            im.save(path)
            print("%s: 已清除 %d px（%d 连通块）" % (name, len(removed_pts), len(comps)))
        after = dark_bg(Image.open(path).convert("RGBA").crop((bx0, by0, bx1, by1))) if apply else None
        cw, ch = before.size
        scale = max(1, min(3, 900 // max(1, cw)))
        pv = Image.new("RGB", (cw * scale, ch * scale * (2 if after else 1) + 8), (20, 20, 20))
        pv.paste(before.resize((cw * scale, ch * scale), Image.NEAREST), (0, 0))
        if after:
            pv.paste(after.resize((cw * scale, ch * scale), Image.NEAREST), (0, ch * scale + 8))
        pv_path = os.path.join(PREVIEW_DIR, ("applied_" if apply else "dry_") + name)
        pv.save(pv_path)
        total_removed += len(removed_pts)
        print("%s: %s %d px（区域 (%d,%d)-(%d,%d)，预览 %s）" % (
            name, "清除" if apply else "将清除", len(removed_pts), bx0, by0, bx1, by1,
            os.path.basename(pv_path)))
    print("TOTAL %d px %s" % (total_removed, "APPLIED" if apply else "(dry-run)"))
    if not apply:
        print("目视预览后加 --apply 落盘")


if __name__ == "__main__":
    main()
