# -*- coding: utf-8 -*-
"""MK7 分诊图：剩余标注单位的 attack 卷诊断行（idle f0 + attack 全帧缩略）。
输出 .godot/unit_review/mk6_staging/triage_<n>.png，每行一个单位，行首条写单位名。
用法: python tools/_mk7_triage.py
"""
import io
import json
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")
os.makedirs(STG, exist_ok=True)

_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)

TH = 96  # 缩略边长

UNITS = [
    # M 类：开火位置
    "drop_smg_mk2", "drop_thunder_field", "cold_arm_t55", "cold_t72",
    "cold_inf_btr60", "cold_sup_bmp1_x", "cold_sup_zsu23", "ww1_arm_rolls",
    "ww1_arty_m81", "ww1_boss_av7", "ww1_inf_cavalry", "ww2_air_dive_bomber",
    "ww2_arty_hummel", "ww2_arty_m81", "ww2_fort_flak", "ww2_inf_bazooka",
    "ww2_inf_para_e", "ww2_inf_garand",
    # M 类：fe/杂
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen", "fe_frontier_mixed_company",
    "fe_quantum_mobile_base", "fut_nano_drone", "mod_stryker_m2",
    # D 类：diff/clip
    "drop_phase_lance", "cold_bradley", "cold_arm_btr_e", "fut_air_stealth_bomber",
    "fut_colossus", "mod_air_multirole", "mod_stryker", "mod_arm_himars",
    "ww1_lanchest", "ww1_mark4", "ww1_105mm", "fut_space_fighter",
    "guardian_ww1_ironclad",
    # R/C 类：重生成/卡图对照
    "ww1_a7v", "mod_arty_m270", "mod_ranger", "fut_air_drone",
]


def opaque_pct(sh):
    a = sh.getchannel("A")
    h = a.histogram()
    return 100.0 * sum(h[251:]) / (sh.width * sh.height)


def row(unit):
    ad = os.path.join(UA, unit)
    if not os.path.isdir(ad):
        return None
    cells = []
    note = []
    idir = os.path.join(ad, "sheet_idle.png")
    if os.path.exists(idir):
        try:
            _, _, idl = mk.load_frames(unit, "idle")
            cells.append(idl[0].resize((TH, TH), Image.LANCZOS))
        except Exception as e:
            note.append("idle:%s" % e)
    ap = os.path.join(ad, "sheet_attack.png")
    if os.path.exists(ap):
        sh = Image.open(ap).convert("RGBA")
        op = opaque_pct(sh)
        if op > 90:
            note.append("OPAQUE%.0f%%" % op)
        try:
            _, _, atk = mk.load_frames(unit, "attack")
            for f in atk:
                cells.append(f.resize((TH, TH), Image.LANCZOS))
        except Exception as e:
            note.append("atk:%s" % e)
    if not cells:
        note.append("no sheets")
        cells = [Image.new("RGBA", (TH, TH), (60, 0, 0, 255))]
    return cells, ";".join(note)


def main():
    rows = []
    for u in UNITS:
        r = row(u)
        if r is None:
            print("[miss] %s" % u)
            continue
        rows.append((u,) + r)
    per = 12  # 每图行数
    ncell = 16  # 每行最多格
    for gi in range(0, len(rows), per):
        chunk = rows[gi:gi + per]
        H = len(chunk) * (TH + 18)
        W = (ncell + 1) * TH
        g = Image.new("RGB", (W, H), (38, 42, 50))
        d = ImageDraw.Draw(g)
        for ri, (u, cells, note) in enumerate(chunk):
            y = ri * (TH + 18)
            d.text((4, y + 2), "%s %s" % (u, ("«" + note + "»") if note else ""),
                   fill=(255, 220, 120))
            # 第 0 格 = idle f0（深蓝底区别）
            g.paste(cells[0].resize((TH, TH)), (0, y + 16), cells[0].resize((TH, TH)))
            d.rectangle((0, y + 16, TH - 1, y + 16 + TH - 1), outline=(90, 130, 200))
            for ci, f in enumerate(cells[1:ncell + 1]):
                x = (ci + 1) * TH
                g.paste(f, (x, y + 16), f)
                d.rectangle((x, y + 16, x + TH - 1, y + 16 + TH - 1), outline=(70, 70, 76))
        out = os.path.join(STG, "triage_%d.png" % (gi // per))
        g.save(out)
        print("[grid] %s rows=%d" % (os.path.basename(out), len(chunk)))


if __name__ == "__main__":
    main()
