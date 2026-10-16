# -*- coding: utf-8 -*-
"""整卷动画重做批（2026-10-14）：体检报告 §8.3 重灾 5 卷 + t34_85 焰位错位卷。

路线 = API 精灵图工作流单姿态 i2i（锚=现役卡图，与 _tmp_api_firegrid 同款）：
  每卷 idle 8 拍 + attack 6 拍 → 自适应品红键控 → 全卷统一缩放（防 size 跳变 QA）
  → 底线对齐 → 描边烘焙（deploy_unit_anims.bake_outline_on_sheet）→ sheet+anim.json
  → foot_frac/subject 工具回填 → --import。
t34_85 修复点：击发焰强制画在左侧炮口（原卷焰在右后 x=217）。

产物直接进 assets/effects/unit_anims/<key>/（改前整卷备份 D:/godotplay/_art_backup/）。
用法：python tools/_tmp_anim_redo_api_20261014.py <key|all> [pass]
"""
import json
import os
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _tmp_api_card_regen_20261014 import KEYS, SKELETON, ROOT, CTX  # noqa: E402
from _tmp_api_firegrid_20261014 import call_i2i, b64  # noqa: E402

ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
POSE_ROOT = os.path.join(ROOT, ".godot", "unit_review", "apiredo")

UNITS_REDO = {
    "ww2_t34_85": dict(
        anchor="assets/card_icons/player/vis_player_007.png",
        desc="a World War II Soviet T-34/85 medium tank: one sloped-armor turret with a long 85mm gun, green camouflage steel, five large road wheels per side",
        idle=[
            "idle 1: the tank parked level, turret facing forward, gun level left, engine idling",
            "idle 2: the turret traversed a few degrees toward the left, gun swinging with it",
            "idle 3: the turret traversed back toward center, gun level left again",
            "idle 4: the tank settled slightly on its suspension, hull dipping a little at the front",
            "idle 5: the tank rising back to level on its suspension",
            "idle 6: the turret traversed a few degrees toward the right, gun swinging with it",
            "idle 7: the turret traversing back toward forward, gun following",
            "idle 8: the tank parked level and still, identical to idle 1",
        ],
        attack=[
            "ready: the 85mm gun pointing level left from the traversed-forward turret, hull braced on its suspension",
            "fire: the 85mm gun discharging, one large star-shaped orange muzzle flash with a white core attached directly at the LEFT muzzle tip, the hull rocking back on its suspension",
            "fire 2: the muzzle flash at the LEFT gun muzzle shrinking to a smaller burst, smoke wisps drifting left, hull settled",
            "recoil: the gun recoiled back into the turret, the hull settled onto its tracks, no flash",
            "cool: thin smoke drifting from the gun muzzle on the left, the turret unchanged, no flash",
            "settle: the gun back to level left, the tank at rest, identical stance to ready",
        ],
    ),
    "fe_iron_wall_juggernaut": dict(
        anchor="assets/card_icons/enemy/fe_iron_wall_juggernaut.png",
        desc="a colossal iron-wall juggernaut war mech: one massive layered plate armored body, one huge shoulder cannon, one oversized armored fist, thick reverse-jointed legs, dark iron plating with glowing seams",
        idle=[
            "idle 1: the juggernaut standing level on both legs, shoulder cannon forward, fist at its side, seams glowing steady",
            "idle 2: the juggernaut shifting its weight onto the left leg, torso leaning slightly left, seams steady",
            "idle 3: the juggernaut shifting weight back to center, the shoulder cannon elevating a few degrees",
            "idle 4: the shoulder cannon easing back to level, vents on the back releasing a puff of steam",
            "idle 5: the armored fist raising slightly and clenching, seams brightening a little",
            "idle 6: the fist relaxing back down to its side, seams dimming",
            "idle 7: the juggernaut settling onto both legs, torso upright, vents releasing thin steam",
            "idle 8: the juggernaut standing level and still, identical to idle 1",
        ],
        attack=[
            "ready: the one shoulder cannon pointing level left, the juggernaut planted on both legs, seams brightening",
            "fire: the shoulder cannon discharging, one huge star-shaped orange flash with a white core at the LEFT cannon muzzle, the whole mech rocked back",
            "fire 2: the cannon flash shrinking to a smaller burst at the LEFT muzzle, smoke drifting left",
            "recoil: the cannon eased back into its mount, the mech settled onto its legs, no flash",
            "cool: thin smoke drifting from the cannon muzzle on the left, seams glowing from the discharge, no flash",
            "settle: the cannon back to level left, the juggernaut at rest, seams steady",
        ],
    ),
    "fut_colossus": dict(
        anchor="assets/card_icons/enemy/vis_enemy_070.png",
        desc="a towering futuristic colossus mech: heavy pale-green armor, one shoulder-mounted cannon, one arm gatling gun, thick digitigrade legs, glowing cyan core",
        idle=[
            "idle 1: the colossus standing level on its digitigrade legs, shoulder cannon level left, gatling arm lowered, core glow steady",
            "idle 2: the colossus shifting its weight forward, torso dipping slightly, core pulsing brighter",
            "idle 3: the colossus rising back to level, the gatling arm rotating slowly without firing",
            "idle 4: the gatling arm stopping, the shoulder cannon elevating a few degrees",
            "idle 5: the shoulder cannon easing back to level, vents releasing a thin vapor wisp",
            "idle 6: the colossus shifting weight onto the right leg, torso leaning slightly right, core steady",
            "idle 7: the colossus returning to a centered stance, both legs planted",
            "idle 8: the colossus standing level and still, identical to idle 1",
        ],
        attack=[
            "ready: the one shoulder cannon pointing level left, the arm gatling spun up with a slight motion blur, the colossus braced",
            "fire: the shoulder cannon discharging, one large star-shaped orange flash with a white core at the LEFT cannon muzzle, the gatling firing thin tracer streaks toward the left, the mech rocked back",
            "fire 2: the cannon flash shrinking to a smaller burst at the LEFT muzzle, the gatling still spitting tracer streaks, smoke drifting left",
            "recoil: the cannon eased back into its mount, the gatling slowing, the mech settled onto its legs, no flash",
            "cool: thin smoke drifting from both weapons on the left, the gatling stopped, no flash",
            "settle: the cannon back to level left, the gatling arm lowered and still, the colossus at rest",
        ],
    ),
    "ww2_fort_flak": dict(
        anchor="assets/card_icons/enemy/vis_enemy_075.png",
        desc="a World War II 88mm anti-aircraft gun emplacement: one long-barreled 88 on a cross-shaped platform mount with a splinter shield, dark grey steel",
        idle=[
            "idle 1: the 88 barrel elevated toward the upper left, the mount still",
            "idle 2: the barrel elevating a few degrees higher, traversing slightly left",
            "idle 3: the barrel traversing back toward center, elevation unchanged",
            "idle 4: the barrel depressing a few degrees, the mount unchanged",
            "idle 5: the barrel elevating back to its patrol angle toward the upper left",
            "idle 6: the mount rotating a few degrees, the barrel tracking with it",
            "idle 7: the mount rotating back, the barrel settling",
            "idle 8: the barrel at its patrol elevation toward the upper left, identical to idle 1",
        ],
        attack=[
            "ready: the one long barrel elevated toward the upper left, the mount braced, splinter shield unchanged",
            "fire: the 88 discharging, one huge star-shaped orange flash with a white core attached at the elevated LEFT muzzle, the whole mount rocking on its cross legs, dust kicked at the base",
            "fire 2: the muzzle flash shrinking to a smaller burst at the LEFT elevated muzzle, smoke drifting up-left",
            "recoil: the barrel slid back in its cradle, the mount settled onto the platform, no flash",
            "cool: thin smoke drifting from the muzzle high on the left, the barrel re-elevating, no flash",
            "settle: the barrel back elevated toward the upper left, the mount at rest",
        ],
    ),
    "ww2_fort_bunker": dict(
        anchor="assets/card_icons/enemy/vis_enemy_074.png",
        desc="a squat concrete bunker block: one dark embrasure slit, weathered grey concrete walls, a low roof slab",
        idle=[
            "idle 1: the bunker silent, the embrasure dark, no smoke",
            "idle 2: a thin wisp of smoke drifting from a roof vent on the right",
            "idle 3: the smoke wisp thinning and drifting left",
            "idle 4: the bunker silent again, the embrasure dark",
            "idle 5: a faint warm glow appearing deep inside the embrasure slit",
            "idle 6: the glow fading back to dark",
            "idle 7: another thin smoke wisp rising from the roof vent",
            "idle 8: the bunker silent and dark, identical to idle 1",
        ],
        attack=[
            "ready: the one machine gun barrel visible inside the embrasure slit pointing left, the bunker silent",
            "fire: one large star-shaped orange muzzle flash bursting OUT of the embrasure slit toward the LEFT edge, the slit lip scorched bright",
            "fire 2: the muzzle flash at the LEFT embrasure shrinking to a smaller burst, sparks scattering left",
            "recoil: the barrel withdrawn into the slit, thin gunsmoke drifting from the embrasure, no flash",
            "cool: the gunsmoke thinning and drifting left along the wall, no flash",
            "settle: the barrel back at the slit pointing left, the bunker silent",
        ],
    ),
}

