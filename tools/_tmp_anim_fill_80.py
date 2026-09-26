#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""记录4 美术补齐：80 个无分帧动画单位的程序化合成（v5 范式批量化）。

范式出处：tools/_tmp_b4_anim_prog_build_v5.py（实机验收否掉视频通道后拍板的
载具/单位通用方案——卡图直出、造型与卡图逐像素一致、零视频变形）。
- 参考=该单位当前战场静态显示的卡图（敌图朝左直接用；我图朝右镜像成朝左=游戏约定）
- idle 8 帧：车体/站姿微颤（y 抖 1-2px）
- attack 12 帧：0-3 瞄准 → 4-6 开火(枪口星形火光+后坐+抛壳) → 7-9 余焰 → 10-11 回位
- 512 master 合成 → 256 部署 sheet_idle(2048x256)/sheet_attack(3072x256) + anim.json
- 描边预烘焙由 tools/deploy_unit_anims.py --bake-existing 统一收口（本脚本不做）
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "card_icons")
DEPLOY = os.path.join(ROOT, "assets", "effects", "unit_anims")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")
CANVAS = 512
FOOT = int(CANVAS * 0.92)

# ── 80 个待补单位（终版口径 ANIMFINAL uncovered - cold_boss_mig）──
UNITS = ["cold_ak47","cold_bradley","cold_chieftain","cold_f4","cold_inf_m60","cold_leo1","cold_m1","cold_m14","cold_m60t","cold_mig21","cold_rpg","cold_rpk","cold_sam7","cold_t62","drop_overclock_matrix","fut_aa_hover","fut_arm_omega","fut_assault_mech","fut_attack_drone","fut_heavy_trooper","fut_howitzer","fut_nano_drone","fut_shield","fut_space_fighter","fut_stealth_bomber","fut_stormcore","fut_swarm","guardian_cold_thunder","guardian_future_omega","guardian_modern_stealth","guardian_ww1_ironclad","guardian_ww2_blitzkrieg","mod_ah1","mod_ah64","mod_challenger2","mod_hummer_m2","mod_hummer_tow","mod_javelin","mod_leo2a6","mod_m1a2","mod_ranger","mod_stinger","mod_stryker_m2","mod_stryker_mgs","mod_t90","mod_uh60","platform_cold_carrier","platform_cold_ifv","platform_cold_light","platform_cold_radar","platform_cold_scout","platform_future_radar","platform_modern_radar","platform_modern_stealth","platform_ww1_fort","platform_ww1_radar","platform_ww2_medium","ww1_105mm","ww1_37mm","ww1_a7v","ww1_enfield","ww1_flame","ww1_lanchest","ww1_m76","ww1_mark4","ww1_mg08","ww1_saint","ww1_vickers","ww2_air_me262","ww2_air_meteor_e","ww2_arm_tiger","ww2_browning","ww2_is2","ww2_m120","ww2_mp40","ww2_ppsh","ww2_pz3","ww2_pz4","ww2_t34_76","ww2_t34_85"]

# 特例参考：自身无专属卡图、战场显示本就是同族回退图的单位 → 代理单位 id
# （走与普通单位相同的 vis 映射解析；代理图与该单位当前战场回退显示同族同向）
REF_PROXY = {
    "cold_inf_m60": "cold_ak47",
    "drop_overclock_matrix": "fut_attack_drone",
    "ww2_arm_tiger": "platform_ww2_heavy",
}

import re
_vis_map = {}
_src = open(os.path.join(ROOT, "scripts", "ui_asset_loader.gd"), encoding="utf-8").read()
for _m in re.finditer(r'"([a-z0-9_]+)":\s*"(vis_player_\d+)"', _src):
    _vis_map[_m.group(1)] = _m.group(2)
_foe2plat = {}
_src2 = open(os.path.join(ROOT, "data", "enemy_unit_manifest.gd"), encoding="utf-8").read()
for _m in re.finditer(r'"([a-z0-9_]+)":\s*"(platform_[a-z0-9_]+)"', _src2):
    _foe2plat[_m.group(1)] = _m.group(2)


def find_ref(uid):
    """返回 (路径, 需镜像)。enemy/=朝左直接用；player|root/=朝右镜像；vis_map 同理。"""
    uid = REF_PROXY.get(uid, uid)
    cands = [
        (os.path.join(ICONS, "enemy", uid + ".png"), False),
        (os.path.join(ICONS, "player", uid + ".png"), True),
        (os.path.join(ICONS, uid + ".png"), True),
    ]
    vid = _vis_map.get(uid)
    if not vid and uid in _foe2plat:
        vid = _vis_map.get(_foe2plat[uid])
    if vid:
        cands.append((os.path.join(ICONS, "player", vid + ".png"), True))
        cands.append((os.path.join(ICONS, "enemy", vid + ".png"), False))
    for p, flip in cands:
        if os.path.exists(p):
            return p, flip
    return None, False


