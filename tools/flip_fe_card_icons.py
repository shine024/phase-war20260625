#!/usr/bin/env python3
"""水平翻转 14 张 fe_* 卡图（朝左→朝右，对齐 vis_player_* 我方朝向）。
原地覆盖 assets/card_icons/player/fe_*.png，翻转后 PIL 校验完整性。"""
import os, sys
from PIL import Image
sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")

FILES = [
    "fe_iron_wall_bastion", "fe_iron_wall_juggernaut",
    "fe_nova_devastator", "fe_nova_ghost_sniper",
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen",
    "fe_quantum_mobile_base", "fe_quantum_repair_drone",
    "fe_helix_phantom", "fe_helix_orbital_strike",
    "fe_void_phase_cannon", "fe_void_dimensional_soldier",
    "fe_frontier_veteran", "fe_frontier_mixed_company",
]

ok = 0
fail = 0
for fname in FILES:
    path = os.path.join(PLAYER_DIR, fname + ".png")
    if not os.path.exists(path):
        print(f"  SKIP {fname}: not found")
        fail += 1
        continue
    try:
        with Image.open(path) as im:
            im.load()
            flipped = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            flipped.save(path, "PNG")
            w, h = flipped.size
            print(f"  OK {fname}  ({w}x{h} {flipped.mode})")
            ok += 1
    except Exception as e:
        print(f"  FAIL {fname}: {e}")
        fail += 1

print(f"\nDone: {ok} flipped, {fail} fail")