INV = ("facing LEFT in profile, the weapon pointing left where applicable, the subject NEVER mirrored, "
       "IDENTICAL structure, identical part count and identical proportions as the reference image: "
       "never adding, removing or reshaping any part, the same colors and details, "
       "the same size within the frame in every image")


def prompt_for(cfg, pose):
    return (SKELETON.replace("{DESC}", cfg["desc"])
            + "Now show THE SAME subject in this exact state: %s. " % pose + INV)


def key_adaptive(im):
    """品红键控；opaque<5% 时回退角点色距键控（防暗品红底）。"""
    from _tmp_api_card_regen_20261014 import key_magenta
    arr = key_magenta(im)
    if (arr[:, :, 3] > 0).mean() >= 0.05:
        return arr
    a = np.asarray(im.convert("RGB")).astype(int)
    cc = np.vstack([a[:40, :40].reshape(-1, 3), a[:40, -40:].reshape(-1, 3),
                    a[-40:, :40].reshape(-1, 3), a[-40:, -40:].reshape(-1, 3)])
    bg = np.median(cc, 0)
    dist = np.sqrt(((a - bg) ** 2).sum(2))
    alpha = np.where(dist < 70, 0, 255).astype(np.uint8)
    return np.dstack([a.astype(np.uint8), alpha])


