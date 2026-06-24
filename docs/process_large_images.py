#!/usr/bin/env python3
"""Process 1024x1024 images: remove white bg, resize to 512x512."""

from PIL import Image, ImageChops
import os

target_dir = r"F:\godot fair duet\create\phase-war\assets\card_icons"

def remove_white_bg(img):
    if img.mode == 'RGB':
        img = img.convert('RGBA')
    bg_sample = img.getpixel((img.size[0] // 2, 0))
    bg_img = Image.new('RGBA', img.size, bg_sample)
    diff = ImageChops.difference(img, bg_img)
    diff_gray = diff.convert('L')
    mask = diff_gray.point(lambda x: 255 if x > 30 else 0)
    orig_a = img.getchannel('A')
    new_alpha = mask
    if orig_a.getextrema()[0] < 255:
        new_alpha = ImageChops.lighter(mask, orig_a)
    r, g, b, _ = img.split()
    return Image.merge('RGBA', (r, g, b, new_alpha))

def process_image(filename):
    path = os.path.join(target_dir, filename)
    img = Image.open(path)
    img = remove_white_bg(img)
    
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        img.thumbnail((512, 512), Image.LANCZOS)
        canvas = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
        x = (512 - img.size[0]) // 2
        y = (512 - img.size[1]) // 2
        canvas.paste(img, (x, y), img)
        img = canvas
    
    img.save(path, 'PNG')
    return img.size

# Files to process (exclude placeholder and omega_platform)
files_to_process = [
    'cold_bmp1.png', 'cold_bradley.png', 'cold_btr60.png', 'cold_chieftain.png',
    'cold_f4.png', 'cold_leo1.png', 'cold_m1.png', 'cold_m113.png', 'cold_m14.png',
    'cold_m60t.png', 'cold_mig21.png', 'cold_t55.png', 'cold_t62.png', 'cold_t72.png',
    'cold_zsu23.png',
    'fut_aa_hover.png', 'fut_assault_mech.png', 'fut_attack_drone.png',
    'fut_scout_drone.png', 'fut_scout_mech.png', 'fut_shield.png',
    'fut_space_fighter.png', 'fut_spectre.png', 'fut_stealth_bomber.png',
    'fut_stormcore.png', 'fut_swarm.png',
    'mod_ah1.png', 'mod_ah64.png', 'mod_challenger2.png', 'mod_hummer_m2.png',
    'mod_hummer_tow.png', 'mod_leo2a6.png', 'mod_m1a1.png', 'mod_m1a2.png',
    'mod_m270.png', 'mod_m6.png', 'mod_stryker_m2.png', 'mod_stryker_mgs.png',
    'mod_t90.png', 'mod_uh60.png',
    'vis_player_003.png', 'vis_player_012.png', 'vis_player_013.png', 'vis_player_030.png',
    'ww1_37mm.png', 'ww1_a7v.png', 'ww1_ft17.png', 'ww1_lanchest.png',
    'ww1_mark4.png', 'ww1_mg08.png', 'ww1_saint.png', 'ww1_vickers.png',
    'ww2_browning.png', 'ww2_hellcat.png', 'ww2_is2.png', 'ww2_kingtiger.png',
    'ww2_m81.png', 'ww2_panther.png', 'ww2_pz3.png', 'ww2_pz4.png',
    'ww2_sherman.png', 'ww2_t34_76.png', 'ww2_t34_85.png',
]

# Exclude placeholder
if '_enemy_placeholder.png' in files_to_process:
    files_to_process.remove('_enemy_placeholder.png')

print(f"Processing {len(files_to_process)} files...")
ok = 0
fail = 0
for f in files_to_process:
    try:
        size = process_image(f)
        ok += 1
        print(f"  OK: {f} -> {size}")
    except Exception as e:
        fail += 1
        print(f"  FAIL: {f} - {e}")

print(f"\nDone: {ok} OK, {fail} failed")
