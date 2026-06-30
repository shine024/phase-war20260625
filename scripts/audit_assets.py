#!/usr/bin/env python3
"""Art asset audit for Phase War"""
import os, json, re

BASE = r"D:\godotplay\godot fair duel\phase-war"

# Scan all assets
asset_types = {}
for root, dirs, files in os.walk(os.path.join(BASE, "assets")):
    for f in files:
        ext = os.path.splitext(f)[1].lower()
        if ext in ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'):
            cat = "images"
        elif ext in ('.ogg', '.wav', '.mp3', '.flac'):
            cat = "audio"
        elif ext in ('.ttf', '.otf', '.woff'):
            cat = "fonts"
        elif ext in ('.tga', '.bmp'):
            cat = "images"
        else:
            continue
        if cat not in asset_types:
            asset_types[cat] = []
        rel = os.path.relpath(os.path.join(root, f), os.path.join(BASE, "assets"))
        asset_types[cat].append(rel)

for cat in sorted(asset_types):
    asset_types[cat].sort()

print("=== Asset Inventory ===")
for cat in sorted(asset_types):
    print(f"{cat}: {len(asset_types[cat])} files")
    for f in asset_types[cat][:10]:
        print(f"  {f}")
    if len(asset_types[cat]) > 10:
        print(f"  ... and {len(asset_types[cat])-10} more")

# Check the 6 missing refs from code scan
print("\n=== Missing Asset Check ===")
missing_from_code = [
    "assets/backgrounds/*.png",
    "assets/sfx/button.ogg",
    "assets/unit_sprites/omega_platform.png",
    "audio/sfx/interface_sound.tres",
    "models/characters/player_model.tscn",
    "textures/ui/ui_theme.tres"
]
for m in missing_from_code:
    full = os.path.join(BASE, m)
    exists = os.path.exists(full)
    # Check if it's a wildcard
    if '*' in m:
        import glob
        matches = glob.glob(full)
        print(f"  {m}: {len(matches)} matches")
    else:
        print(f"  {m}: {'EXISTS' if exists else 'MISSING'}")

# Save asset inventory
with open(os.path.join(BASE, "audit_assets.json"), 'w') as f:
    json.dump(asset_types, f, indent=2, ensure_ascii=False)
print(f"\nSaved to audit_assets.json")