def assemble(key, cfg):
    """统一缩放拼卷：全卷 bbox 并集定一个比例，底线对齐，描边烘焙，写盘。"""
    from deploy_unit_anims import bake_outline_on_sheet
    pose_dir = os.path.join(POSE_ROOT, key)
    plan = [("idle", p) for p in cfg["idle"]] + [("attack", p) for p in cfg["attack"]]
    keyed = {}
    masks = []
    for idx, (kind, pose) in enumerate(plan):
        fp = os.path.join(pose_dir, "%s_%02d.png" % (kind, idx))
        arr = key_adaptive(Image.open(fp))
        keyed[idx] = arr
        masks.append(arr[:, :, 3] > 0)
    union = np.logical_or.reduce(masks)
    ys, xs = np.nonzero(union)
    ux0, ux1, uy0, uy1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    FS = 256
    scale = min(int(FS * 0.88) / (ux1 - ux0), int(FS * 0.90) / (uy1 - uy0))
    frames = {"idle": [], "attack": []}
    for idx, (kind, pose) in enumerate(plan):
        arr = keyed[idx]
        sub = arr[uy0:uy1, ux0:ux1]
        h, w = sub.shape[:2]
        nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
        im = Image.fromarray(sub, "RGBA").resize((nw, nh), Image.LANCZOS)
        canvas = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        canvas.paste(im, ((FS - nw) // 2, FS - nh - int(round(0.055 * FS))), im)
        frames[kind].append(canvas)
    out_dir = os.path.join(ANIM, key)
    os.makedirs(out_dir, exist_ok=True)
    for kind, fname in (("idle", "sheet_idle.png"), ("attack", "sheet_attack.png")):
        sheet = Image.new("RGBA", (FS * len(frames[kind]), FS), (0, 0, 0, 0))
        for i, fr in enumerate(frames[kind]):
            sheet.paste(fr, (i * FS, 0))
        sheet = bake_outline_on_sheet(sheet)
        sheet.save(os.path.join(out_dir, fname))
        print("  %s/%s: %d frames" % (key, fname, len(frames[kind])), flush=True)
    anim = {"fps": 8, "frame_size": FS,
            "counts": {"idle": len(frames["idle"]), "attack": len(frames["attack"])},
            "outline": {"baked": True, "width_px": 4, "color": [13, 18, 28, 217],
                        "frame_basis": FS}}
    json.dump(anim, open(os.path.join(out_dir, "anim.json"), "w"),
              ensure_ascii=False, indent=1)
    print("  %s/anim.json counts=%s" % (key, anim["counts"]), flush=True)


def redo(key):
    cfg = UNITS_REDO[key]
    pose_dir = os.path.join(POSE_ROOT, key)
    os.makedirs(pose_dir, exist_ok=True)
    card = os.path.join(ROOT, cfg["anchor"])
    card_im = Image.open(card).convert("RGB")
    plan = [("idle", p) for p in cfg["idle"]] + [("attack", p) for p in cfg["attack"]]
    for idx, (kind, pose) in enumerate(plan):
        fp = os.path.join(pose_dir, "%s_%02d.png" % (kind, idx))
        if os.path.exists(fp):
            print("  [%s %02d] 已有, 复用" % (key, idx), flush=True)
            continue
        ok, _ = call_i2i([b64(card_im)], prompt_for(cfg, pose), fp)
        print("  [%s %s_%02d] %s" % (key, kind, idx, "OK" if ok else "FAIL"),
              flush=True)
        if not ok:
            return False
        time.sleep(2)
    assemble(key, cfg)
    return True


if __name__ == "__main__":
    targets = [sys.argv[1]] if len(sys.argv) > 1 and sys.argv[1] != "all" \
        else list(UNITS_REDO)
    for k in targets:
        print("[%s] 重做开始" % k, flush=True)
        redo(k)
    print("redo pass done", flush=True)
