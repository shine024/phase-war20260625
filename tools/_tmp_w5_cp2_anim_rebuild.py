# -*- coding: utf-8 -*-
"""W5 CP-2 Wave2 动画直出（2026-09-15）：5 单位动画-新卡同步（rolls v6 范式泛化）。

源 = 各单位 enemy 卡 512（透明、朝左=sheet 约定）。idle 微颤 8 帧 / attack 火光+后坐
12 帧；枪口锚点 = 左缘 14 列实心行中位（车头/枪口朝左）。旧 sheet 备份 preW5B2。
特例：mod_arty_rq7 飞行体浮动机位（bob ±3、无后坐）；drop 两单位旧目录为死格式
（仅 attack_f0.png，loader 不认）→ 补 sheet_idle/attack + anim.json 属从无到有，
顺手清除孤儿 attack_f0。
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEPLOY = os.path.join(ROOT, "assets", "effects", "unit_anims")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")
CANVAS = 512
FOOT = int(CANVAS * 0.92)

UNITS = {
    # id: (flash_core, flash_rim, fly)
    "drop_phase_lance": ((225, 252, 255, 255), (110, 222, 255, 225), False),
    "drop_thunder_field": ((225, 252, 255, 255), (110, 222, 255, 225), False),
    "mod_arty_rq7": ((220, 250, 255, 235), (130, 225, 255, 200), True),
    "ww1_inf_mp18_x": ((255, 255, 220, 255), (255, 170, 40, 220), False),
    "vis_xeno_tripod": ((235, 225, 255, 255), (165, 120, 255, 225), False),
    # Wave3 追加（照片感批动画联动，2026-09-15）
    "mod_sup_m4_carbine": ((255, 255, 220, 255), (255, 170, 40, 220), False),
    "ww2_air_bomber": ((255, 255, 220, 255), (255, 170, 40, 220), True),
    "ww2_air_dive_bomber": ((255, 255, 220, 255), (255, 170, 40, 220), True),
    "ww2_arty_pak40": ((255, 255, 220, 255), (255, 170, 40, 220), False),
    "ww2_sup_gmc_truck": ((255, 255, 220, 255), (255, 170, 40, 220), False),
    # 追加：死格式目录单位补齐（2026-09-15，loader 不认 attack_f0 旧格式=从未有动画）
    "drop_railgun": ((225, 252, 255, 255), (110, 222, 255, 225), False),
    "drop_smg_mk2": ((255, 255, 220, 255), (255, 170, 40, 220), False),
}


def cut_transparent(png):
    im = Image.open(png).convert("RGBA")
    return im.crop(im.getbbox())


def to_canvas(sub, h_cap_frac=0.92):
    w, h = sub.size
    scale = min((CANVAS - 16) / w, (CANVAS * h_cap_frac - 8) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x0, y0 = (CANVAS - nw) // 2, FOOT - nh
    cv.paste(sub, (x0, y0), sub)
    return cv, (x0, y0, x0 + nw, y0 + nh)


def flash_star(draw, cx, cy, r, core, rim):
    import math
    pts = []
    for i in range(10):
        ang = i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(ang), cy + rr * 0.72 * math.sin(ang)))
    draw.polygon(pts, fill=rim)
    draw.polygon([(cx + r * 0.5 * math.cos(i * math.pi / 5), cy + r * 0.36 * math.sin(i * math.pi / 5))
                  for i in range(10)], fill=core)


def emit(frames, anim, unit_dir, rev_name):
    os.makedirs(unit_dir, exist_ok=True)
    os.makedirs(REV, exist_ok=True)
    fs = frames[0].size[0]
    sh = Image.new("RGBA", (fs * len(frames), fs), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sh.paste(f, (i * fs, 0))
        f.save(os.path.join(unit_dir, "f%02d.png" % i))
    for i in range(len(frames), 14):
        p = os.path.join(unit_dir, "f%02d.png" % i)
        if os.path.exists(p):
            os.unlink(p)
    sh.save(os.path.join(REV, "%s_%s_sheet.png" % (rev_name, anim)))
    sh.save(os.path.join(unit_dir, "sheet_%s.png" % anim))
    return sh


def main():
    for uid, (core, rim, fly) in UNITS.items():
        unit_dir = os.path.join(DEPLOY, uid)
        for anim in ("idle", "attack"):
            cur = os.path.join(unit_dir, "sheet_%s.png" % anim)
            if os.path.exists(cur):
                bak = os.path.join(REV, "%s_%s_sheet_preW5B2.png" % (uid, anim))
                if not os.path.exists(bak):
                    shutil.copy2(cur, bak)

        enemy_png = os.path.join(ROOT, "assets", "card_icons", "enemy", uid + ".png")
        if not os.path.exists(enemy_png):  # drop 两兄弟 enemy 侧是 vis_enemy_NNN
            num = uid.split("_")[-1]
            alt = os.path.join(ROOT, "assets", "card_icons", "enemy", "vis_enemy_" + num + ".png")
            assert os.path.exists(alt), uid
            enemy_png = alt
        base, bb = to_canvas(cut_transparent(enemy_png))
        x0, y0, x1, y1 = bb
        arr = np.asarray(base)
        solid = arr[:, :, 3] > 128
        cols = np.where(solid.any(axis=0))[0]
        left_band = solid[:, int(cols.min()):int(cols.min()) + 14]
        rows_l = np.where(left_band.any(axis=1))[0]
        gun_y = int(np.median(rows_l)) if len(rows_l) else int(np.median(np.where(solid.any(axis=1))[0]))
        gun_x = int(cols.min()) + 6

        bob = [0, -3, -2, -3, 0, -3, -2, -3] if fly else [0, -1, -2, -1, 0, -1, -2, -1]
        idle = []
        for dy in bob:
            f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            f.paste(base, (0, dy), base)
            idle.append(f)

        atk = []
        for i in range(12):
            rec = 0 if fly else (5 if 4 <= i <= 6 else (2 if 7 <= i <= 9 else 0))
            dyb = -3 if (fly and i % 2) else 0
            f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            f.paste(base, (rec, dyb), base)
            d = ImageDraw.Draw(f)
            if 4 <= i <= 6:
                r = 24 if i == 4 else (19 if i == 5 else 13)
                flash_star(d, gun_x - 8, gun_y, r, core, rim)
            elif 7 <= i <= 9:
                d.ellipse([gun_x - 26, gun_y - 6, gun_x - 2, gun_y + 6],
                          fill=(rim[0], rim[1], rim[2], 110))
            atk.append(f)

        emit(idle, "idle", unit_dir, uid)
        emit(atk, "attack", unit_dir, uid)
        meta = os.path.join(unit_dir, "anim.json")
        if not os.path.exists(meta):
            with open(meta, "w", encoding="utf-8") as f:
                json.dump({"fps": 8, "frame_size": 256, "counts": {"idle": 8, "attack": 12}}, f)
        # 孤儿死格式件清除（loader 不认）
        orphan = os.path.join(unit_dir, "attack_f0.png")
        if os.path.exists(orphan):
            os.remove(orphan)
            if os.path.exists(orphan + ".import"):
                os.remove(orphan + ".import")
        for anim in ("idle", "attack"):
            p = os.path.join(unit_dir, "sheet_%s.png" % anim)
            im = Image.open(p).convert("RGBA")
            out = im.resize((im.size[0] // 2, 256), Image.LANCZOS)
            out.save(p)
        print("[anim] %s ok (gun=(%d,%d) fly=%s)" % (uid, gun_x, gun_y, fly))
    print("ANIM REBUILD DONE")


if __name__ == "__main__":
    main()
