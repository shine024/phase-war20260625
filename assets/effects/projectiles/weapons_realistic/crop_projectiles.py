"""
裁剪弹道贴图的透明边距，让子弹主体填满整张图。
备份原文件到 _original_backup/ 子目录。
"""
import os
from PIL import Image

BACKUP_DIR = "_original_backup"
TILE_PAD = 16  # 裁剪后四周保留的像素边距，避免子弹贴边

# 只裁剪这些命名贴图（不动 hash 命名的，那些可能已优化过）
TARGETS = [
    "weapon_smg_projectile.png",
    "weapon_rifle_projectile.png",
    "weapon_mg_projectile.png",
    "weapon_pistol_projectile.png",
    "weapon_shotgun_projectile.png",
    "weapon_sniper_projectile.png",
    "weapon_rocket_projectile.png",
    "weapon_flak_projectile.png",
    "weapon_laser_projectile.png",
    "weapon_missile_projectile.png",
    "weapon_omega_cannon_projectile.png",
    "weapon_rail_cannon_projectile.png",
    "weapon_artillery_ballistic.png",
]

os.makedirs(BACKUP_DIR, exist_ok=True)

for fname in TARGETS:
    if not os.path.exists(fname):
        print(f"SKIP {fname}: not found")
        continue
    img = Image.open(fname).convert("RGBA")
    orig_w, orig_h = img.size

    # 找非透明像素的边界框
    px = img.load()
    x0, y0, x1, y1 = orig_w, orig_h, 0, 0
    for y in range(orig_h):
        row_has = False
        for x in range(orig_w):
            if px[x, y][3] > 30:
                row_has = True
                if x < x0: x0 = x
                if x > x1: x1 = x
        if row_has:
            if y < y0: y0 = y
            if y > y1: y1 = y

    if x1 < x0 or y1 < y0:
        print(f"SKIP {fname}: no opaque content")
        continue

    # 加边距
    x0 = max(0, x0 - TILE_PAD)
    y0 = max(0, y0 - TILE_PAD)
    x1 = min(orig_w - 1, x1 + TILE_PAD)
    y1 = min(orig_h - 1, y1 + TILE_PAD)

    bw = x1 - x0 + 1
    bh = y1 - y0 + 1

    # 备份原文件（仅首次）
    backup_path = os.path.join(BACKUP_DIR, fname)
    if not os.path.exists(backup_path):
        img.save(backup_path)
        print(f"BACKUP {fname} -> {backup_path}")

    # 裁剪
    cropped = img.crop((x0, y0, x1 + 1, y1 + 1))
    # 同时删除对应的 .import 文件（Godot 会重新生成）
    import_path = fname + ".import"
    cropped.save(fname)
    if os.path.exists(import_path):
        os.remove(import_path)
        print(f"  removed stale .import: {import_path}")

    print(f"CROP {fname}: {orig_w}x{orig_h} -> {bw}x{bh} (ratio {bw/bh:.2f})")

print("\nDone. Godot will re-import on next launch.")
