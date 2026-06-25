#!/usr/bin/env python3
"""Batch fix: remove white background + resize to 512x512 for root-level PNGs."""

import os
from PIL import Image

base_dir = r"F:\godot fair duet\create\phase-war\assets\card_icons"

files_to_fix = [
    "boss_cold_mig.png", "boss_future_nexus.png", "boss_modern_command.png",
    "boss_ww1_av7.png", "boss_ww2_kingtiger.png",
    "elite_cold_t72.png", "elite_future_spectre.png", "elite_modern_abrams.png", "elite_modern_apache.png",
    "enemy_cold_ak.png", "enemy_cold_btr.png", "enemy_cold_m113.png", "enemy_cold_m14.png",
    "enemy_cold_m60.png", "enemy_cold_rpg.png",
    "enemy_future_cyborg.png", "enemy_future_drone.png", "enemy_future_hovertank.png",
    "enemy_future_howitzer.png", "enemy_future_mech.png",
    "enemy_modern_javelin.png", "enemy_modern_marine.png", "enemy_modern_stryker.png",
    "enemy_ww1_105mm.png", "enemy_ww1_m76.png", "enemy_ww1_mg08.png",
    "enemy_ww1_mg_nest.png", "enemy_ww1_mortar.png",
    "enemy_ww2_infantry.png", "enemy_ww2_mp40.png",
    "enemy_ww2_panzerschreck.png", "enemy_ww2_panzerschrek.png",
    "_enemy_placeholder.png", "enemy_ww1_infantry_basic.png",
]

SUCCESS = []
FAILED = []

def remove_white_and_crop(img, tolerance=20):
    """Remove white/light background, crop to subject, pad to square."""
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    w, h = img.size
    pixels = list(img.getdata())
    
    # Build byte string for new image
    new_bytes = bytearray()
    for px in pixels:
        r, g, b, a = px
        # If pixel is close to white, make transparent
        if abs(r - 255) <= tolerance and abs(g - 255) <= tolerance and abs(b - 255) <= tolerance:
            new_bytes.extend([r, g, b, 0])
        else:
            new_bytes.extend([r, g, b, min(a, 255)])
    
    result = Image.frombytes('RGBA', (w, h), bytes(new_bytes))
    
    # Crop to bounding box of non-transparent pixels
    bbox = result.getbbox()
    if bbox is None:
        return result
    
    cropped = result.crop(bbox)
    
    # Pad to square
    cw, ch = cropped.size
    size = max(cw, ch)
    padded = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    paste_x = (size - cw) // 2
    paste_y = (size - ch) // 2
    padded.paste(cropped, (paste_x, paste_y))
    
    return padded


for f in files_to_fix:
    src = os.path.join(base_dir, f)
    if not os.path.exists(src):
        FAILED.append((f, "MISSING"))
        print(f"SKIP {f}: MISSING")
        continue
    
    try:
        img = Image.open(src)
        orig_w, orig_h = img.size
        
        # Step 1: Remove white background and crop to subject
        processed = remove_white_and_crop(img)
        
        # Step 2: Resize to 512x512
        processed = processed.resize((512, 512), Image.LANCZOS)
        
        # Verify alpha
        pixels = list(processed.getdata())
        trans_count = sum(1 for px in pixels if px[3] == 0)
        total = len(pixels)
        
        # Save
        processed.save(src, 'PNG')
        
        # Remove .import file if exists
        imp = src + ".import"
        if os.path.exists(imp):
            os.remove(imp)
        
        SUCCESS.append((f, f"{orig_w}x{orig_h} -> 512x512, alpha={trans_count}/{total}"))
        print(f"OK   {f}: {orig_w}x{orig_h} -> 512x512, transparent_pixels={trans_count}/{total}")
        
    except Exception as e:
        FAILED.append((f, str(e)))
        print(f"FAIL {f}: {e}")

print(f"\n{'='*60}")
print(f"Success: {len(SUCCESS)}, Failed: {len(FAILED)}")
if FAILED:
    print("\nFailed:")
    for f, reason in FAILED:
        print(f"  {f}: {reason}")
