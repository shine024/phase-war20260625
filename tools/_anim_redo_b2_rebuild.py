# -*- coding: utf-8 -*-
## B2 批：动画重做 —— 卡图直出重建（范式 = _vision_fix_rebuild_a，2026-10-03 用户验收）
## 范围：审查导出 128 案中 B1(火光)/A组/B组 未覆盖的 38 案 + fe_ 13 案全新建 + 2 特案(卡图互换)
## 规则：fam 同卡家族原地重建（B1 先例）；卡图不同股东 → 单位键专属目录（cold_arm_btr_e）
##       只动显式清单；每文件先备份再写（.godot/art_backup_b2_rebuild_20261003/）
import json, os, sys, io, hashlib, shutil
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

spec = importlib.util.spec_from_file_location("ra", os.path.join(ROOT, "tools", "_vision_fix_rebuild_a.py"))
ra = importlib.util.module_from_spec(spec)
sys.modules["ra"] = ra
spec.loader.exec_module(ra)
import numpy as np
from PIL import Image, ImageDraw

BAK = os.path.join(ROOT, ".godot", "art_backup_b2_rebuild_20261003")

# (key, 卡图res路径, air, flip, parts, muzzle, nofire)
# parts: ("idle",)/("attack",)/None=两列; nofire=True: attack 列用待机式微颤(不开火, gmc_truck)
CASES = [
    ("ww1_arm_ft17",        "res://assets/card_icons/player/vis_player_002.png", False, True,  ("attack",), None, False),
    ("ww1_mp18",            "res://assets/card_icons/player/vis_player_036.png", False, True,  None,        None, False),
    ("ww1_fort_artillery",  "res://assets/card_icons/player/vis_player_073.png",   False, True, ("idle",),   None, False),
    ("ww2_inf_bazooka",     "res://assets/card_icons/player/vis_player_009.png", False, True,  None,        None, False),
    ("ww2_arty_m81",        "res://assets/card_icons/player/vis_player_011.png", False, True,  ("attack",), None, False),
    ("ww2_panther",         "res://assets/card_icons/player/vis_player_048.png", False, True,  None,        None, False),
    ("ww2_pschreck",        "res://assets/card_icons/enemy/vis_enemy_046.png", False, False,  None,        None, False),
    ("cold_ak47",           "res://assets/card_icons/player/vis_player_050.png", False, True,  None,        None, False),
    ("cold_bradley",        "res://assets/card_icons/player/vis_player_053.png", False, True,  None,        None, False),
    ("cold_arm_btr_e",      "res://assets/card_icons/enemy/vis_enemy_052.png", False, False,  None,        None, False),
    ("mod_javelin",         "res://assets/card_icons/player/vis_player_089.png", False, True,  None,        None, False),
    ("mod_stryker_m2",      "res://assets/card_icons/player/mod_stryker_m2.png", False, True,  None,        None, False),
    ("fut_arm_hovertank",   "res://assets/card_icons/player/vis_player_025.png", False, True,  None,        None, False),
    ("fut_space_fighter",   "res://assets/card_icons/player/vis_player_093.png", True,  True,  None,        None, False),
    ("fut_nano_drone",      "res://assets/card_icons/player/fut_nano_drone.png", True,  True,  None,        None, False),
    ("fut_nexus",           "res://assets/card_icons/enemy/vis_enemy_071.png", False, False,  ("idle",),   None, False),
    ("fut_colossus",        "res://assets/card_icons/player/vis_player_070.png", False, True,  None,        None, False),
    ("guardian_cold_thunder",   "res://assets/card_icons/player/vis_player_112.png", False, True, ("idle",),  None, False),
    ("guardian_future_omega",   "res://assets/card_icons/player/vis_player_114.png", False, True, None,      None, False),
    ("ww1_inf_cavalry",     "res://assets/card_icons/player/vis_player_004.png", False, True,  ("attack",), None, False),
    ("ww2_sup_gmc_truck",   "res://assets/card_icons/enemy/ww2_sup_gmc_truck.png", False, False,  ("attack",), None, True),
    ("mod_sup_m4_carbine",  "res://assets/card_icons/enemy/mod_sup_m4_carbine.png", False, False, None,    None, False),
    ("mod_arty_rq7",        "res://assets/card_icons/enemy/mod_arty_rq7.png", False, False,  ("idle",),   None, False),
    ("fut_inf_neural",      "res://assets/card_icons/enemy/fut_inf_neural.png", False, False,  ("idle",),   None, False),
    ("fut_sup_ps9",         "res://assets/card_icons/enemy/fut_sup_ps9.png", False, False,  ("idle",),   None, False),
    ("ww2_air_dive_bomber", "res://assets/card_icons/enemy/ww2_air_dive_bomber.png", True, False, None,     None, False),
    ("cold_air_strike_fighter", "res://assets/card_icons/enemy/cold_air_strike_fighter.png", True, False, None, None, False),
    ("mod_air_bomber",      "res://assets/card_icons/enemy/mod_air_bomber.png", True,  False,  None,        None, False),
    ("fut_air_stealth_multirole", "res://assets/card_icons/enemy/fut_air_stealth_multirole.png", True, False, None,      None, False),
    ("ww2_air_meteor_e",    "res://assets/card_icons/enemy/ww2_air_meteor_e.png", True, False, None,        None, False),
    ("ww2_air_me262",       "res://assets/card_icons/enemy/ww2_air_me262.png", True,  False,  None,        None, False),
    ("fut_fort_ion",        "res://assets/card_icons/player/vis_player_080.png", False, True,  None,        None, False),
    # fe_ 13 案：目录不存在，全新建（id 即解析链单位键，自动接线）
    ("fe_iron_wall_bastion",      "res://assets/card_icons/player/fe_iron_wall_bastion.png", False, False, None, None, False),
    ("fe_nova_devastator",        "res://assets/card_icons/player/fe_nova_devastator.png",   False, True,  None, None, False),
    ("fe_nova_ghost_sniper",      "res://assets/card_icons/player/fe_nova_ghost_sniper.png", False, True,  None, None, False),
    ("fe_aether_hover_cavalry",   "res://assets/card_icons/player/fe_aether_hover_cavalry.png", True, False, None, None, False),
    ("fe_aether_swarm_queen",     "res://assets/card_icons/player/fe_aether_swarm_queen.png",  True, False, None, None, False),
    ("fe_quantum_mobile_base",    "res://assets/card_icons/player/fe_quantum_mobile_base.png", False, False, None, None, False),
    ("fe_quantum_repair_drone",   "res://assets/card_icons/player/fe_quantum_repair_drone.png", True, False, None, None, False),
    ("fe_helix_orbital_strike",   "res://assets/card_icons/player/fe_helix_orbital_strike.png", False, True, None, None, False),
    ("fe_void_phase_cannon",      "res://assets/card_icons/player/fe_void_phase_cannon.png",  False, True,  None, None, False),
    ("fe_void_dimensional_soldier","res://assets/card_icons/player/fe_void_dimensional_soldier.png", False, False, None, None, False),
    ("fe_frontier_veteran",       "res://assets/card_icons/player/fe_frontier_veteran.png",  False, False, None, None, False),
    ("fe_frontier_mixed_company", "res://assets/card_icons/player/fe_frontier_mixed_company.png", False, True, None, None, False),
    ("fe_iron_wall_juggernaut",   "res://assets/card_icons/player/fe_iron_wall_juggernaut.png", False, False, None, None, False),
]


