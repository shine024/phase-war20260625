# -*- coding: utf-8 -*-
## 视觉审计图版生成器：每个单位一行 = [敌图 | 我图 | idle_f0 | idle_f3 | attack_f0]
## 机械层：镜像一致性（敌图水平翻转 vs 我图 逐像素比对）+ probe 四类疑似
## 视觉层：图版供视觉模型逐版目验（与原图不一样/忽大忽小/截断/变形）
## 输出: _anim_review/vision_sheets/sheet_*.png + _anim_review/vision_audit_data.json
import json, os, io, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _card_anim_asset_probe as probe
from PIL import Image, ImageDraw, ImageFont

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "_anim_review", "unit_manifest_full.json")
OUTDIR = os.path.join(ROOT, "_anim_review", "vision_sheets")
os.makedirs(OUTDIR, exist_ok=True)

CELL = 224          # 单元格边宽
LABEL_H = 26
ROWS_PER_SHEET = 10
COLS = 5
GAP = 4

_font = None
def font(sz=13):
    global _font
    if _font is None:
        for p in (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf", r"C:\Windows\Fonts\consola.ttf"):
            if os.path.isfile(p):
                try:
                    _font = ImageFont.truetype(p, sz)
                    return _font
                except Exception:
                    pass
        _font = ImageFont.load_default()
    return _font


def rel_path(res):
    return os.path.join(ROOT, res[len("res://"):].replace("/", os.sep)) if res and res.startswith("res://") else ""


def load_norm(path, size=CELL):
    """载入并归一到 CELL 内 contain（透明底加深色棋盘便于目验抠图残留）"""
    if not path or not os.path.isfile(path):
        return None
    im = Image.open(path).convert("RGBA")
    im.thumbnail((size, size), Image.LANCZOS)
    bg = Image.new("RGBA", (size, size), (34, 40, 48, 255))
    bg.paste(im, ((size - im.width) // 2, (size - im.height) // 2), im)
    return bg


def sheet_frame(sheet_path, fs, idx, size=CELL):
    """从雪碧图切第 idx 帧"""
    if not sheet_path or not os.path.isfile(sheet_path):
        return None
    im = Image.open(sheet_path).convert("RGBA")
    n_full = im.width // fs
    if idx >= n_full:
        idx = n_full - 1
    if n_full <= 0:
        return None
    fr = im.crop((idx * fs, 0, (idx + 1) * fs, fs))
    fr.thumbnail((size, size), Image.LANCZOS)
    bg = Image.new("RGBA", (size, size), (34, 40, 48, 255))
    bg.paste(fr, ((size - fr.width) // 2, (size - fr.height) // 2), fr)
    return bg


def mirror_diff(p_enemy, p_player):
    """镜像一致性：敌图水平翻转 vs 我图，返回差异像素占比(0..1)；任一缺失返回 None"""
    if not p_enemy or not p_player or not os.path.isfile(p_enemy) or not os.path.isfile(p_player):
        return None
    a = Image.open(p_enemy).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    b = Image.open(p_player).convert("RGBA")
    if a.size != b.size:
        b = b.resize(a.size, Image.NEAREST)
    da, db = a.tobytes(), b.tobytes()
    n = len(da) // 4
    diff = 0
    step = 4
    total = 0
    for i in range(0, n, 2):  # 隔像素抽样提速
        o = i * step
        if abs(da[o] - db[o]) > 24 or abs(da[o + 1] - db[o + 1]) > 24 or abs(da[o + 2] - db[o + 2]) > 24:
            diff += 1
        total += 1
    return diff / max(total, 1)


def main():
    d = json.load(open(DUMP, encoding="utf-8"))
    enemies, players, captured, platforms = d["enemies"], d["players"], d["captured"], d["platforms"]

    icon2fam = {}
    for e in enemies:
        ip = e.get("icon_player") or ""
        if ip and ip not in icon2fam:
            icon2fam[ip] = e["id"][4:] if e["id"].startswith("foe_") else e["id"]
    fam_players = {}
    for p in players:
        f = icon2fam.get(p.get("icon") or "")
        if f:
            fam_players.setdefault(f, []).append(p)
    captured_ids = {c["id"] for c in captured}

    rows = []  # 每行: {label, sub, cells[5], suspects, mirror}
    for e in enemies:
        fid = e["id"][4:] if e["id"].startswith("foe_") else e["id"]
        pe = rel_path(e.get("icon", ""))
        pp = rel_path(e.get("icon_player", ""))
        mir = mirror_diff(pe, pp)
        a = e.get("anim") or {}
        si = rel_path(a.get("sheet_idle", ""))
        sa = rel_path(a.get("sheet_attack", ""))
        fs = a.get("fs", 256)
        idle_n = a.get("idle", 0)
        cells = [load_norm(pe), load_norm(pp),
                 sheet_frame(si, fs, 0),
                 sheet_frame(si, fs, min(3, max(idle_n - 1, 0))) if idle_n >= 2 else None,
                 sheet_frame(sa, fs, 0)]
        if cells[2] is None and e.get("boss_frames"):
            d0 = rel_path("res://assets/effects/unit_anims/%s/idle_f0.png" % e.get("boss_dir", fid))
            cells[2] = load_norm(d0)
        if cells[4] is None and e.get("pose_frames"):
            d0 = rel_path("res://assets/effects/unit_anims/%s/attack_f0.png" % e.get("pose_dir", fid))
            cells[4] = load_norm(d0)
        # probe 疑似（敌/我两侧并集，face 只看我方）
        def anim_dict(flip):
            if not a:
                return None
            return dict(a, sheet_idle=("../" + a["sheet_idle"][len("res://"):]) if a.get("sheet_idle") else "",
                        sheet_attack=("../" + a["sheet_attack"][len("res://"):]) if a.get("sheet_attack") else "",
                        _flip=flip)
        boss = {"dir": e["boss_dir"]} if e.get("boss_frames") else None
        sus = set()
        try:
            s_e, _ = probe.analyze_card("../" + pe[len(ROOT) + 1:].replace(os.sep, "/") if pe else None,
                                        anim_dict(False), boss, None)
            s_p, _ = probe.analyze_card("../" + pp[len(ROOT) + 1:].replace(os.sep, "/") if pp else None,
                                        anim_dict(True), boss, None)
            sus = ({x for x in s_e if x != "face"} | set(s_p)) - {"diff", "probe_err"}
        except Exception:
            pass
        sus_txt = sorted(sus)
        if mir is not None and mir > 0.02:
            sus_txt.append("mirror")
        rows.append({
            "sec": "fam", "id": fid, "label": "%s %s" % (fid, e.get("name", "")),
            "sub": "seg%s 掉%s%.0f%%%s" % (e.get("seg", "?"), e.get("drop_card_id", ""), e.get("drop", 0) * 100,
                                            " 同名卡✓" if fid in captured_ids else ""),
            "cells": cells, "sus": sus_txt, "mirror": mir,
            "joined": [p["id"] for p in fam_players.get(fid, [])],
        })

    # 独立我方卡
    matched = {q["id"] for q in players if (q.get("icon") or "") in icon2fam}
    for p in players:
        if p["id"] in matched:
            continue
        pi = rel_path(p.get("icon", ""))
        a = p.get("anim") or {}
        cells = [load_norm(pi), None,
                 sheet_frame(rel_path(a.get("sheet_idle", "")), a.get("fs", 256), 0),
                 None,
                 sheet_frame(rel_path(a.get("sheet_attack", "")), a.get("fs", 256), 0)]
        if cells[2] is None and p.get("boss_frames"):
            cells[2] = load_norm(rel_path("res://assets/effects/unit_anims/%s/idle_f0.png" % p.get("boss_dir", p["id"])))
        rows.append({"sec": "ind", "id": p["id"], "label": "%s %s" % (p["id"], p.get("name", "")),
                     "sub": "独立我方卡", "cells": cells, "sus": [], "mirror": None, "joined": []})

    # 特色掉落卡
    cap_recs = {c["id"]: c for c in captured}
    for did in sorted(c for c in cap_recs if c.startswith("drop_")):
        c = cap_recs[did]
        pi = rel_path(c.get("icon", ""))
        a = c.get("anim") or {}
        cells = [load_norm(pi), None,
                 sheet_frame(rel_path(a.get("sheet_idle", "")), a.get("fs", 256), 0),
                 None,
                 sheet_frame(rel_path(a.get("sheet_attack", "")), a.get("fs", 256), 0)]
        rows.append({"sec": "drop", "id": did, "label": "%s %s" % (did, c.get("name", "")),
                     "sub": "特色掉落卡", "cells": cells, "sus": [], "mirror": None, "joined": []})

    # 相位师平台
    for p in platforms:
        a = p.get("anim") or {}
        idle_n = a.get("idle", 0)
        si = rel_path(a.get("sheet_idle", ""))
        cells = [None, None,
                 sheet_frame(si, a.get("fs", 256), 0),
                 sheet_frame(si, a.get("fs", 256), min(3, max(idle_n - 1, 0))) if idle_n >= 2 else None,
                 sheet_frame(rel_path(a.get("sheet_attack", "")), a.get("fs", 256), 0)]
        rows.append({"sec": "plat", "id": p["id"], "label": "%s %s" % (p["id"], p.get("name", "")),
                     "sub": "相位师平台", "cells": cells, "sus": [], "mirror": None, "joined": []})

    # ── 出图版 ──
    W = COLS * (CELL + GAP) + GAP + 320
    n_sheets = 0
    for si0 in range(0, len(rows), ROWS_PER_SHEET):
        chunk = rows[si0:si0 + ROWS_PER_SHEET]
        H = LABEL_H * len(chunk) + GAP * (len(chunk) + 1) + (CELL + 8) * len(chunk)
        sheet = Image.new("RGB", (W, H), (16, 20, 24))
        dr = ImageDraw.Draw(sheet)
        y = GAP
        for r in chunk:
            bad = bool(r["sus"])
            bar = (60, 26, 26) if bad else (26, 32, 40)
            dr.rectangle([0, y, W, y + LABEL_H], fill=bar)
            dr.text((8, y + 5), r["label"], fill=(230, 236, 244), font=font(14))
            dr.text((330, y + 6), r["sub"] + ("  ⚠" + ",".join(r["sus"]) if bad else ""),
                    fill=(224, 169, 63) if bad else (139, 152, 168), font=font(12))
            y += LABEL_H
            x = GAP
            for ci in range(COLS):
                cell = r["cells"][ci]
                if cell is not None:
                    sheet.paste(cell.convert("RGB"), (x, y))
                else:
                    dr.rectangle([x, y, x + CELL, y + CELL], fill=(24, 28, 34))
                    dr.text((x + 70, y + CELL // 2), "—", fill=(80, 90, 100), font=font(16))
                if bad:
                    dr.rectangle([x, y, x + CELL, y + CELL], outline=(224, 92, 92), width=2)
                x += CELL + GAP
            # 列标注行
            y += CELL + 2
            dr.text((GAP, y), "敌图            我图            idle首帧        idle中帧        攻击首帧",
                    fill=(100, 112, 126), font=font(11))
            y += 14
        fp = os.path.join(OUTDIR, "sheet_%02d.png" % n_sheets)
        sheet.save(fp)
        print("SHEET %s rows=%d" % (os.path.basename(fp), len(chunk)))
        n_sheets += 1

    # 数据存档
    out = [{"sec": r["sec"], "id": r["id"], "sus": r["sus"],
            "mirror": round(r["mirror"], 4) if r["mirror"] is not None else None,
            "joined": r["joined"]} for r in rows]
    with open(os.path.join(ROOT, "_anim_review", "vision_audit_data.json"), "w", encoding="utf-8") as f:
        json.dump({"rows": out, "sheets": n_sheets}, f, ensure_ascii=False, indent=1)
    mir_bad = [r["id"] for r in rows if r.get("mirror") is not None and r["mirror"] > 0.02]
    print("DONE rows=%d sheets=%d mirror_mismatch>2%%: %d %s" % (
        len(rows), n_sheets, len(mir_bad), ",".join(mir_bad[:12])))


if __name__ == "__main__":
    main()
