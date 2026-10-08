# -*- coding: utf-8 -*-
"""fam44 链式帧·程序归一入格（2026-10-07 用户问「有用格子约束么」：生图层格导图已证伪
（阶段2 3/4 病根），格子约束改由代码 100% 执行——
每帧按锚定帧的暗内容 bbox（lum<180，排除浅烟/白底）等比缩放，地线对齐+中心x对齐后贴 832 格。

用法:
    python tools/_fam44_chain_norm.py <key> <mix名> --anchor <白底锚png> --frames f2.png f3.png ...
格1/6 固定=锚本体。产出: <key>_chain<mix名>_n_sheet_832.png / _n_anim.gif
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image

g_OUT = ".godot/unit_review/img25_staging/"
CELL = 832
DARK = 180  # 暗内容阈值：轮履/车体<180，浅烟>180 被排除，白底 255


def metrics(im):
    a = np.asarray(im.convert("L"))
    ys, xs = np.where(a < DARK)
    if len(xs) == 0:
        return None
    return {"x0": xs.min(), "x1": xs.max(), "y1": ys.max(),
            "h": ys.max() - ys.min() + 1, "cx": (xs.min() + xs.max()) / 2}


def norm_cell(frame_path, anchor832, m_a):
    fr = Image.open(frame_path).convert("RGB")
    m_f = metrics(fr)
    scale = m_a["h"] / m_f["h"]
    w, h = fr.size
    fr = fr.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    m_f2 = metrics(fr)
    dx = round(m_a["cx"] - m_f2["cx"])
    dy = round(m_a["y1"] - m_f2["y1"])
    cell = Image.new("RGB", (CELL, CELL), (255, 255, 255))
    cell.paste(fr, (dx, dy))
    return cell


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("mixname")
    ap.add_argument("--anchor", required=True)
    ap.add_argument("--frames", nargs="+", required=True, help="格2-5 共4张，顺序即格序")
    args = ap.parse_args()

    anchor = Image.open(args.anchor).convert("RGB").resize((CELL, CELL), Image.LANCZOS)
    m_a = metrics(anchor)
    cells = [anchor.copy()]
    for p in args.frames:
        cells.append(norm_cell(p, anchor, m_a))
    cells.append(anchor.copy())

    sheet = Image.new("RGB", (CELL * 3, CELL * 2), (255, 255, 255))
    gf = []
    for i, im in enumerate(cells):
        sheet.paste(im, ((i % 3) * CELL, (i // 3) * CELL))
        gf.append(im.resize((330, 330), Image.LANCZOS))
    base = "%s/%s_chain%s_n" % (g_OUT, args.key, args.mixname)
    sheet.save(base + "_sheet_832.png")
    gf[0].save(base + "_anim.gif", save_all=True, append_images=gf[1:], duration=125, loop=0)
    print("OK", base + "_sheet_832.png")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
