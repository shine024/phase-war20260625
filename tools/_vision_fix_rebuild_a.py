# -*- coding: utf-8 -*-
## 视觉审计修复 A 组：卡图直出重建（动画内容与卡图不一致的单位）
## 范式 = _tmp_anim_fill_80 v5（卡图抠主体→512 画布→idle 微颤 8 帧/attack 后坐+火光 n 帧→256 部署）
## 增强：air 类居中悬浮；attack 帧数自适应原 counts；部署前全量备份；md5 落账
## 安全（14:27 误跑教训）：仅动显式清单，绝不 glob；每文件先备份再写。
import json, os, sys, io, hashlib, shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")
BAK = os.path.join(ROOT, ".godot", "art_backup_visionfix_20261003")
CANVAS = 512
FOOT = int(CANVAS * 0.92)
FRAME = 256

import importlib.util
spec = importlib.util.spec_from_file_location("dua", os.path.join(ROOT, "tools", "deploy_unit_anims.py"))
dua = importlib.util.module_from_spec(spec)
sys.modules["dua"] = dua
spec.loader.exec_module(dua)  # v6.37 后 import 安全（__main__ 保护）

# (key, 卡图res路径, idle_n, attack_n, air, flip)  counts=误跑恢复后的现役值
# flip=True: 源图朝右(player 独立卡/drop 卡), 翻转成 sheet 真身朝左
CASES = [
    ("mod_arm_m1a2sep",      "res://assets/card_icons/enemy/vis_enemy_023.png", 8, 12, False, False),
    ("ww2_air_bomber",       "res://assets/card_icons/enemy/ww2_air_bomber.png", 8, 10, True, False),
    ("ww1_arm_rolls",        "res://assets/card_icons/enemy/vis_enemy_001.png", 8, 12, False, False),
    ("ww1_lanchest",         "res://assets/card_icons/player/ww1_lanchest.png", 8, 12, False, True),
    ("ww1_a7v",              "res://assets/card_icons/player/ww1_a7v.png", 8, 12, False, True),
    ("ww1_mark4",            "res://assets/card_icons/player/ww1_mark4.png", 8, 6, False, True),
    ("ww2_arm_tiger",        "res://assets/card_icons/enemy/vis_enemy_008.png", 8, 10, False, False),
    ("cold_inf_m60",         "res://assets/card_icons/enemy/vis_enemy_051.png", 8, 10, False, False),
    ("ww2_fort_bunker",      "res://assets/card_icons/enemy/vis_enemy_074.png", 8, 12, False, False),
    ("mod_fort_citadel",     "res://assets/card_icons/enemy/vis_enemy_078.png", 8, 12, False, False),
    ("ww2_fort_flak",        "res://assets/card_icons/enemy/vis_enemy_075.png", 8, 12, False, False),
    ("mod_stinger",          "res://assets/card_icons/player/mod_stinger.png", 8, 10, False, True),
    ("fut_inf_scout_mech",   "res://assets/card_icons/enemy/vis_enemy_024.png", 8, 12, False, False),
    ("ww1_inf_mp18_x",       "res://assets/card_icons/enemy/ww1_inf_mp18_x.png", 8, 12, False, False),
    # 共享 key → 新建独立目录（解析链第一位自动接线，宿主动画不动）
    ("fut_air_drone",        "res://assets/card_icons/enemy/vis_enemy_065.png", 8, 10, True, False),
    ("drop_mega_beam_cannon",    "res://assets/card_icons/player/vis_player_064.png", 8, 12, False, True),
    ("drop_mega_particle_cannon","res://assets/card_icons/player/vis_player_071.png", 5, 12, False, True),
    ("mod_air_technical_e",  "res://assets/card_icons/enemy/vis_enemy_058.png", 8, 12, False, False),
    ("ww2_sup_mg42",         "res://assets/card_icons/enemy/vis_enemy_045.png", 8, 8, False, False),
    ("mod_inf_marine",       "res://assets/card_icons/enemy/vis_enemy_057.png", 8, 12, False, False),
    ("mod_boss_command",     "res://assets/card_icons/enemy/vis_enemy_064.png", 8, 12, False, False),
    ("fut_arm_mech_e",       "res://assets/card_icons/enemy/vis_enemy_067.png", 8, 10, False, False),
    # D 组卡图重掷后随动: 新敌图=朝左源, flip=False（卡图换血见 _vision_fix_redraw_d.py）
    # 第7元素=枪口覆盖(gx,gy)画布坐标: 车体前脸比炮管更凸出时（皮卡/棱镜/abrams_mk2）最左带中位会打在保险杠/首下, 须目视定点
    ("mod_inf_technical",    "res://assets/card_icons/enemy/vis_enemy_018.png", 8, 12, False, False, (222, 263)),
    ("fut_arm_prism",        "res://assets/card_icons/enemy/vis_enemy_026.png", 8, 12, False, False, (40, 212)),
    ("mod_arm_abrams_mk2",   "res://assets/card_icons/enemy/vis_enemy_035.png", 8, 11, False, False, (20, 303)),
]


