# -*- coding: utf-8 -*-
"""MK7 诊断：attack vs idle(并集) 剪影差分叠加图。
灰=attack 主体，红=离体物(extra)，黄=亮核(V>150&S>40 CC>=40px)。
每单位一行 12 帧 + 行首 idle 参照。输出 triage_diff_<n>.png 并打印亮核坐标报表。
用法: python tools/_mk7_diag.py [unit ...]   # 缺省=全候选
"""
import io
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")

_src = open(os.path.join(ROOT, "tools", "_mk6_mech_batch.py"), encoding="utf-8").read()
_src = _src.replace('if __name__ == "__main__":\n    main()', '')
_src = '\n'.join(l for l in _src.splitlines()
                 if not l.strip().startswith('sys.stdout = io.TextIOWrapper'))
mk = types.ModuleType('mk')
mk.__file__ = os.path.join(ROOT, "tools", "_mk6_mech_batch.py")
exec(compile(_src, '_mk6_mech_batch.py', 'exec'), mk.__dict__)

ALL = [
    "cold_arm_t55", "cold_t72", "cold_inf_btr60", "cold_sup_bmp1_x",
    "cold_sup_zsu23", "ww1_arm_rolls", "ww2_arty_hummel", "ww2_fort_flak",
    "mod_arm_himars", "guardian_ww1_ironclad",
    "drop_smg_mk2", "drop_thunder_field", "ww1_boss_av7", "ww2_arty_m81",
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen", "fe_frontier_mixed_company",
    "fe_quantum_mobile_base", "fut_nano_drone", "mod_stryker_m2", "ww2_inf_bazooka",
    "cold_bradley", "cold_arm_btr_e", "fut_air_stealth_bomber", "fut_colossus",
    "mod_air_multirole", "mod_stryker", "ww1_lanchest", "ww1_mark4", "ww1_105mm",
    "fut_space_fighter",
    "ww1_inf_cavalry", "ww2_air_dive_bomber",
]


def dilate(mask, r):
    m = mask.copy()
    for _ in range(r):
        m2 = m.copy()
        m2[1:, :] |= m[:-1, :]; m2[:-1, :] |= m[1:, :]
        m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
        m = m2
    return m


def erode(mask, r):
    return ~dilate(~mask, r)


def hsv_of(arr):
    return np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert('HSV')).astype(int)


def ccs_of(mask):
    H, W = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    for y0 in range(H):
        for x0 in range(W):
            if mask[y0, x0] and not seen[y0, x0]:
                stack = [(y0, x0)]; seen[y0, x0] = True; pix = []
                while stack:
                    y, x = stack.pop(); pix.append((y, x))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                out.append(pix)
    return out


def diag(unit):
    _, _, idle = mk.load_frames(unit, "idle")
    sky_union = np.zeros((256, 256), dtype=bool)
    for f in idle:
        sky_union |= np.asarray(f)[:, :, 3] > 40
    sky = erode(~sky_union, 3)
    _, _, atk = mk.load_frames(unit, "attack")
    panels = []
    report = []
    for i, fr in enumerate(atk):
        arr = np.asarray(fr)
        extra = (arr[:, :, 3] > 40) & sky
        panel = Image.new("RGB", (256, 256), (30, 32, 38))
        solid = np.zeros((256, 256, 4), dtype=np.uint8)
        solid[:, :, 0] = 150; solid[:, :, 1] = 150; solid[:, :, 2] = 158
        solid[:, :, 3] = arr[:, :, 3]
        sil = Image.fromarray(solid)
        panel.paste((150, 150, 158), (0, 0), sil)
        d = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        if extra.any():
            rm = np.zeros((256, 256, 4), dtype=np.uint8)
            rm[extra] = (255, 60, 60, 200)
            d = Image.alpha_composite(d, Image.fromarray(rm))
            hsv = hsv_of(arr)
            bright = (hsv[:, :, 2] > 150) & (hsv[:, :, 1] > 40) & extra
            for pix in ccs_of(bright):
                if len(pix) < 40:
                    continue
                ys = [p[0] for p in pix]; xs = [p[1] for p in pix]
                report.append("    f%-2d 亮核 a=%-5d bbox=(%d,%d)-(%d,%d) c=(%.0f,%.0f)" % (
                    i, len(pix), min(xs), min(ys), max(xs), max(ys),
                    sum(xs) / len(xs), sum(ys) / len(ys)))
                ym = np.zeros((256, 256, 4), dtype=np.uint8)
                ym[bright] = (255, 230, 40, 255)
                d = Image.alpha_composite(d, Image.fromarray(ym))
        panel.paste(Image.new("RGB", (256, 256), (0, 0, 0)), (0, 0), d)
        panels.append(panel.resize((96, 96), Image.LANCZOS))
    ref = idle[0].resize((96, 96), Image.LANCZOS)
    return ref, panels, report


def main():
    units = sys.argv[1:] or ALL
    rows = []
    for u in units:
        try:
            ref, panels, report = diag(u)
        except Exception as e:
            print("[err] %s %s" % (u, e))
            continue
        rows.append((u, ref, panels))
        if report:
            print("── %s" % u)
            for l in report:
                print(l)
    per = 10
    for gi in range(0, len(rows), per):
        chunk = rows[gi:gi + per]
        g = Image.new("RGB", (97 * 13, len(chunk) * 116), (20, 22, 26))
        dr = ImageDraw.Draw(g)
        for ri, (u, ref, panels) in enumerate(chunk):
            y = ri * 116
            g.paste(ref.resize((96, 96)), (0, y + 16))
            dr.rectangle((0, y + 16, 95, y + 111), outline=(90, 130, 200))
            for ci, p in enumerate(panels[:12]):
                x = (ci + 1) * 97
                g.paste(p, (x, y + 16))
            dr.text((3, y + 2), u, fill=(255, 220, 120))
        out = os.path.join(STG, "triage_diff_%d.png" % (gi // per))
        g.save(out)
        print("[grid] %s" % os.path.basename(out))


if __name__ == "__main__":
    main()