def backup(out_dir, bdir, fns):
    os.makedirs(bdir, exist_ok=True)
    for fn in fns:
        src = os.path.join(out_dir, fn)
        if os.path.isfile(src) and not os.path.isfile(os.path.join(bdir, fn)):
            shutil.copy2(src, os.path.join(bdir, fn))


def build_nofire(base, idle):
    """gmc_truck：attack 列 = 待机式微颤（不开火）。"""
    return [f.copy() for f in idle]


def process(case):
    key, card_res, air, flip, parts, muzzle, nofire = case
    out_dir = os.path.join(ra.ANIM, key)
    os.makedirs(out_dir, exist_ok=True)
    aj = os.path.join(out_dir, "anim.json")
    old_meta = json.load(open(aj, encoding="utf-8")) if os.path.isfile(aj) else {}
    old_counts = old_meta.get("counts", {})
    backup(out_dir, os.path.join(BAK, key), ("sheet_idle.png", "sheet_attack.png", "anim.json", "attack_f0.png"))
    keep_idle, keep_attack = parts == ("attack",), parts == ("idle",)
    idle_n = int(old_counts.get("idle", 8) or 8)
    attack_n = int(old_counts.get("attack", 12) or 12)
    sub = ra.load_card(card_res, flip)
    cv = ra.to_canvas(sub, air)
    arr = np.asarray(cv)
    solid = arr[:, :, 3] > 8
    cols = np.where(solid.any(axis=0))[0]
    rows_ = np.where(solid.any(axis=1))[0]
    bb = (int(cols.min()), int(rows_.min()), int(cols.max()), int(rows_.max()))
    idle, atk = ra.build(cv, bb, air, idle_n, attack_n, muzzle)
    if nofire:
        atk = build_nofire(cv, idle)
    for anim, frames in (("idle", idle), ("attack", atk)):
        if anim == "idle" and keep_idle:
            continue
        if anim == "attack" and keep_attack:
            continue
        sh = Image.new("RGBA", (ra.CANVAS * len(frames), ra.CANVAS), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sh.paste(fr, (i * ra.CANVAS, 0))
        sh.save(os.path.join(ra.REV, "%s_%s_sheet_512.png" % (key, anim)))
        half = sh.resize((ra.FRAME * len(frames), ra.FRAME), Image.LANCZOS)
        dua_sheet = ra.dua.bake_outline_on_sheet(half)
        dua_sheet.save(os.path.join(out_dir, "sheet_%s.png" % anim))
    meta = {"fps": old_meta.get("fps", 8), "frame_size": ra.FRAME,
            "counts": {"idle": idle_n if not keep_idle else int(old_counts.get("idle", 8)),
                       "attack": attack_n if not keep_attack else int(old_counts.get("attack", 12))},
            "outline": ra.dua.outline_meta()}
    if old_meta.get("foot_frac") is not None:
        meta["foot_frac"] = old_meta["foot_frac"]
    json.dump(meta, open(aj, "w", encoding="utf-8"), ensure_ascii=False)
    print("[OK] %-28s air=%-5s parts=%-14s counts=%s/%s flip=%s" % (
        key, air, str(parts), meta["counts"]["idle"], meta["counts"]["attack"], flip))


def main():
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    ok = 0
    for case in CASES:
        if only and case[0] not in only:
            continue
        process(case)
        ok += 1
    print("B2 直出完成 %d 案（备份 %s/）" % (ok, BAK))


if __name__ == "__main__":
    main()
