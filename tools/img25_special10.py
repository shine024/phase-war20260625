# -*- coding: utf-8 -*-
"""img25 特别批（docs/111.txt，2026-10-01 用户点名）：指定掷转正 + 对比包，单独文件夹保存。

用法:
    python tools/img25_special10.py            # 全量 10 单位
    python tools/img25_special10.py --keys cold_ak47,mod_hummer_m2

输入: .godot/unit_review/img25_staging/<key>_<roll>_attack_sheet_832.png（批 runner 已产 3 掷）
掷次决定: 优先 _special10/_decisions.json；缺的条目回落 staging/_finalize_decisions.json；
          再缺回落本脚本 BUILTIN_DECISIONS（10-01 目检定案，含 flips/批注）。
输出（全部落 staging/_special10/，绝不写 assets/）:
    <key>_attack_sheet_832.png   转正终版（flips→借格→清渍→垂直注册）
    <key>_attack_cells.png       六格 contact 条带
    <key>_attack_anim.gif        六格 8fps 预览
    <key>_zoom_final.png         500px 六格放大（朝向/开火位置目检用）
    <key>_cmp_identity.png       卡图|锚定帧|新c1|新开火格 四栏身份对比
    <key>_cmp_old_new.png        现役部署版 vs 新版 两排对比
    <key>_cmp_old_anim.gif       现役 12 帧循环（对照）
    _health.json / _report.md    机检明细 + 汇总
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from img25_finalize import (ST, cell_of, depink_erase, body_mask, largest_cc_bbox, graft_cell)  # noqa: E402
from img25_healthcheck import check_sheet  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPECIAL = os.path.join(ST, "_special10")
WORKLIST = os.path.join(ST, "_worklist.json")
FIN_DEC = os.path.join(ST, "_finalize_decisions.json")
F = 832

# 10-01 目检定案（500px 放大逐格核对：朝向以火光+炮口为首要判据）。已有 finalize 决定的单位不在此列。
BUILTIN_DECISIONS = {
    "fut_assault_mech": {
        "roll": "R1", "flips": [], "borrow": {},
        "issues": [
            "六格朝向全左正确；c2/c3 火光紧贴枪口（开火位置✓）；c4 枪口白烟衰减、c6 右后余烟，帧序完整",
            "站跪混排：c1-c3 站姿、c4-c6 跪姿（与 cold_ak47 同病、用户已接受同款，翻转无法修复）",
            "c2 腿部金色火光映衬（协调，非崩坏）",
        ],
    },
    "fut_sup_ps9": {
        "roll": "R3", "flips": [], "borrow": {},
        "issues": [
            "六格炮口全朝左；c3 大火光紧贴炮口（开火位置✓）",
            "c2 整车金黄蓄力（蓄力表达，可接受）；c2/c3 帆顶略低于待机格（压低观感，轻度）",
            "c3 右后品红烟——转正清渍已清，清后局部透明属预期",
        ],
    },
    "mod_hummer_m2": {
        "roll": "R2", "flips": [1, 2, 3, 5], "borrow": {},
        "issues": [
            "三掷全部镜像混杂（R2 4 格朝右 / R1 4 格 / R3 6 格全右），R2 为三掷最优；flips=[c2,c3,c4,c6] 翻正后六格全朝左",
            "⚠ 开火位置残留缺陷：c3 火光翻正后位于车头前部（引擎盖高度），低于车顶机枪口；R1/R3 同病无可借格。"
            "832→256 显示偏差 ~5px，『大概有开火动作』标准下可接受；不满意则单格重掷",
            "c4 曳光翻正后朝左、高度同样偏低",
            "绛红地面阴影为锚定帧自带，全格一致",
        ],
    },
}

ORDER = []          # 111.txt 原序（去重后）
PICKS = {}          # key -> roll


def load_picks():
    txt = os.path.join(ROOT, "docs", "111.txt")
    for line in open(txt, encoding="utf-8"):
        s = line.strip()
        if not s:
            continue
        assert s.endswith("R1") or s.endswith("R2") or s.endswith("R3"), "无法解析: %s" % s
        key, roll = s[:-2], s[-2:]
        if key not in PICKS:
            ORDER.append(key)
        PICKS[key] = roll


def get_decision(key):
    p = os.path.join(SPECIAL, "_decisions.json")
    if os.path.exists(p):
        d = json.load(open(p, encoding="utf-8"))
        if key in d:
            return d[key], "special"
    d = json.load(open(FIN_DEC, encoding="utf-8"))
    if key in d:
        return d[key], "finalize"
    return BUILTIN_DECISIONS[key], "builtin"


def register_vertical(im):
    bots = []
    for i in range(6):
        bb = largest_cc_bbox(body_mask(cell_of(im, i)))
        bots.append(bb[3] if bb else None)
    ref = bots[0]
    moved = []
    for i in range(1, 6):
        if bots[i] is None or ref is None:
            continue
        dy = ref - bots[i]
        if abs(dy) >= 3:
            c = cell_of(im, i)
            cleared = Image.new('RGBA', (F, F), (0, 0, 0, 0))
            cleared.paste(c, (0, dy), c)
            im.paste(cleared, ((i % 3) * F, (i // 3) * F))
            moved.append("c%d%+d" % (i + 1, dy))
    return moved


def zoom_sheet(im, path):
    Z = 500
    sheet = Image.new('RGB', (3 * Z + 40, 2 * (Z + 34) + 10), (90, 90, 90))
    d = ImageDraw.Draw(sheet)
    for i in range(6):
        c = cell_of(im, i).resize((Z, Z), Image.LANCZOS)
        x = 10 + (i % 3) * (Z + 10)
        y = 10 + (i // 3) * (Z + 34)
        sheet.paste(c, (x, y), c)
        d.text((x + 4, y + Z + 4), "c%d" % (i + 1), fill=(255, 255, 80))
    sheet.save(path)


def cmp_identity(im, card_path, anchor_path, path):
    H = 400
    parts = [("卡图", Image.open(card_path).convert('RGBA')),
             ("锚定帧", Image.open(anchor_path).convert('RGBA')),
             ("新c1", cell_of(im, 0)), ("新开火格c3", cell_of(im, 2))]
    scaled = []
    for lab, p in parts:
        w = max(1, int(p.width * H / p.height))
        scaled.append((lab, p.resize((w, H), Image.LANCZOS)))
    W = sum(p.width for _, p in scaled) + 8 * (len(scaled) + 1) + 130 * len(scaled)
    sheet = Image.new('RGB', (W, H + 44), (70, 70, 70))
    d = ImageDraw.Draw(sheet)
    x = 8
    for lab, p in scaled:
        sheet.paste(p, (x, 8), p)
        d.text((x + 2, H + 16), lab, fill=(255, 255, 80))
        x += p.width + 138
    sheet.save(path)


def gif_of(frames, path, dur=125):
    bg = Image.new('RGBA', frames[0].size, (60, 60, 60, 255))
    comp = []
    for f in frames:
        b = bg.copy()
        b.paste(f, (0, 0), f)
        comp.append(b.convert('RGB'))
    comp[0].save(path, save_all=True, append_images=comp[1:], duration=dur, loop=0)


def cmp_old_new(key, new_im, path):
    old_p = os.path.join(ROOT, "assets", "effects", "unit_anims", key, "sheet_attack.png")
    if not os.path.exists(old_p):
        return False
    o = Image.open(old_p).convert('RGBA')
    n_old = o.width // 256
    idx = [round(i * (n_old - 1) / 5) for i in range(6)]
    C = 192
    sheet = Image.new('RGB', (6 * C + 7 * 8 + 56, 2 * (C + 30) + 10), (90, 90, 90))
    d = ImageDraw.Draw(sheet)
    for row, (tag, frames) in enumerate([("旧", [o.crop((i * 256, 0, i * 256 + 256, 256)) for i in idx]),
                                         ("新", [cell_of(new_im, i).resize((256, 256), Image.LANCZOS) for i in range(6)])]):
        for j, f in enumerate(frames):
            f2 = f.resize((C, C), Image.LANCZOS)
            x = 56 + 8 + j * (C + 8)
            y = 10 + row * (C + 30)
            sheet.paste(f2, (x, y), f2)
        d.text((8, y + C // 2), tag, fill=(255, 255, 80))
    d.text((64, 2 * (C + 30) - 6), "上=现役部署版(均匀6/12帧) 下=新版6帧", fill=(200, 200, 200))
    sheet.save(path)
    return True


def process(key, roll, dec):
    src = os.path.join(ST, "%s_%s_attack_sheet_832.png" % (key, roll))
    im = Image.open(src).convert('RGBA')
    for i in dec.get("flips", []):
        x0, y0 = (i % 3) * F, (i // 3) * F
        im.paste(cell_of(im, i).transpose(Image.FLIP_LEFT_RIGHT), (x0, y0))
    for ci, dr in (dec.get("borrow") or {}).items():
        graft_cell(im, int(ci), dr, key)
    im, n_pink = depink_erase(im)
    moved = register_vertical(im)
    out_sheet = os.path.join(SPECIAL, "%s_attack_sheet_832.png" % key)
    im.save(out_sheet)

    frames = [cell_of(im, i).resize((256, 256), Image.LANCZOS) for i in range(6)]
    contact = Image.new('RGBA', (256 * 6 + 8 * 7, 256 + 16), (70, 70, 70, 255))
    for i, f in enumerate(frames):
        contact.paste(f, (8 + i * (256 + 8), 8), f)
    contact.convert('RGB').save(os.path.join(SPECIAL, "%s_attack_cells.png" % key))
    gif_of(frames, os.path.join(SPECIAL, "%s_attack_anim.gif" % key))
    zoom_sheet(im, os.path.join(SPECIAL, "%s_zoom_final.png" % key))

    wl = json.load(open(WORKLIST, encoding="utf-8"))
    card = next((e["card"] for e in wl if e.get("key") == key), None)
    anchor = os.path.join(ROOT, ".godot", "unit_review", "img25_approved", key + "_anchor_raw.png")
    if not os.path.exists(anchor):
        anchor = os.path.join(ST, key + "_anchor_raw.png")
    cmp_identity(im, os.path.join(ROOT, card), anchor,
                 os.path.join(SPECIAL, "%s_cmp_identity.png" % key))
    old_ok = cmp_old_new(key, im, os.path.join(SPECIAL, "%s_cmp_old_new.png" % key))
    if old_ok:
        o = Image.open(os.path.join(ROOT, "assets", "effects", "unit_anims", key, "sheet_attack.png")).convert('RGBA')
        old_frames = [o.crop((i * 256, 0, i * 256 + 256, 256)) for i in range(o.width // 256)]
        gif_of(old_frames, os.path.join(SPECIAL, "%s_cmp_old_anim.gif" % key))

    health = check_sheet(out_sheet)
    print("[%s] %s 转正 flips=%s 清渍%dpx 注册=%s 机检=%s" %
          (key, roll, dec.get("flips") or "无", n_pink, moved or "无", health["verdict"]))
    for iss in health["issues"]:
        print("   机检 %s: %s" % (iss["tag"], iss["msg"]))
    return health


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", default="", help="逗号分隔子集")
    load_picks()
    args = ap.parse_args()
    sub = set(args.keys.split(",")) if args.keys else None

    os.makedirs(SPECIAL, exist_ok=True)
    dec_used, healths = {}, {}
    for key in ORDER:
        if sub and key not in sub:
            continue
        roll = PICKS[key]
        d, src = get_decision(key)
        if d.get("roll") != roll:
            print("[!] %s: 111.txt 指定 %s，已有决定为 %s —— 以 111.txt 为准" % (key, roll, d["roll"]))
            d = dict(d)
            d["roll"] = roll
        dec_used[key] = d
        healths[key] = process(key, roll, d)

    json.dump(dec_used, open(os.path.join(SPECIAL, "_decisions.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    json.dump(healths, open(os.path.join(SPECIAL, "_health.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    # 回写 3 条新决定到主决定表（仅增量，保证 img25_finalize.py 口径一致）
    fin = json.load(open(FIN_DEC, encoding="utf-8"))
    add = {k: v for k, v in dec_used.items() if k not in fin}
    if add:
        fin.update(add)
        json.dump(fin, open(FIN_DEC, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("主决定表 +%d 条: %s" % (len(add), sorted(add)))
    print("完成 %d 单位 -> %s" % (len(healths), SPECIAL))


if __name__ == "__main__":
    main()
