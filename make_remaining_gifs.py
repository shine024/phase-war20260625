#!/usr/bin/env python3
"""Generate remaining GIFs: realistic projectiles + law effects."""

import os
from PIL import Image

root = r"F:\godot fair duet\create\phase-war"
outdir = os.path.join(root, "output_gifs")

# Realistic projectiles - these are single-frame images (256x256)
# We'll copy them as-is with .gif extension
realistic_projectiles = [
    ("assets/effects/projectiles/weapons_realistic/weapon_smg_projectile.png", "anim_13_smg_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_rifle_projectile.png", "anim_14_rifle_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_mg_projectile.png", "anim_15_mg_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_pistol_projectile.png", "anim_16_pistol_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_shotgun_projectile.png", "anim_17_shotgun_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_sniper_projectile.png", "anim_18_sniper_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_rocket_projectile.png", "anim_19_rocket_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_flak_projectile.png", "anim_20_flak_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_laser_projectile.png", "anim_21_laser_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_missile_projectile.png", "anim_22_missile_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_omega_cannon_projectile.png", "anim_23_omega_cannon_realistic.gif"),
    ("assets/effects/projectiles/weapons_realistic/weapon_rail_cannon_projectile.png", "anim_24_rail_realistic.gif"),
]

success = 0
fail = 0

for src_path, gif_name in realistic_projectiles:
    full_path = os.path.join(root, src_path)
    if not os.path.exists(full_path):
        print(f"SKIP: {src_path}")
        fail += 1
        continue
    
    try:
        img = Image.open(full_path)
        out_path = os.path.join(outdir, gif_name)
        img.save(out_path, optimize=True)
        size_kb = os.path.getsize(out_path) / 1024
        print(f"OK: {gif_name:50s} {size_kb:.0f}KB")
        success += 1
    except Exception as e:
        print(f"FAIL: {gif_name}: {e}")
        fail += 1

# Law effects - single frame images (1024x1024)
law_files = sorted(os.listdir(os.path.join(root, "assets/effects/laws")))
law_map = {
    "sci_fi_game_VFX_art__phase_arm_2026-05-21T00-43-56.png": "#43 钢铁·相位装甲",
    "sci_fi_game_VFX_art__fortress__2026-05-21T00-43-56.png": "#44 钢铁·堡垒之墙",
    "sci_fi_game_VFX_art__nanite_re_2026-05-21T00-43-56.png": "#45 钢铁·快速维修",
    "sci_fi_game_VFX_art__shared_sh_2026-05-21T00-43-57.png": "#46 钢铁·护阵联结",
    "sci_fi_game_VFX_art__anchor_fi_2026-05-21T00-44-24.png": "#47 钢铁·锚定力场",
    "sci_fi_game_VFX_art__armor_har_2026-05-21T00-44-24.png": "#48 钢铁·固壁协议",
    "sci_fi_game_VFX_art__resonant__2026-05-21T00-44-50.png": "#49 钢铁·共振装甲",
    "sci_fi_game_VFX_art__burning_p_2026-05-21T00-44-50.png": "#50 烈焰·热能过载",
    "sci_fi_game_VFX_art__forward_f_2026-05-21T00-44-50.png": "#51 烈焰·前线火力压制",
    "sci_fi_game_VFX_art__ember_par_2026-05-21T00-45-17.png": "#52 烈焰·灼烧印记",
    "sci_fi_game_VFX_art__advancing_2026-05-21T00-44-51.png": "#53 烈焰·灼浪推进",
    "sci_fi_game_VFX_art__afterburn_2026-05-21T00-45-17.png": "#54 烈焰·灰烬幕障",
    "sci_fi_game_VFX_art__ultimate__2026-05-21T00-45-17.png": "#55 烈焰·核心破裂",
    "sci_fi_game_VFX_art__weapon_he_2026-05-21T00-44-24.png": "#56 烈焰·余烬加燃",
    "sci_fi_game_VFX_art__EMP_storm_2026-05-21T00-45-17.png": "#57 雷霆·电磁风暴",
    "sci_fi_game_VFX_art__chain_lig_2026-05-21T00-45-44.png": "#58 雷霆·链式放电",
    "sci_fi_game_VFX_art__ion_net_a_2026-05-21T00-45-44.png": "#59 雷霆·离子网",
    "sci_fi_game_VFX_art__arc_beaco_2026-05-21T00-45-44.png": "#60 雷霆·弧光信标",
    "sci_fi_game_VFX_art__electric__2026-05-21T00-45-44.png": "#61 雷霆·激涌驱动",
    "sci_fi_game_VFX_art__static_el_2026-05-21T00-46-12.png": "#62 雷霆·静电域",
    "sci_fi_game_VFX_art__spacetime_2026-05-21T00-46-12.png": "#63 虚空·时空涟漪",
    "sci_fi_game_VFX_art__shield_co_2026-05-21T00-46-12.png": "#64 虚空·护盾转移",
    "sci_fi_game_VFX_art__phase_clo_2026-05-21T00-46-12.png": "#65 虚空·相位披幕",
    "sci_fi_game_VFX_art__entropy_l_2026-05-21T00-46-35.png": "#66 虚空·熵镜",
    "sci_fi_game_VFX_art__gravity_w_2026-05-21T00-46-35.png": "#67 虚空·引力井",
}

for fname, label in law_map.items():
    full_path = os.path.join(root, "assets/effects/laws", fname)
    if not os.path.exists(full_path):
        print(f"SKIP: {fname}")
        fail += 1
        continue
    
    try:
        num = label.split()[0].replace("#", "")
        gif_name = f"law_{num}_{fname[:30]}.gif"
        img = Image.open(full_path)
        out_path = os.path.join(outdir, gif_name)
        img.save(out_path, optimize=True)
        size_kb = os.path.getsize(out_path) / 1024
        print(f"OK: {label:30s} {size_kb:.0f}KB")
        success += 1
    except Exception as e:
        print(f"FAIL: {label}: {e}")
        fail += 1

print(f"\nDone: {success} succeeded, {fail} failed")
