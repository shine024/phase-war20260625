# -*- coding: utf-8 -*-
"""fam44 六格尺寸归一（2026-10-07）：整版法伴生病——逐格独立生成导致主体大小/站位漂移，
动画=呼吸/弹跳。按「地带宽」（履带/轮距，底部15%行，对炮管姿态鲁棒）求缩放系数，
缩放后对齐 格1 地线 y（+可选横向中心）。

用法:
  python tools/_fam44_cell_normalize.py --sheet <fix.png> --cuts "x1,x2|y1" \
      --scales "2=1.016,3=1.076,..." [--align-x] [--tag _n]

  105mm 格3 类后坐帧地带退化（只剩拖尾触地）时，缩放系数请手填 bbox 高比。
产出: <sheet><tag>.png；打印各格前后诊断。
"""
import argparse
import os
import sys

from PIL import Image


def measure(cell, win=None):
    """主体 bbox + 地带横向范围 + 地线 y。win=(y0,y1) 时只在窗口行内量（烟火不掺入基准）。"""
    W, H = cell.size
    box = cell.getbbox(alpha_only=True)
    if not box:
        return None
    x0, y0, x1, y1 = box
    if win:
        gtop, gbot = win
    else:
        gtop = y1 - max(8, int((y1 - y0) * 0.15))
        gbot = y1
    px = cell.load()
    gminx, gmaxx, gy = W, 0, gtop
    for y in range(gtop, min(gbot, H)):
        hit = False
        for x in range(W):
            if px[x, y][3] > 60:
                gminx = min(gminx, x)
                hit = True
                break
        for x in range(W - 1, -1, -1):
            if px[x, y][3] > 60:
                gmaxx = max(gmaxx, x)
                break
        if hit:
            gy = y
    if gmaxx < gminx:
        return None
    return {"bbox": box, "gw": gmaxx - gminx, "gcx": (gminx + gmaxx) / 2,
            "gy": gy, "h": y1 - y0}


def rescale_anchored(cell, f, src_cx, src_gy, dst_cx, dst_gy):
    """整格 LANCZOS 缩放 f，锚定 (src_cx, src_gy)→(dst_cx, dst_gy)，裁回格内。"""
    W, H = cell.size
    nw, nh = max(1, int(round(W * f))), max(1, int(round(H * f)))
    rs = cell.resize((nw, nh), Image.LANCZOS)
    ox = int(round(dst_cx - src_cx * f))
    oy = int(round(dst_gy - src_gy * f))
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sx0, sy0 = max(0, -ox), max(0, -oy)
    dx0, dy0 = max(0, ox), max(0, oy)
    w = min(nw - sx0, W - dx0)
    h = min(nh - sy0, H - dy0)
    canvas.paste(rs.crop((sx0, sy0, sx0 + w, sy0 + h)), (dx0, dy0))
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cuts", required=True)
    ap.add_argument("--scales", required=True, help="2=1.016,3=1.076,...")
    ap.add_argument("--align-x", action="store_true")
    ap.add_argument("--win", default=None,
                    help='"520,600|1310,1400" 上下行履带量测窗口（烟火污染基准时用）')
    ap.add_argument("--tag", default="_n")
    args = ap.parse_args()

    win_top = win_bot = None
    if args.win:
        a, b = args.win.split("|")
        win_top = tuple(int(v) for v in a.split(","))
        win_bot = tuple(int(v) for v in b.split(","))

    sheet = Image.open(args.sheet).convert("RGBA")
    xs = [0] + [int(v) for v in args.cuts.split("|")[0].split(",")] + [sheet.width]
    ys = [0] + [int(v) for v in args.cuts.split("|")[1].split(",")] + [sheet.height]
    scales = {}
    for kv in args.scales.split(","):
        if kv.strip():
            k, v = kv.split("=")
            scales[int(k)] = float(v)

    cells, ms = {}, {}
    for f_idx in range(6):
        r, c = f_idx // 3, f_idx % 3
        cells[f_idx + 1] = sheet.crop((xs[c], ys[r], xs[c + 1], ys[r + 1]))
        ms[f_idx + 1] = measure(cells[f_idx + 1],
                                win=win_top if r == 0 else win_bot)
    ref = ms[1]
    print(f"基准 格1: 地带宽={ref['gw']} 地线y={ref['gy']} 中心x={ref['gcx']:.0f}")

    for f_idx in range(2, 7):
        m = ms[f_idx]
        f = scales.get(f_idx, 1.0)
        if m is None or abs(f - 1.0) < 0.005:
            print(f"  格{f_idx}: 跳过（f={f:.3f}）")
            continue
        dst_cx = ref["gcx"] if args.align_x else m["gcx"]
        new = rescale_anchored(cells[f_idx], f, m["gcx"], m["gy"], dst_cx, ref["gy"])
        m2 = measure(new, win=(win_top if (f_idx - 1) // 3 == 0 else win_bot)
                     if args.win else None)
        cells[f_idx] = new
        print(f"  格{f_idx}: f={f:.3f} 地带宽 {m['gw']}→{m2['gw']} 地线 {m['gy']}→{m2['gy']}"
              f" 中心x {m['gcx']:.0f}→{m2['gcx']:.0f}")

    for f_idx, cell in cells.items():
        r, c = (f_idx - 1) // 3, (f_idx - 1) % 3
        sheet.paste(cell, (xs[c], ys[r]))

    out = args.sheet[:-4] + args.tag + ".png"
    sheet.save(out)
    print("OK", out)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
