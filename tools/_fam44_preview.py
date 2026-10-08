# -*- coding: utf-8 -*-
"""fam44 统一取景预览 GIF（2026-10-07）：旧预览每格独立缩放（格宽 800/815/881 不一），
整车在帧间横向呼吸 ~9% + 视觉上下跳。本工具以每格履带窗口量测的中心 x 为锚，
取 720×行高 固定窗口（允许越格边，越界=透明，不引入邻格残影），
六帧同一几何 → 只有火光动，车不动。

用法:
  python tools/_fam44_preview.py --sheet <sheet.png> --cuts "x1,x2|y1" \
      [--win "500,615|520,620"] [--tag _u] [--dur 140]
产出: <sheet><tag>.gif
"""
import argparse
import sys

from PIL import Image

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else "tools")
from _fam44_cell_normalize import measure


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cuts", required=True)
    ap.add_argument("--win", default=None, help='"500,615|520,620" 履带量测窗口')
    ap.add_argument("--tag", default="_u")
    ap.add_argument("--dur", type=int, default=140)
    args = ap.parse_args()

    win_top = win_bot = None
    if args.win:
        a, b = args.win.split("|")
        win_top = tuple(int(v) for v in a.split(","))
        win_bot = tuple(int(v) for v in b.split(","))

    sheet = Image.open(args.sheet).convert("RGBA")
    xs = [0] + [int(v) for v in args.cuts.split("|")[0].split(",")] + [sheet.width]
    ys = [0] + [int(v) for v in args.cuts.split("|")[1].split(",")] + [sheet.height]
    FW = 720

    frames = []
    for f_idx in range(6):
        r, c = f_idx // 3, f_idx % 3
        cell = sheet.crop((xs[c], ys[r], xs[c + 1], ys[r + 1]))
        m = measure(cell, win=win_top if r == 0 else win_bot)
        cx = m["gcx"] if m else cell.width / 2
        x0 = xs[c] + cx - FW / 2
        frame = Image.new("RGBA", (FW, ys[r + 1] - ys[r]), (0, 0, 0, 0))
        frame.alpha_composite(cell, (int(round(xs[c] - x0)), 0))
        bg = Image.new("RGBA", frame.size, (17, 17, 20, 255))
        bg.alpha_composite(frame)
        frames.append(bg.convert("RGB").resize((384, int(384 * frame.height / FW)),
                                               Image.LANCZOS))
        print(f"  格{f_idx+1} 中心={cx:.0f} 窗口x0={x0:.0f}", flush=True)

    out = args.sheet[:-4] + f"{args.tag}.gif"
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=args.dur, loop=0)
    print("OK", out)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
