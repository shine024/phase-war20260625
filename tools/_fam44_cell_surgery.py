# -*- coding: utf-8 -*-
"""fam44 格级手术（2026-10-07）
对 sheet_832 做确定性修整：翻回误翻转格 / 品红渍清除 / 青辉光去饱和 / 游离碎屑清除。
输出 _fix.png（不覆写原件，幂等可重跑）。

用法:
  python tools/_fam44_cell_surgery.py --sheet <sheet_832.png> --cuts "x1,x2|y1" \
      [--flip 2,6] [--scrub-pink] [--desat-cyan] [--despeckle 150]
"""
import argparse
import sys
from collections import deque

from PIL import Image


def cells_of(im, cuts):
    xs = [0] + [int(v) for v in cuts.split("|")[0].split(",")] + [im.width]
    ys = [0] + [int(v) for v in cuts.split("|")[1].split(",")] + [im.height]
    out = []
    for r in range(2):
        for c in range(3):
            out.append((xs[c], ys[r], xs[c + 1], ys[r + 1]))
    return out  # 格1..6 行主序


def scrub_pink(im):
    """强品红→透明；弱紫→去饱和为灰。"""
    px = im.load()
    w, h = im.size
    n_kill = n_des = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mn = min(r, b)
            if r > 90 and b > 90 and g < 0.55 * mn:
                px[x, y] = (r, g, b, 0)
                n_kill += 1
            elif mn >= 25 and g < 0.35 * mn and r + b - 2 * g > 60:
                px[x, y] = (r, g, b, 0)  # 中紫残留（g≈0 的 r≈b）→ 直接杀，去饱和只会留灰斑
                n_kill += 1
            elif r + b - 2 * g > 100 and abs(r - b) < 100:
                v = (r + g + b) // 3
                px[x, y] = (v, v, v, a)
                n_des += 1
    return n_kill, n_des


def desat_cyan(im):
    """青蓝辉光→亮度灰（保留 alpha）。"""
    px = im.load()
    w, h = im.size
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and g - r > 45 and b - r > 60:
                v = (r * 30 + g * 60 + b * 60) // 150
                px[x, y] = (v, v, v, a)
                n += 1
    return n


def despeckle(im, min_px):
    """与本格主体不相连的小连通域 → alpha 0。"""
    w, h = im.size
    px = im.load()
    mask = [[px[x, y][3] > 40 for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    n = 0
    for y in range(h):
        for x in range(w):
            if mask[y][x] and not seen[y][x]:
                q = deque([(x, y)])
                seen[y][x] = True
                pts = []
                while q:
                    cx, cy = q.popleft()
                    pts.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
                if len(pts) < min_px:
                    for cx, cy in pts:
                        r, g, b, _ = px[cx, cy]
                        px[cx, cy] = (r, g, b, 0)
                    n += 1
    return n


def kill_below_shadow(im, cells):
    """每列找不透明实体最低点，其下方暗色像素（不论alpha）＝影子/地面渍 → alpha 0。"""
    px = im.load()
    n = 0
    for (x0, y0, x1, y1) in cells:
        for x in range(x0, x1):
            y_op = None
            for y in range(y1 - 1, y0 - 1, -1):
                if px[x, y][3] >= 240:
                    y_op = y
                    break
            if y_op is None:
                continue
            for y in range(y_op + 3, y1):
                r, g, b, a = px[x, y]
                if a > 0 and max(r, g, b) < 165:
                    px[x, y] = (r, g, b, 0)
                    n += 1
    return n


def erase_rects(im, cells, spec):
    """cell:x0,y0,x1,y1;... → 区域内置透明（cell 为 1..6）。"""
    px = im.load()
    n = 0
    for tok in spec.split(";"):
        tok = tok.strip()
        if not tok:
            continue
        ci, rest = tok.split(":", 1)
        x0, y0, x1, y1 = (int(v) for v in rest.split(","))
        c = cells[int(ci) - 1]
        for y in range(c[1] + y0, min(c[1] + y1, c[3])):
            for x in range(c[0] + x0, min(c[0] + x1, c[2])):
                if px[x, y][3]:
                    px[x, y] = (0, 0, 0, 0)
                    n += 1
    return n


def clone_cells(im, cells, spec):
    """dst=src,dx;... → 用清洗后的 src 格覆盖 dst 格（dx=沿横轴右移像素，0 为逐像素复制）。"""
    n = 0
    for tok in spec.split(";"):
        tok = tok.strip()
        if not tok:
            continue
        d, rest = tok.split("=")
        s, dx = (rest.split(",") + ["0"])[:2]
        d, s, dx = int(d) - 1, int(s) - 1, int(dx)
        cd, cs = cells[d], cells[s]
        region = im.crop(cs)
        if dx:
            region = region.transform(
                region.size, Image.AFFINE, (1, 0, -dx, 0, 1, 0), resample=Image.NEAREST)
        im.paste(Image.new("RGBA", region.size, (0, 0, 0, 0)), (cd[0], cd[1]))
        im.paste(region, (cd[0], cd[1]))
        n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cuts", required=True)
    ap.add_argument("--flip", default="")
    ap.add_argument("--scrub-pink", action="store_true")
    ap.add_argument("--desat-cyan", action="store_true")
    ap.add_argument("--despeckle", type=int, default=0)
    ap.add_argument("--kill-below-shadow", action="store_true")
    ap.add_argument("--void-black", action="store_true")
    ap.add_argument("--clone", default="", help="dst=src,dx;... 用 src 格盖 dst 格")
    ap.add_argument("--erase", default="", help="cell:x0,y0,x1,y1;... 格内坐标")
    args = ap.parse_args()

    im = Image.open(args.sheet).convert("RGBA")
    cells = cells_of(im, args.cuts)
    for tok in args.flip.split(","):
        tok = tok.strip()
        if not tok:
            continue
        i = int(tok) - 1
        c = cells[i]
        im.paste(im.crop(c).transpose(Image.FLIP_LEFT_RIGHT), (c[0], c[1]))
        print("翻转回原 格%d" % (i + 1))
    if args.scrub_pink:
        k, d = scrub_pink(im)
        print("品红强杀 %d px / 弱紫去饱和 %d px" % (k, d))
    if args.desat_cyan:
        print("青辉光去饱和 %d px" % desat_cyan(im))
    if args.kill_below_shadow:
        print("杀实体下方阴影 %d px" % kill_below_shadow(im, cells))
    if args.erase:
        print("矩形擦除 %d px" % erase_rects(im, cells, args.erase))
    for i, c in enumerate(cells):
        cell = im.crop(c)
        if args.despeckle > 0:
            n = despeckle(cell, args.despeckle)
            if n:
                print("格%d 清碎屑 %d 处" % (i + 1, n))
            im.paste(cell, (c[0], c[1]))
    if args.clone:
        print("克隆重建 %d 格" % clone_cells(im, cells, args.clone))
    if args.void_black:
        # a=0 残影 RGB 归零：防双线性缩放渗色（品红边晕）
        px = im.load()
        n = 0
        for y in range(im.height):
            for x in range(im.width):
                if px[x, y][3] == 0 and px[x, y][:3] != (0, 0, 0):
                    px[x, y] = (0, 0, 0, 0)
                    n += 1
        print("透明残影归黑 %d px" % n)
    out = args.sheet[:-4] + "_fix.png"
    im.save(out)
    print("OK", out)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
