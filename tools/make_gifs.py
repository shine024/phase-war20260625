#!/usr/bin/env python3
"""Split sprite sheets into animated GIFs for HTML showcase."""

import os
from PIL import Image

root = r"F:\godot fair duet\create\phase-war"

# All resources: (sprite_sheet_path, output_gif_name, frame_count)
RESOURCES = [
    # Section 1.1 - General projectiles (1536x1024, horizontal sprite sheets)
    ("docs/美术资源预览/弹道与命中效果/弹道_冲锋枪.png", "anim_01_smg_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_步枪.png", "anim_02_rifle_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_机枪.png", "anim_03_mg_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_手枪.png", "anim_04_pistol_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_霰弹.png", "anim_05_shotgun_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_狙击.png", "anim_06_sniper_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_激光.png", "anim_07_laser_projectile.gif", 8),
    ("docs/美术资源预览/弹道与命中效果/弹道_火箭.png", "anim_08_rocket_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_导弹.png", "anim_09_missile_projectile.gif", 8),
    ("docs/美术资源预览/弹道与命中效果/弹道_高射炮.png", "anim_10_flak_projectile.gif", 10),
    ("docs/美术资源预览/弹道与命中效果/弹道_电磁轨道炮.png", "anim_11_rail_projectile.gif", 8),
    ("docs/美术资源预览/弹道与命中效果/弹道_Omega加农炮.png", "anim_12_omega_cannon_projectile.gif", 8),
    
    # Section 1.3 - Artillery (1024x1024, horizontal sprite sheets)
    ("assets/effects/projectiles/artillery_anim/weapon_artillery_ballistic.png", "anim_25_artillery_ballistic.gif", 20),
    ("assets/effects/projectiles/artillery_anim/weapon_artillery_muzzle.png", "anim_26_artillery_muzzle.gif", 20),
    ("assets/effects/projectiles/artillery_anim/weapon_artillery_impact.png", "anim_27_artillery_impact.gif", 20),
    
    # Section 1.4 - Omega platform (1536x1024)
    ("assets/effects/projectiles/omega_platform/omega_platform_projectile_core.png", "anim_28_omega_core.gif", 9),
    ("assets/effects/projectiles/omega_platform/omega_platform_projectile_trail.png", "anim_29_omega_trail.gif", 26),
    ("assets/effects/projectiles/omega_platform/omega_platform_projectile_impact.png", "anim_30_omega_impact.gif", 25),
    
    # Section 2 - Impact effects (1536x1024)
    ("docs/美术资源预览/弹道与命中效果/命中特效_轻武器.png", "anim_31_impact_small_arms.gif", 16),
    ("docs/美术资源预览/弹道与命中效果/命中特效_霰弹.png", "anim_32_impact_shotgun.gif", 16),
    ("docs/美术资源预览/弹道与命中效果/命中特效_狙击.png", "anim_33_impact_sniper.gif", 16),
    ("docs/美术资源预览/弹道与命中效果/命中特效_爆炸.png", "anim_34_impact_explosive.gif", 16),
    ("docs/美术资源预览/弹道与命中效果/命中_Omega.png", "anim_35_impact_omega.gif", 16),
    ("docs/美术资源预览/弹道与命中效果/曲射弹道.png", "anim_36_artillery_trajectory.gif", 20),
    ("docs/美术资源预览/弹道与命中效果/曲射命中特效_v3_透明底.png", "anim_37_artillery_hit_v3.gif", 16),
    
    # Section 2.3 - Realistic impacts
    ("assets/effects/projectiles/weapons_realistic/weapon_impact_small_arms.png", "anim_38_impact_small_arms_realistic.gif", 16),
    ("assets/effects/projectiles/weapons_realistic/weapon_impact_shotgun.png", "anim_39_impact_shotgun_realistic.gif", 16),
    ("assets/effects/projectiles/weapons_realistic/weapon_impact_sniper.png", "anim_40_impact_sniper_realistic.gif", 16),
    ("assets/effects/projectiles/weapons_realistic/weapon_impact_explosive.png", "anim_41_impact_explosive_realistic.gif", 16),
    ("assets/effects/projectiles/weapons_realistic/weapon_impact_omega.png", "anim_42_impact_omega_realistic.gif", 16),
]

outdir = os.path.join(root, "output_gifs")
os.makedirs(outdir, exist_ok=True)

success = 0
fail = 0

for sprite_path, gif_name, frames in RESOURCES:
    full_path = os.path.join(root, sprite_path)
    if not os.path.exists(full_path):
        print(f"SKIP (missing): {sprite_path}")
        fail += 1
        continue
    
    try:
        img = Image.open(full_path)
        w, h = img.size
        frame_w = w // frames
        
        frames_list = []
        for i in range(frames):
            left = i * frame_w
            box = (left, 0, left + frame_w, h)
            frame = img.crop(box)
            # Convert to RGBA if needed
            if frame.mode != 'RGBA':
                frame = frame.convert('RGBA')
            frames_list.append(frame)
        
        out_path = os.path.join(outdir, gif_name)
        frames_list[0].save(
            out_path,
            save_all=True,
            append_images=frames_list[1:],
            duration=66,  # ~15fps
            loop=0,
            optimize=True,
        )
        
        size_kb = os.path.getsize(out_path) / 1024
        print(f"OK: {gif_name:55s} {w}x{h} -> {size_kb:.0f}KB")
        success += 1
    except Exception as e:
        print(f"FAIL: {gif_name}: {e}")
        fail += 1

print(f"\nDone: {success} succeeded, {fail} failed")
print(f"GIFs saved to: {outdir}")
