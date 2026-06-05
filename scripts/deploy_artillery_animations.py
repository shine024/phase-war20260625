#!/usr/bin/env python3
"""Deploy artillery animation textures to the project and update bullet system."""
import os
import shutil
from pathlib import Path

PROJECT = r"F:\godot fair duet\create\phase-war"
SRC = os.path.join(PROJECT, "assets", "effects", "projectiles", "artillery_anim")
DEST = os.path.join(PROJECT, "assets", "effects", "projectiles", "weapons_realistic")

# Files to deploy (use v3 versions which are the latest)
DEPLOY_FILES = {
    "weapon_artillery_muzzle_v3_transparent.png": "weapon_artillery_muzzle.png",
    "weapon_artillery_impact_v3_transparent.png": "weapon_artillery_impact.png",
    "weapon_artillery_ballistic_transparent.png": "weapon_artillery_ballistic.png",
}

def main():
    os.makedirs(DEST, exist_ok=True)
    
    for src_name, dest_name in DEPLOY_FILES.items():
        src_path = os.path.join(SRC, src_name)
        dest_path = os.path.join(DEST, dest_name)
        
        if not os.path.exists(src_path):
            print(f"SKIP: {src_path} not found")
            continue
        
        shutil.copy2(src_path, dest_path)
        size = os.path.getsize(dest_path)
        print(f"Deployed: {dest_name} ({size/1024:.1f} KB) -> {dest_path}")
    
    print("\n=== Files deployed ===")
    for name in DEPLOY_FILES.values():
        fp = os.path.join(DEST, name)
        if os.path.exists(fp):
            size = os.path.getsize(fp)
            print(f"  res://assets/effects/projectiles/weapons_realistic/{name} ({size/1024:.1f} KB)")
        else:
            print(f"  MISSING: {name}")
    
    print("\n=== Godot resource path mapping ===")
    print("  Ballistic trail: res://assets/effects/projectiles/weapons_realistic/weapon_artillery_ballistic.png")
    print("  Muzzle blast:    res://assets/effects/projectiles/weapons_realistic/weapon_artillery_muzzle.png")
    print("  Impact explosion:res://assets/effects/projectiles/weapons_realistic/weapon_artillery_impact.png")


if __name__ == "__main__":
    main()
