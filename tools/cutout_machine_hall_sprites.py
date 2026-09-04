# -*- coding: utf-8 -*-
"""cutout_machine_hall_sprites.py —— 机枢大厅白底精灵抠图（边缘泛洪法）

与 deploy_card_icons_11.py 的全局亮度阈值不同：这里只抠"与画面边缘连通的近白区域"，
机身内部的白灯/白汽/白卡（炊事机蒸汽、打印机白卡、白板便签）完整保留。

流程：边缘取种（近白处）→ PIL floodfill 打标 → 背景掩码 → alpha 侵蚀 1px 去白边
     → alpha bbox 自动裁边（留 2px 边距）→ 存 PNG。
输入：docs/基地重设计/generated_mh/mh_*_wreck.jpeg / _active.jpeg / mh_panel_*.jpeg
输出：同名 .png（透明底），原地同目录。
用法：python tools/cutout_machine_hall_sprites.py          # 全部
      python tools/cutout_machine_hall_assets.py generator  # 单机器两态（可选参数同生成器 id）
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "基地重设计", "generated_mh")

SENTINEL = (255, 0, 255)   # 泛洪填充哨兵色（洋红）
NEAR_WHITE = 205           # 种子点亮度门槛
FLOOD_THRESH = 34          # floodfill 容差（吃掉 JPEG 边缘噪点）

MACHINE_IDS = ["generator", "war_table", "lab_bench", "analyzer", "radio",
               "rest_pod", "workbench", "galley", "printer"]
PANEL_IDS = ["panel_t1_whiteboard", "panel_t2_crt", "panel_t3_holo"]


def is_near_white(px):
    return (int(px[0]) + int(px[1]) + int(px[2])) / 3.0 >= NEAR_WHITE


def edge_seeds(img):
    """沿四边每 48px 取一个近白种子点。"""
    w, h = img.size
    pts = []
    for x in range(8, w, 48):
        pts += [(x, 2), (x, h - 3)]
    for y in range(8, h, 48):
        pts += [(2, y), (w - 3, y)]
    px = img.load()
    return [p for p in pts if is_near_white(px[p])]


def cutout(src_path, out_path):
    img = Image.open(src_path).convert("RGB")
    seeds = edge_seeds(img)
    if not seeds:
        print("  无近白边缘种子，跳过（可能已不是白底）")
        return False
    for s in seeds:
        try:
            ImageDraw.floodfill(img, s, SENTINEL, thresh=FLOOD_THRESH)
        except Exception:
            pass
    arr = np.array(img)
    mask = (arr[:, :, 0] == 255) & (arr[:, :, 1] == 0) & (arr[:, :, 2] == 255)
    ratio = mask.mean()
    if ratio < 0.05 or ratio > 0.97:
        print("  背景占比异常 %.0f%%，疑似非白底图，跳过" % (ratio * 100))
        return False
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    # 1px 侵蚀：吃掉贴边白晕（alpha>0 且 邻接 alpha==0 的像素 → 0）
    transparent = alpha == 0
    neigh = (np.roll(transparent, 1, 0) | np.roll(transparent, -1, 0) |
             np.roll(transparent, 1, 1) | np.roll(transparent, -1, 1))
    alpha[~transparent & neigh] = 0
    rgba = np.dstack([arr, alpha])
    out = Image.fromarray(rgba, "RGBA")
    bbox = out.getbbox()
    if bbox:
        pad = 2
        bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                min(out.width, bbox[2] + pad), min(out.height, bbox[3] + pad))
        out = out.crop(bbox)
    out.save(out_path)
    print("  OK %dx%d（背景 %.0f%% 已抠）" % (out.width, out.height, ratio * 100))
    return True


def collect_targets(args):
    names = []
    if args:
        for a in args:
            if a in MACHINE_IDS:
                names += ["mh_%s_wreck" % a, "mh_%s_active" % a]
            elif a in PANEL_IDS:
                names.append("mh_%s" % a)
            else:
                raise SystemExit("未知 id: %s" % a)
    else:
        names = (["mh_%s_%s" % (m, s) for m in MACHINE_IDS for s in ("wreck", "active")]
                 + ["mh_%s" % p for p in PANEL_IDS])
    return names


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    ok = total = 0
    for name in collect_targets(args):
        src = os.path.join(SRC_DIR, name + ".jpeg")
        out = os.path.join(SRC_DIR, name + ".png")
        if not os.path.exists(src):
            print("[skip] 缺源图 %s" % name)
            continue
        total += 1
        print("[%s]" % name, end=" ", flush=True)
        if cutout(src, out):
            ok += 1
    print("抠图完成 %d/%d" % (ok, total))


if __name__ == "__main__":
    main()