def tight_crop_rgba(png):
    im = Image.open(png).convert("RGBA")
    a = im.getchannel("A")
    bb = a.getbbox()
    return im.crop(bb) if bb else im


def to_canvas(sub, h_cap_frac=0.92):
    w, h = sub.size
    scale = min((CANVAS - 16) / w, (CANVAS * h_cap_frac - 8) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x0, y0 = (CANVAS - nw) // 2, FOOT - nh
    cv.paste(sub, (x0, y0), sub)
    return cv, (x0, y0, x0 + nw, y0 + nh)


def flash_star(draw, cx, cy, r, core=(255, 255, 220, 255), rim=(255, 170, 40, 220)):
    import math
    pts_o, pts_c = [], []
    for i in range(10):
        ang = i * math.pi / 5 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.45
        x, y = cx + rr * math.cos(ang), cy + rr * 0.72 * math.sin(ang)
        (pts_c if i % 2 == 0 else pts_o).append((x, y))
    draw.polygon(pts_c, fill=rim)
    draw.polygon([(cx + rr * 0.5 * math.cos(i * math.pi / 5), cy + rr * 0.36 * math.sin(i * math.pi / 5))
                  for i in range(10)], fill=core)


def build_sheets(base, bb, out_dir, rev_name):
    x0, y0, x1, y1 = bb
    arr = np.asarray(base)
    solid = arr[:, :, 3] > 128
    cols = np.where(solid.any(axis=0))[0]
    band = np.where(solid.sum(axis=1) > max(3, solid.any(axis=1).sum() * 0.02))[0]
    gun_y = int(np.median(band))
    gun_x = int(cols.min()) + 6

    bob = [0, -1, -2, -1, 0, -1, -2, -1]
    idle = []
    for dy in bob:
        f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        f.paste(base, (0, dy), base)
        idle.append(f)

    atk = []
    for i in range(12):
        rec = 5 if 4 <= i <= 6 else (2 if 7 <= i <= 9 else 0)
        f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        f.paste(base, (rec, 0), base)
        d = ImageDraw.Draw(f)
        if 4 <= i <= 6:
            r = 26 if i == 4 else (20 if i == 5 else 14)
            flash_star(d, gun_x - 10, gun_y, r)
            d.ellipse([gun_x - 52, gun_y - 5, gun_x - 10, gun_y + 5], fill=(255, 200, 80, 190))
            d.ellipse([x1 - 60, gun_y + 8, x1 - 52, gun_y + 16], fill=(230, 160, 60, 220))
        elif 7 <= i <= 9:
            d.ellipse([gun_x - 34, gun_y - 7, gun_x - 6, gun_y + 7], fill=(255, 180, 70, 110))
        atk.append(f)

    os.makedirs(out_dir, exist_ok=True)
    for anim, frames, want in (("idle", idle, 8), ("attack", atk, 12)):
        assert len(frames) == want
        fs = frames[0].size[0]
        sh = Image.new("RGBA", (fs * len(frames), fs), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sh.paste(fr, (i * fs, 0))
        half = sh.resize((sh.size[0] // 2, 256), Image.LANCZOS)
        half.save(os.path.join(out_dir, "sheet_%s.png" % anim))
        sh.save(os.path.join(REV, "%s_%s_sheet_512.png" % (rev_name, anim)))
    import json
    meta = {"fps": 8, "frame_size": 256, "counts": {"idle": 8, "attack": 12}}
    json.dump(meta, open(os.path.join(out_dir, "anim.json"), "w", encoding="utf-8"))


def main():
    os.makedirs(REV, exist_ok=True)
    ok, skip = [], []
    for uid in UNITS:
        out_dir = os.path.join(DEPLOY, uid)
        if os.path.exists(os.path.join(out_dir, "anim.json")):
            skip.append(uid)
            continue
        ref, flip = find_ref(uid)
        if ref is None:
            skip.append(uid + " (no-ref)")
            continue
        sub = tight_crop_rgba(ref)
        if flip:
            sub = sub.transpose(Image.FLIP_LEFT_RIGHT)
        base, bb = to_canvas(sub)
        build_sheets(base, bb, out_dir, uid)
        ok.append(uid)
    print("FILL done=%d skipped=%d" % (len(ok), len(skip)))
    if skip:
        print("FILL skipped_list=", skip)


if __name__ == "__main__":
    main()
