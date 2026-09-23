#!/usr/bin/env python3
"""B7（2026-09-14）：单位动画雪碧图内容占比归一——对齐卡图（战场比例协调）。
根因：unit_frame_anim 的尺寸补偿只管分辨率（512²→256²），不管内容占比；
雪碧图与卡图内容占比不一致 = 动画态单位在战场偏大/偏小。
实测（内容高占比 bh / 底边 y1）：c96 卡 0.74/0.92 vs 动画 0.90/0.92（偏大 22%）；
rolls 卡 0.57/0.79 vs 动画 0.25/0.93（偏小 56%）；flak 0.58/0.79 vs 0.53/0.91；garand ≈一致。

规则：以卡图 player 版内容 bbox（alpha≥10）为目标——
  s = 卡 bh / idle聚合 bh（每单位一个系数，idle/attack 共用保体型一致）；
  底边对齐：全部帧内容底边平移 (卡 y1 − idle聚合 y1)×fs；
  每帧按自身 bbox 底边中心锚定（保留 idle 微动的相对摆动）。
原图备份 _art_backup/<dir>_<sheet>-preB7-2026-09-14.png。
"""
import json
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM_ROOT = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, "_art_backup")
PREVIEW = os.path.join(ROOT, "_anim_review", "b7_previews")

UNITS = [
    ("fut_inf_c96", "fut_inf_c96.png"),
    ("ww1_arm_rolls", "vis_player_001.png"),
    ("ww2_arm_garand_para", "ww2_arm_garand_para.png"),
    ("ww2_fort_flak", "vis_player_075.png"),
]

A_T = 10  # alpha 阈值（内容判定，与脚锚扫描口径近似）


def bbox_frac(im):
    a = im.getchannel("A").point(lambda v: 255 if v >= A_T else 0)
    bb = a.getbbox()
    if not bb:
        return None
    w, h = im.size
    return bb, (bb[2] - bb[0]) / w, (bb[3] - bb[1]) / h, bb[3] / h


def cell_union_bbox(sheet, fs):
    """全部帧内容 bbox 的并集（像素，返回 (x0,y0,x1,y1,y1_frac,bh_frac) 基于 cell 域）"""
    w, h = sheet.size
    n = w // fs
    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for i in range(n):
        cell = sheet.crop((i * fs, 0, (i + 1) * fs, fs))
        bb = cell.getchannel("A").point(lambda v: 255 if v >= A_T else 0).getbbox()
        if not bb:
            continue
        x0 = min(x0, bb[0]); y0 = min(y0, bb[1])
        x1 = max(x1, bb[2]); y1 = max(y1, bb[3])
    if x1 < 0:
        return None
    return (x0, y0, x1, y1, y1 / fs, (y1 - y0) / fs)


def process_sheet(path, fs, s, delta_px):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    n = w // fs
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    max_w = 0
    for i in range(n):
        cell = im.crop((i * fs, 0, (i + 1) * fs, fs))
        bb = cell.getchannel("A").point(lambda v: 255 if v >= A_T else 0).getbbox()
        if not bb:
            continue
        crop = cell.crop(bb)
        cw, ch = crop.size
        nw = max(1, int(round(cw * s)))
        nh = max(1, int(round(ch * s)))
        max_w = max(max_w, nw)
        crop = crop.resize((nw, nh), Image.LANCZOS)
        cx = (bb[0] + bb[2]) / 2.0
        bottom = bb[3] + delta_px
        px0 = int(round(cx - nw / 2.0))
        py0 = int(round(bottom - nh))
        cell2 = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
        cell2.paste(crop, (px0, py0), crop)
        out.paste(cell2, (i * fs, 0))
    return out, max_w


def main():
    os.makedirs(BAK, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    for dir_name, card_name in UNITS:
        card_path = os.path.join(ROOT, "assets", "card_icons", "player", card_name)
        card = Image.open(card_path).convert("RGBA")
        cbb, cbw, cbh, cy1 = bbox_frac(card)

        meta = json.load(open(os.path.join(ANIM_ROOT, dir_name, "anim.json"), encoding="utf-8"))
        fs = int(meta.get("frame_size", 256))

        idle_path = os.path.join(ANIM_ROOT, dir_name, "sheet_idle.png")
        idle = Image.open(idle_path).convert("RGBA")
        ub = cell_union_bbox(idle, fs)
        if ub is None:
            print("%s: idle 无内容，跳过" % dir_name)
            continue
        _, _, _, _, uy1, ubh = ub
        s = cbh / ubh
        delta = (cy1 - uy1) * fs
        print("%s: 卡 bh=%.3f y1=%.3f | idle bh=%.3f y1=%.3f | s=%.3f delta=%.1fpx"
              % (dir_name, cbh, cy1, ubh, uy1, s, delta))

        for anim in ("idle", "attack"):
            p = os.path.join(ANIM_ROOT, dir_name, "sheet_%s.png" % anim)
            if not os.path.exists(p):
                continue
            bak = os.path.join(BAK, "%s_sheet_%s-preB7-2026-09-14.png" % (dir_name, anim))
            if not os.path.exists(bak):
                shutil.copy2(p, bak)
            out, max_w = process_sheet(p, fs, s, delta)
            out.save(p)
            flag = " ⚠溢出" if max_w > fs else ""
            print("  %s -> s应用, 帧内容最大宽 %d/%d%s" % (os.path.basename(p), max_w, fs, flag))

        # 复测 + 预览行：卡图 | idle f0 | idle f4 | attack f0（深底）
        idle2 = Image.open(idle_path).convert("RGBA")
        ub2 = cell_union_bbox(idle2, fs)
        print("  复测 idle bh=%.3f y1=%.3f（目标 %.3f/%.3f）" % (ub2[3], ub2[4], cbh, cy1))
        row_h = 200
        tiles = [card.resize((row_h, row_h))]
        for sheet_img, idx in ((idle2, 0), (idle2, 4),
                               (Image.open(os.path.join(ANIM_ROOT, dir_name, "sheet_attack.png")).convert("RGBA"), 0)):
            cell = sheet_img.crop((idx * fs, 0, (idx + 1) * fs, fs)).resize((row_h, row_h), Image.NEAREST)
            tiles.append(cell)
        pv = Image.new("RGBA", (row_h * len(tiles) + 8 * (len(tiles) - 1), row_h), (40, 44, 52, 255))
        x = 0
        for t in tiles:
            pv.alpha_composite(t, (x, 0))
            x += row_h + 8
        pv.convert("RGB").save(os.path.join(PREVIEW, "b7_%s.png" % dir_name))
    print("DONE")


if __name__ == "__main__":
    main()