def md5f(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()[:10] if os.path.isfile(p) else None


def load_card(res, flip=False):
    p = os.path.join(ROOT, res[len("res://"):].replace("/", os.sep))
    im = Image.open(p).convert("RGBA")
    if flip:  # player 侧源图朝右 → 翻成 sheet 真身朝左
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    a = im.getchannel("A")
    bb = a.getbbox()
    return im.crop(bb) if bb else im


def to_canvas(sub, air):
    w, h = sub.size
    scale = min((CANVAS - 16) / w, (CANVAS * 0.92 - 8) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    cv = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    if air:  # 空中单位：水平居中，垂直 46% 线（留下方空域给投影感）
        cv.paste(sub, ((CANVAS - nw) // 2, int(CANVAS * 0.46) - nh // 2), sub)
    else:
        cv.paste(sub, ((CANVAS - nw) // 2, FOOT - nh), sub)
    return cv


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


def build(base, bb, air, idle_n, attack_n, muzzle=None):
    """base=512 画布合成帧; bb=主体框。返回 idle/attack 帧列表(512)。muzzle=(gx,gy) 覆盖自动枪口检测"""
    x0, y0, x1, y1 = bb
    arr = np.asarray(base)
    solid = arr[:, :, 3] > 128
    cols = np.where(solid.any(axis=0))[0]
    # 枪口高度 = 最左 24px 带(最左伸出的即炮管/枪管尖)的实心行中位
    c0 = int(cols.min())
    tip_rows = np.where(solid[:, c0:min(c0 + 24, arr.shape[1])].any(axis=1))[0]
    gun_y = int(np.median(tip_rows)) if len(tip_rows) else int(np.median(np.where(solid.any(axis=1))[0]))
    gun_x = c0 + 6
    if muzzle:
        gun_x, gun_y = muzzle

    bob = [0, -1, -2, -1, 0, -1, -2, -1]
    idle = []
    for i in range(idle_n):
        dy = bob[i % len(bob)]
        f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        f.paste(base, (0, dy), base)
        idle.append(f)

    # attack: n 帧三段（静-后坐+火光峰-回位），火光半径随相位包络
    def phase(i):
        if i < attack_n / 3.0: return 0, 0
        if i < 2 * attack_n / 3.0: return (5 if i - attack_n / 3.0 < 1.5 else 3), 1
        return 2 if i < 5 * attack_n / 6.0 else 0, 0

    atk = []
    for i in range(attack_n):
        rec, firing = phase(i)
        f = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        f.paste(base, (rec, 0), base)
        d = ImageDraw.Draw(f)
        if firing:
            k = 1.0 - (i - attack_n / 3.0) / max(attack_n / 3.0, 1)
            r = int(26 * k) + 6
            cx = max(gun_x - 2, r + 4)  # 火光星心收进主体前缘内侧, 钳制不切画布
            flash_star(d, cx, gun_y, r)
            d.ellipse([max(cx - 42, 4), gun_y - 5, cx, gun_y + 5], fill=(255, 200, 80, 190))
        elif rec:
            cx = max(gun_x - 2, 18)
            d.ellipse([max(cx - 28, 4), gun_y - 7, cx, gun_y + 7], fill=(255, 180, 70, 110))
        atk.append(f)
    return idle, atk


def main():
    os.makedirs(REV, exist_ok=True)
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for case in CASES:
        key, card_res, idle_n, attack_n, air, flip = case[:6]
        muzzle = case[6] if len(case) > 6 else None
        if only and key not in only:
            continue
        out_dir = os.path.join(ANIM, key)
        os.makedirs(out_dir, exist_ok=True)
        # 备份现役（仅一次）
        bdir = os.path.join(BAK, key)
        os.makedirs(bdir, exist_ok=True)
        aj = os.path.join(out_dir, "anim.json")
        old_meta = json.load(open(aj, encoding="utf-8")) if os.path.isfile(aj) else {}
        old_counts = old_meta.get("counts", {})
        for fn in ("sheet_idle.png", "sheet_attack.png", "anim.json"):
            src = os.path.join(out_dir, fn)
            if os.path.isfile(src) and not os.path.isfile(os.path.join(bdir, fn)):
                shutil.copy2(src, os.path.join(bdir, fn))
        # 直出
        sub = load_card(card_res, flip)
        cv = to_canvas(sub, air)
        arr = np.asarray(cv)
        solid = arr[:, :, 3] > 8
        cols = np.where(solid.any(axis=0))[0]
        rows = np.where(solid.any(axis=1))[0]
        bb = (int(cols.min()), int(rows.min()), int(cols.max()), int(rows.max()))
        idle, atk = build(cv, bb, air, idle_n, attack_n, muzzle)
        for anim, frames in (("idle", idle), ("attack", atk)):
            sh = Image.new("RGBA", (CANVAS * len(frames), CANVAS), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                sh.paste(fr, (i * CANVAS, 0))
            sh.save(os.path.join(REV, "%s_%s_sheet_512.png" % (key, anim)))
            half = sh.resize((FRAME * len(frames), FRAME), Image.LANCZOS)
            dua.bake_outline_on_sheet(half).save(os.path.join(out_dir, "sheet_%s.png" % anim))
        meta = {"fps": old_meta.get("fps", 8), "frame_size": FRAME,
                "counts": {"idle": idle_n, "attack": attack_n},
                "outline": dua.outline_meta()}
        if old_meta.get("foot_frac") is not None:
            meta["foot_frac"] = old_meta["foot_frac"]  # 先保留, 收尾统一重算
        json.dump(meta, open(aj, "w", encoding="utf-8"), ensure_ascii=False)
        print("[%s] 直出 idle=%d attack=%d air=%s 旧counts=%s sheet md5 i=%s a=%s" % (
            key, idle_n, attack_n, air, old_counts,
            md5f(os.path.join(out_dir, "sheet_idle.png")),
            md5f(os.path.join(out_dir, "sheet_attack.png"))))
    print("A 组直出完成（备份 .godot/art_backup_visionfix_20261003/）")


if __name__ == "__main__":
    main()
