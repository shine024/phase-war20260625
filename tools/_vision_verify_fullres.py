# -*- coding: utf-8 -*-
## 全分辨率复核版：视觉目验候选清单 → [敌图|我图|idle_f0|idle中帧|attack_f0] 360px 放大
## 用途: 缩略图上疑似"与原图不一样/忽大忽小/截断/变形"的行, 放大后逐项定性
import json, os, io, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "_anim_review", "unit_manifest_full.json")
OUTDIR = os.path.join(ROOT, "_anim_review", "vision_verify")
os.makedirs(OUTDIR, exist_ok=True)

from PIL import Image, ImageDraw, ImageFont

CELL = 360
LABEL_H = 30
GAP = 4
ROWS_PER_SHEET = 4
COLS = 5

_font = None
def font(sz=15):
    global _font
    if _font is None:
        for p in (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf"):
            if os.path.isfile(p):
                try:
                    _font = ImageFont.truetype(p, sz)
                    return _font
                except Exception:
                    pass
        _font = ImageFont.load_default()
    return _font

# (sec, id, 嫌由)  缩略图目验候选
CANDIDATES = [
    ("fam", "ww1_arm_rolls", "icon蓝光装甲车 vs anim橄榄履带"),
    ("fam", "ww2_arm_tiger", "icon虎式 vs anim小斜甲+~60%大"),
    ("fam", "mod_inf_technical", "icon迷彩MBT vs anim沙漠皮卡"),
    ("fam", "mod_arm_m1a1", "icon彩迷彩金 vs anim素灰"),
    ("fam", "mod_arm_m1a2sep", "icon金迷彩M1A2 vs anim橄榄老坦"),
    ("fam", "fut_arm_prism", "icon白蓝轮式 vs anim深色履带"),
    ("fam", "mod_arm_abrams_mk2", "icon绿苏系坦 vs anim沙M1"),
    ("fam", "fut_inf_scout_mech", "icon小侦察 vs anim巨机甲 size"),
    ("fam", "ww2_air_bomber", "iconB17四发 vs anim单发战机"),
    ("fam", "ww1_inf_mp18_x", "icon大衣兵 vs anim突击兵 size"),
    ("fam", "ww2_sup_mg42", "icon无兵 vs anim有机枪手"),
    ("fam", "ww2_inf_panzerschreck_e", "icon仅发射器 vs anim士兵"),
    ("fam", "ww2_inf_para_e", "icon灰伞兵 vs anim橄榄步兵"),
    ("fam", "cold_inf_m60", "icon沙色 vs anim绿色?"),
    ("fam", "mod_inf_marine", "icon丛林 vs anim沙漠 size"),
    ("fam", "mod_air_technical_e", "icon绿皮卡 vs anim沙漠装甲车"),
    ("fam", "mod_arm_stryker_e", "icon绿迷彩 vs anim沙色"),
    ("fam", "mod_arty_mlrs_e", "icon绿 vs anim灰蓝光"),
    ("fam", "mod_inf_delta_e", "mirror敌沙 vs 我深蓝黑"),
    ("fam", "mod_sup_m4_carbine", "mirror敌沙M4 vs 我灰兜帽"),
    ("fam", "ww2_air_dive_bomber", "mirror敌Ju87 vs 我深蓝战机"),
    ("fam", "mod_arm_abrams_e", "icon绿迷彩 vs anim素橄榄"),
    ("fam", "mod_boss_command", "icon亮 vs anim暗重制 size"),
    ("fam", "fut_air_drone", "icon四旋翼 vs anim战斗机"),
    ("fam", "fut_arm_mech_e", "icon小 vs anim占满 size"),
    ("fam", "fut_arm_hovertank_e", "icon蓝 vs anim棕灰"),
    ("fam", "fut_inf_spectre_e", "icon青绿 vs anim黑斗篷"),
    ("fam", "fut_arm_colossus_e", "icon青绿 vs anim棕灰"),
    ("fam", "cold_inf_metis", "icon小 vs anim大 size"),
    ("fam", "cold_air_strike_fighter", "icon深灰 vs anim白+蓝描边 bg"),
    ("fam", "ww2_arty_pak40", "icon黄褐 vs anim灰 size"),
    ("fam", "ww2_fort_flak", "icon蓝88炮 vs anim绿炮塔底座"),
    ("fam", "mod_fort_citadel", "icon小六边 vs anim绿城堡"),
    ("fam", "ww2_fort_bunker", "icon干净+蓝旗 vs anim泥泞重画"),
    ("fam", "fut_arty_hel30", "icon绿拖车 vs anim同款 size"),
    ("ind", "ww1_lanchest", "icon轮式装甲车 vs anim坦克"),
    ("ind", "ww1_a7v", "iconA7V方箱 vs anim斜甲坦"),
    ("ind", "ww1_mark4", "icon菱形马克IV vs anim斜甲坦"),
    ("ind", "ww1_105mm", "icon蓝灰炮 vs anim黄绿德炮"),
    ("ind", "mod_stinger", "icon白衣 vs anim绿迷彩"),
    ("ind", "mod_stryker_m2", "icon灰素 vs anim绿迷彩"),
    ("ind", "fut_space_fighter", "attack帧tan色 vs icon白蓝"),
    ("drop", "drop_mega_beam_cannon", "icon轮式车 vs anim履带MLRS"),
    ("drop", "drop_mega_particle_cannon", "icon方尖塔 vs anim机甲"),
]


def rel_path(res):
    return os.path.join(ROOT, res[len("res://"):].replace("/", os.sep)) if res and res.startswith("res://") else ""


def load_norm(path, size=CELL):
    if not path or not os.path.isfile(path):
        return None
    im = Image.open(path).convert("RGBA")
    im.thumbnail((size, size), Image.LANCZOS)
    bg = Image.new("RGBA", (size, size), (34, 40, 48, 255))
    bg.paste(im, ((size - im.width) // 2, (size - im.height) // 2), im)
    return bg


def sheet_frame(sheet_path, fs, idx, size=CELL):
    if not sheet_path or not os.path.isfile(sheet_path):
        return None
    im = Image.open(sheet_path).convert("RGBA")
    n_full = im.width // fs
    if n_full <= 0:
        return None
    idx = min(idx, n_full - 1)
    fr = im.crop((idx * fs, 0, (idx + 1) * fs, fs))
    fr.thumbnail((size, size), Image.LANCZOS)
    bg = Image.new("RGBA", (size, size), (34, 40, 48, 255))
    bg.paste(fr, ((size - fr.width) // 2, (size - fr.height) // 2), fr)
    return bg


def main():
    d = json.load(open(DUMP, encoding="utf-8"))
    enemies, players, captured, platforms = d["enemies"], d["players"], d["captured"], d["platforms"]

    # 定位每行资产（与 _vision_audit_sheets 同逻辑）
    recs = {}
    for e in enemies:
        fid = e["id"][4:] if e["id"].startswith("foe_") else e["id"]
        recs[("fam", fid)] = {
            "label": "%s %s" % (fid, e.get("name", "")),
            "icon_e": rel_path(e.get("icon", "")), "icon_p": rel_path(e.get("icon_player", "")),
            "a": e.get("anim") or {}, "boss": e.get("boss_dir"), "has_boss": e.get("boss_frames"),
            "pose": e.get("pose_dir"), "has_pose": e.get("pose_frames"),
        }
    for p in players:
        recs.setdefault(("ind", p["id"]), {
            "label": "%s %s" % (p["id"], p.get("name", "")),
            "icon_e": rel_path(p.get("icon", "")), "icon_p": "",
            "a": p.get("anim") or {}, "boss": p.get("boss_dir"), "has_boss": p.get("boss_frames"),
            "pose": p.get("pose_dir"), "has_pose": p.get("pose_frames"),
        })
    for did in sorted(c["id"] for c in captured if c["id"].startswith("drop_")):
        c = next(x for x in captured if x["id"] == did)
        recs[("drop", did)] = {
            "label": "%s %s" % (did, c.get("name", "")),
            "icon_e": rel_path(c.get("icon", "")), "icon_p": "",
            "a": c.get("anim") or {}, "boss": c.get("boss_dir"), "has_boss": c.get("boss_frames"),
            "pose": c.get("pose_dir"), "has_pose": c.get("pose_frames"),
        }

    rows = []
    for sec, cid, why in CANDIDATES:
        r = recs.get((sec, cid))
        if r is None:
            print("MISS %s|%s" % (sec, cid))
            continue
        a = r["a"]
        fs = a.get("fs", 256)
        idle_n = a.get("idle", 0)
        si = rel_path(a.get("sheet_idle", ""))
        sa = rel_path(a.get("sheet_attack", ""))
        cells = [
            load_norm(r["icon_e"]), load_norm(r["icon_p"]),
            sheet_frame(si, fs, 0),
            sheet_frame(si, fs, min(3, max(idle_n - 1, 0))) if idle_n >= 2 else None,
            sheet_frame(sa, fs, 0),
        ]
        if cells[2] is None and r["has_boss"]:
            cells[2] = load_norm(rel_path("res://assets/effects/unit_anims/%s/idle_f0.png" % (r["boss"] or cid)))
        if cells[4] is None and r["has_pose"]:
            cells[4] = load_norm(rel_path("res://assets/effects/unit_anims/%s/attack_f0.png" % (r["pose"] or cid)))
        rows.append({"sec": sec, "label": r["label"], "why": why, "cells": cells})

    W = COLS * (CELL + GAP) + GAP + 60
    n_sheets = 0
    for si0 in range(0, len(rows), ROWS_PER_SHEET):
        chunk = rows[si0:si0 + ROWS_PER_SHEET]
        H = LABEL_H * len(chunk) + GAP * (len(chunk) + 1) + (CELL + 20) * len(chunk)
        sheet = Image.new("RGB", (W, H), (14, 17, 21))
        dr = ImageDraw.Draw(sheet)
        y = GAP
        for r in chunk:
            dr.rectangle([0, y, W, y + LABEL_H], fill=(46, 30, 30))
            dr.text((8, y + 6), "[%s] %s   嫌由: %s" % (r["sec"], r["label"], r["why"]),
                    fill=(238, 200, 120), font=font(15))
            y += LABEL_H
            x = GAP
            for ci in range(COLS):
                cell = r["cells"][ci]
                if cell is not None:
                    sheet.paste(cell.convert("RGB"), (x, y))
                else:
                    dr.rectangle([x, y, x + CELL, y + CELL], fill=(24, 28, 34))
                x += CELL + GAP
            y += CELL + 2
            dr.text((GAP, y), "敌图              我图              idle首帧          idle中帧          攻击首帧",
                    fill=(110, 120, 132), font=font(12))
            y += 18
        fp = os.path.join(OUTDIR, "verify_%02d.png" % n_sheets)
        sheet.save(fp)
        print("VERIFY %s rows=%d" % (os.path.basename(fp), len(chunk)))
        n_sheets += 1
    print("DONE candidates=%d sheets=%d" % (len(rows), n_sheets))


if __name__ == "__main__":
    main()
